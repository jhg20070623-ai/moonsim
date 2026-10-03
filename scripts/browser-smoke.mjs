import assert from "node:assert/strict";
import { createServer } from "node:http";
import { mkdtemp, readFile, rm, stat, mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { chromium, firefox } from "playwright";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const site = join(root, "site");
const capture = process.argv.includes("--capture");
const browserNames = process.argv.slice(2).filter((argument) => argument !== "--capture");
const selectedBrowsers = browserNames.length > 0 ? browserNames : ["chromium", "firefox"];
const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json",
};

function createStaticServer() {
  return createServer(async (request, response) => {
    try {
      const pathname = new URL(request.url ?? "/", "http://127.0.0.1").pathname;
      if (pathname === "/favicon.ico") {
        response.writeHead(204);
        response.end();
        return;
      }
      const relativePath = pathname === "/" ? "index.html" : decodeURIComponent(pathname.slice(1));
      const file = resolve(site, relativePath);
      if (!file.startsWith(resolve(site) + sep)) throw new Error("Invalid path");
      const body = await readFile(file);
      response.writeHead(200, {
        "content-type": mimeTypes[relativePath.slice(relativePath.lastIndexOf("."))] ?? "application/octet-stream",
        "cache-control": "no-store",
      });
      response.end(body);
    } catch {
      response.writeHead(404);
      response.end("Not found");
    }
  });
}

async function browserFor(name) {
  if (name === "chromium") return chromium.launch({ headless: true });
  if (name === "firefox") return firefox.launch({ headless: true });
  if (name === "edge") return chromium.launch({ channel: "msedge", headless: true });
  throw new Error(`Unknown browser '${name}'. Use chromium, firefox, or edge.`);
}

async function waitForResult(page) {
  await page.waitForFunction(() => {
    const result = document.querySelector("#result-view");
    const download = document.querySelector("#download-button");
    return result && !result.hidden && download && !download.disabled;
  }, null, { timeout: 30000 });
  const error = page.getByTestId("error-message");
  if (await error.isVisible()) throw new Error(await error.innerText());
}

async function readDownload(page, outputDirectory, filename) {
  const downloadPromise = page.waitForEvent("download");
  await page.getByTestId("download-json").click();
  const download = await downloadPromise;
  const path = join(outputDirectory, filename);
  await download.saveAs(path);
  return JSON.parse(await readFile(path, "utf8"));
}

async function runScenario(page, scenario, outputDirectory, filename) {
  const scenarioButton = page.getByTestId(`scenario-${scenario}`);
  if (await scenarioButton.getAttribute("aria-pressed") !== "true") await scenarioButton.click();
  await page.getByTestId("run-button").click();
  await waitForResult(page);
  return readDownload(page, outputDirectory, filename);
}

function checkFiniteNonNegative(value, label) {
  assert.ok(Number.isFinite(value), `${label} should be finite`);
  assert.ok(value >= 0, `${label} should be non-negative`);
}

function manufacturingSignature(result) {
  return {
    completed: result.completed,
    cycle_time: result.cycle_time,
    waiting_time: result.waiting_time,
    wip: result.wip,
    throughput: result.throughput,
    utilization: result.resource_utilization.map(({ name, utilization }) => ({ name, utilization })),
  };
}

function assertClose(left, right, label) {
  assert.ok(Math.abs(left - right) <= 1e-9, `${label}: ${left} differs from ${right}`);
}

async function testBrowser(name, baseUrl, outputDirectory) {
  const browser = await browserFor(name);
  const context = await browser.newContext({
    acceptDownloads: true,
    viewport: { width: 1920, height: 1080 },
  });
  const page = await context.newPage();
  const scriptErrors = [];
  page.on("pageerror", (error) => scriptErrors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") scriptErrors.push(message.text());
  });

  try {
    await page.goto(baseUrl, { waitUntil: "domcontentloaded" });
    assert.equal(await page.title(), "MoonSim Web Lab");
    await page.getByTestId("scenario-selector").waitFor({ state: "visible" });

    const queue = await runScenario(page, "basic_queue", outputDirectory, `${name}-basic-queue.json`);
    assert.equal(queue.response.ok, true, `${name}: Basic Queue request should succeed`);
    assert.equal(queue.response.result.completed, 5, `${name}: Basic Queue should complete all five entities`);
    checkFiniteNonNegative(queue.response.result.waiting_time, `${name}: queue waiting time`);
    assert.ok(queue.response.result.throughput > 0, `${name}: queue throughput should be positive`);
    assert.equal(await page.getByTestId("kpi-grid").locator(".kpi-card").count(), 5, `${name}: Basic Queue should render all five KPI cards`);
    for (const metric of ["completed", "cycle_time", "waiting_time", "wip", "throughput"]) {
      assert.ok((await page.getByTestId(`kpi-${metric}`).innerText()).trim().length > 0, `${name}: ${metric} KPI should be visible`);
    }
    if (capture && name === "chromium") {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: join(root, "docs", "images", "web-lab-overview.png") });
    }

    await page.getByTestId("param-runs").fill("3");
    await page.getByTestId("param-seed").fill("42");
    const experiment = await runScenario(page, "basic_queue", outputDirectory, `${name}-experiment.json`);
    assert.equal(experiment.response.result.run_count, 3, `${name}: Experiment Runner should return three runs`);
    assert.equal(experiment.response.result.base_seed, 42, `${name}: Experiment Runner should retain its base seed`);
    for (const metric of ["completed", "cycle_time", "waiting_time", "mean_wip", "throughput"]) {
      const summary = experiment.response.result[metric];
      assert.ok([summary.mean, summary.min, summary.max].every(Number.isFinite), `${name}: ${metric} mean/min/max should be finite`);
      assert.ok(summary.min <= summary.mean && summary.mean <= summary.max, `${name}: ${metric} mean should lie within its observed range`);
    }
    assert.match(await page.getByTestId("experiment-summary").innerText(), /independent seeds/);
    assert.equal(await page.getByTestId("kpi-grid").locator(".kpi-card").count(), 5, `${name}: Experiment Runner should render all five summary KPI cards`);

    await page.getByTestId("param-runs").fill("1");
    const manufacturing = await runScenario(page, "manufacturing_line", outputDirectory, `${name}-manufacturing.json`);
    assert.equal(manufacturing.request.parameters.entity_count, 20, `${name}: manufacturing default entity count`);
    assert.equal(manufacturing.request.parameters.arrival_interval, 6, `${name}: manufacturing default arrival interval`);
    assert.deepEqual(manufacturing.request.parameters.processing_times, [12, 8, 6, 10, 5, 4, 9], `${name}: manufacturing default processing times`);
    const manufacturingResult = manufacturing.response.result;
    assert.equal(manufacturingResult.completed, 20, `${name}: manufacturing should complete all 20 entities`);
    assert.equal(manufacturingResult.wip, 0, `${name}: manufacturing should drain WIP`);
    assert.ok(manufacturingResult.cycle_time > 0, `${name}: cycle time should be positive`);
    assert.ok(manufacturingResult.throughput > 0, `${name}: throughput should be positive`);
    assert.equal(manufacturingResult.resource_utilization.length, 7, `${name}: utilization chart should have seven stations`);
    assert.ok(manufacturingResult.resource_utilization.every(({ utilization }) => utilization >= 0 && utilization <= 1), `${name}: station utilization should stay in [0, 1]`);
    assert.equal(await page.getByTestId("manufacturing-utilization-chart").locator(".resource-row").count(), 7);
    if (capture && name === "chromium") {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: join(root, "docs", "images", "manufacturing-line.png") });
    }

    await page.getByTestId("param-station_2_time").fill("16");
    await page.getByTestId("run-button").click();
    await waitForResult(page);
    const changedManufacturing = await readDownload(page, outputDirectory, `${name}-manufacturing-changed.json`);
    assert.equal(changedManufacturing.request.parameters.processing_times[1], 16, `${name}: the edited processing time should be in the submitted request`);
    assert.notDeepEqual(
      manufacturingSignature(changedManufacturing.response.result),
      manufacturingSignature(manufacturingResult),
      `${name}: a changed parameter should produce a newly computed result`,
    );

    const logistics = await runScenario(page, "logistics_batching", outputDirectory, `${name}-logistics.json`);
    const policies = logistics.responses;
    assert.deepEqual(Object.keys(policies).sort(), ["fixed_batch", "fixed_time", "hybrid"]);
    assert.equal(await page.getByTestId("logistics-policy-table").locator("tbody tr").count(), 3);
    assert.equal(await page.locator(".compare-chart").count(), 4);
    for (const policy of Object.keys(policies)) {
      const result = policies[policy];
      assert.equal(result.completed, 17, `${name}/${policy}: should complete all 17 entities`);
      assert.equal(result.wip, 0, `${name}/${policy}: WIP should be zero`);
      checkFiniteNonNegative(result.waiting_time, `${name}/${policy}: waiting time`);
      assert.ok(result.batch_statistics.batch_count > 0, `${name}/${policy}: should release at least one batch`);
      assert.ok(result.batch_statistics.overdue_entities >= 0 && result.batch_statistics.overdue_entities <= 17, `${name}/${policy}: overdue count should be within the entity count`);
    }
    assert.ok(policies.fixed_time.batch_statistics.timeout_releases > 0, `${name}: FixedTime should release on timeout`);
    assert.equal(policies.fixed_batch.batch_statistics.timeout_releases, 0, `${name}: FixedBatch should use quantity triggers without timeout releases`);
    assert.ok(policies.hybrid.batch_statistics.timeout_releases > 0, `${name}: Hybrid should exercise its timeout path`);
    if (capture && name === "chromium") {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: join(root, "docs", "images", "logistics-batching.png") });
    }

    await page.setViewportSize({ width: 375, height: 812 });
    const mobileWidth = await page.evaluate(() => ({ viewport: document.documentElement.clientWidth, page: document.documentElement.scrollWidth }));
    assert.ok(mobileWidth.page <= mobileWidth.viewport, `${name}: mobile layout should not overflow horizontally (${mobileWidth.page} > ${mobileWidth.viewport})`);
    assert.equal(scriptErrors.length, 0, `${name}: browser should not report JavaScript errors: ${scriptErrors.join("; ")}`);
    return { name, version: browser.version(), manufacturing: manufacturingResult };
  } finally {
    await context.close();
    await browser.close();
  }
}

async function captureDemo(baseUrl) {
  const imageDirectory = join(root, "docs", "images");
  await mkdir(imageDirectory, { recursive: true });
  const videoDirectory = await mkdtemp(join(tmpdir(), "moonsim-demo-"));
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    acceptDownloads: true,
    viewport: { width: 1920, height: 1080 },
    recordVideo: { dir: videoDirectory, size: { width: 1920, height: 1080 } },
  });
  const page = await context.newPage();
  const video = page.video();

  try {
    await page.goto(baseUrl, { waitUntil: "domcontentloaded" });
    await page.getByTestId("scenario-selector").waitFor({ state: "visible" });
    await page.getByTestId("run-button").click();
    await waitForResult(page);
    await page.waitForTimeout(700);
    await page.getByTestId("scenario-manufacturing_line").click();
    await page.waitForTimeout(400);
    await page.getByTestId("run-button").click();
    await page.waitForFunction(() => !document.querySelector("#download-button").disabled, null, { timeout: 30000 });
    await page.waitForTimeout(1800);
    await page.getByTestId("param-station_2_time").fill("16");
    await page.waitForTimeout(1100);
    await page.getByTestId("run-button").click();
    await page.waitForFunction(() => !document.querySelector("#download-button").disabled, null, { timeout: 30000 });
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(5000);
  } finally {
    await context.close();
    await browser.close();
  }

  const webm = await video.path();
  const gif = join(imageDirectory, "moonsim-demo.gif");
  const convert = (fps, width) => spawnSync("ffmpeg", [
    "-y", "-ss", "0.8", "-i", webm,
    "-filter_complex", `fps=${fps},scale=${width}:-1:flags=lanczos,split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4`,
    "-loop", "0", gif,
  ], { encoding: "utf8", windowsHide: true });
  let result = convert(10, 960);
  if (result.status !== 0) throw new Error(`ffmpeg could not create the demo GIF: ${result.stderr}`);
  if ((await stat(gif)).size > 10 * 1024 * 1024) {
    result = convert(8, 800);
    if (result.status !== 0) throw new Error(`ffmpeg could not reduce the demo GIF: ${result.stderr}`);
  }
  assert.ok((await stat(gif)).size <= 10 * 1024 * 1024, "demo GIF should stay within the 10 MiB target");
  await rm(videoDirectory, { recursive: true, force: true });
  console.log(`Captured real Chromium demo GIF: ${gif}`);
}

const server = createStaticServer();
await new Promise((resolveListen, reject) => {
  server.once("error", reject);
  server.listen(0, "127.0.0.1", resolveListen);
});
const address = server.address();
const baseUrl = `http://127.0.0.1:${address.port}/`;
const outputDirectory = await mkdtemp(join(tmpdir(), "moonsim-browser-e2e-"));

try {
  if (capture) await mkdir(join(root, "docs", "images"), { recursive: true });
  const results = [];
  for (const name of selectedBrowsers) {
    const result = await testBrowser(name, baseUrl, outputDirectory);
    results.push(result);
    console.log(`Browser E2E passed: ${name} ${result.version} (Basic Queue, Experiment Runner, Manufacturing Line, Logistics Batching, responsive layout)`);
  }

  const baseline = results[0];
  const signature = manufacturingSignature(baseline.manufacturing);
  for (const result of results.slice(1)) {
    const other = manufacturingSignature(result.manufacturing);
    for (const key of ["completed", "wip"]) assert.equal(other[key], signature[key], `${baseline.name}/${result.name}: ${key} should match`);
    for (const key of ["cycle_time", "waiting_time", "throughput"]) assertClose(other[key], signature[key], `${baseline.name}/${result.name}: ${key}`);
    assert.equal(other.utilization.length, signature.utilization.length, `${baseline.name}/${result.name}: station counts should match`);
    for (let index = 0; index < signature.utilization.length; index += 1) {
      assert.equal(other.utilization[index].name, signature.utilization[index].name, `${baseline.name}/${result.name}: station name ${index + 1}`);
      assertClose(other.utilization[index].utilization, signature.utilization[index].utilization, `${baseline.name}/${result.name}: station ${index + 1} utilization`);
    }
    console.log(`Deterministic comparison passed: ${baseline.name} vs ${result.name}`);
  }

  if (capture) await captureDemo(baseUrl);
} finally {
  await new Promise((resolveClose) => server.close(resolveClose));
  await rm(outputDirectory, { recursive: true, force: true });
}
