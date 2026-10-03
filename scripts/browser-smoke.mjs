import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { statSync } from "node:fs";
import { createServer } from "node:http";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { createServer as createNetServer } from "node:net";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const site = join(root, "site");
const edgeCandidates = [
  process.env.EDGE_BIN,
  process.env.CHROME_BIN,
  process.env["ProgramFiles(x86)"] && join(process.env["ProgramFiles(x86)"], "Microsoft", "Edge", "Application", "msedge.exe"),
  process.env.ProgramFiles && join(process.env.ProgramFiles, "Microsoft", "Edge", "Application", "msedge.exe"),
  process.env.LOCALAPPDATA && join(process.env.LOCALAPPDATA, "Google", "Chrome", "Application", "chrome.exe"),
].filter(Boolean);
const browser = edgeCandidates.find((candidate) => {
  try { return requireStat(candidate); } catch { return false; }
});

function requireStat(path) {
  return Boolean(path && path.length > 0 && path === resolve(path) && pathExists(path));
}

function pathExists(path) {
  try {
    return statSync(path).isFile();
  } catch {
    return false;
  }
}

if (!browser) {
  throw new Error("Set EDGE_BIN or CHROME_BIN to run the local browser smoke test.");
}

async function freePort() {
  const server = createNetServer();
  await new Promise((resolveListen, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolveListen);
  });
  const { port } = server.address();
  await new Promise((resolveClose) => server.close(resolveClose));
  return port;
}

const pagePort = await freePort();
const debugPort = await freePort();
const profile = await mkdtemp(join(tmpdir(), "moonsim-browser-smoke-"));
const mime = { ".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".json": "application/json" };
const staticServer = createServer(async (request, response) => {
  try {
    const pathname = new URL(request.url, `http://127.0.0.1:${pagePort}`).pathname;
    const file = pathname === "/" ? "index.html" : pathname.slice(1);
    if (file.includes("..") || file.includes("\\")) throw new Error("Invalid path");
    const body = await readFile(join(site, file));
    const extension = file.slice(file.lastIndexOf("."));
    response.writeHead(200, { "content-type": mime[extension] ?? "application/octet-stream" });
    response.end(body);
  } catch {
    response.writeHead(404);
    response.end("Not found");
  }
});
await new Promise((resolveListen, reject) => {
  staticServer.once("error", reject);
  staticServer.listen(pagePort, "127.0.0.1", resolveListen);
});

const child = spawn(browser, [
  "--headless=new",
  "--disable-gpu",
  "--no-first-run",
  "--no-default-browser-check",
  "--remote-allow-origins=*",
  `--remote-debugging-port=${debugPort}`,
  `--user-data-dir=${profile}`,
  `http://127.0.0.1:${pagePort}/?smoke=1`,
], { stdio: "ignore" });

try {
  let targets;
  for (let attempt = 0; attempt < 100; attempt += 1) {
    try {
      const response = await fetch(`http://127.0.0.1:${debugPort}/json`);
      if (response.ok) {
        targets = await response.json();
        if (targets.some((target) => target.type === "page" && target.webSocketDebuggerUrl)) break;
      }
    } catch {}
    await new Promise((resolveWait) => setTimeout(resolveWait, 100));
  }
  const page = targets?.find((target) => target.type === "page" && target.webSocketDebuggerUrl);
  assert.ok(page, "browser DevTools page target did not start");
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolveOpen, reject) => {
    socket.addEventListener("open", resolveOpen, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });
  let nextId = 0;
  const pendingCalls = new Map();
  socket.addEventListener("message", ({ data }) => {
    const message = JSON.parse(data);
    if (message.id === undefined) return;
    const call = pendingCalls.get(message.id);
    if (!call) return;
    pendingCalls.delete(message.id);
    message.error ? call.reject(new Error(message.error.message)) : call.resolve(message.result);
  });
  const cdp = (method, params = {}) => new Promise((resolveCall, rejectCall) => {
    const id = ++nextId;
    pendingCalls.set(id, { resolve: resolveCall, reject: rejectCall });
    socket.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async (expression) => {
    const result = await cdp("Runtime.evaluate", { expression, returnByValue: true });
    if (result.exceptionDetails) {
      throw new Error(result.exceptionDetails.exception?.description ?? result.exceptionDetails.text);
    }
    return result.result.value;
  };
  const waitForSmoke = async () => {
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const state = JSON.parse(await evaluate(
        "JSON.stringify({smoke:document.body.dataset.smoke||'pending',error:document.body.dataset.error||'',completed:document.body.dataset.completed||'',worker:document.querySelector('#running-state').hidden?'idle':'running'})",
      ));
      if (state.smoke === "passed") return state;
      if (state.smoke === "failed") throw new Error(`Browser smoke failed: ${state.error}`);
      await new Promise((resolveWait) => setTimeout(resolveWait, 100));
    }
    const state = await evaluate(
      "JSON.stringify({smoke:document.body.dataset.smoke||'pending',error:document.body.dataset.error||'',worker:document.querySelector('#running-state').hidden?'idle':'running'})",
    );
    throw new Error(`Browser smoke timed out: ${state}`);
  };
  await cdp("Runtime.enable");
  const initial = await waitForSmoke();
  assert.match(initial.completed, /5/);

  await evaluate("document.body.dataset.smoke='pending'; document.querySelector('[data-scenario=basic_queue]').click(); document.querySelector('#param-entity_count').value='5'; document.querySelector('#runs').value='3'; document.querySelector('#scenario-form').requestSubmit(); true");
  await waitForSmoke();
  const experimentSummary = await evaluate("document.querySelector('#run-summary').textContent");
  assert.match(experimentSummary, /3 replications/);

  await evaluate("document.body.dataset.smoke='pending'; document.querySelector('[data-scenario=manufacturing_line]').click(); document.querySelector('#param-entity_count').value='20'; document.querySelector('#runs').value='1'; document.querySelector('#scenario-form').requestSubmit(); true");
  await waitForSmoke();
  const stationCount = await evaluate("document.querySelectorAll('#visualizations .resource-row').length");
  assert.equal(stationCount, 7, "manufacturing should render all seven engine resource metrics");

  await evaluate("document.body.dataset.smoke='pending'; document.querySelector('[data-scenario=logistics_batching]').click(); document.querySelector('#param-entity_count').value='17'; document.querySelector('#scenario-form').requestSubmit(); true");
  await waitForSmoke();
  const policyView = await evaluate("JSON.stringify({charts:document.querySelectorAll('#visualizations .compare-chart').length,rows:document.querySelectorAll('#visualizations tbody tr').length})");
  assert.deepEqual(JSON.parse(policyView), { charts: 4, rows: 3 });

  await cdp("Page.setDownloadBehavior", { behavior: "allow", downloadPath: profile });
  await evaluate("document.querySelector('#download-button').click(); true");
  let downloaded;
  for (let attempt = 0; attempt < 50; attempt += 1) {
    try {
      downloaded = JSON.parse(await readFile(join(profile, "moonsim-logistics_batching-seed-42.json"), "utf8"));
      break;
    } catch {}
    await new Promise((resolveWait) => setTimeout(resolveWait, 100));
  }
  assert.ok(downloaded, "result JSON download should complete");
  assert.equal(downloaded.responses.fixed_batch.completed, 17);
  console.log("Browser Web Lab E2E passed: worker run, 3-seed experiment, 7-station chart, 3-policy comparison, and JSON export");
  await cdp("Page.close").catch(() => {});
  socket.close();
} finally {
  if (child.exitCode === null && child.signalCode === null) {
    child.kill();
    await Promise.race([
      new Promise((resolveExit) => child.once("exit", resolveExit)),
      new Promise((resolveWait) => setTimeout(resolveWait, 3000)),
    ]);
  }
  await new Promise((resolveClose) => staticServer.close(resolveClose));
  if (resolve(profile).startsWith(resolve(tmpdir()) + sep)) {
    for (let attempt = 0; attempt < 10; attempt += 1) {
      try {
        await rm(profile, { recursive: true, force: true });
        break;
      } catch (error) {
        if (error.code !== "EBUSY" || attempt === 9) throw error;
        await new Promise((resolveWait) => setTimeout(resolveWait, 100));
      }
    }
  }
}
