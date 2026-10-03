import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import { join } from "node:path";

const site = fileURLToPath(new URL("../site/", import.meta.url));
for (const file of ["index.html", "styles.css", "app.js", "simulation-worker.js", "moonsim.js"]) {
  await readFile(join(site, file));
}
const html = await readFile(join(site, "index.html"), "utf8");
const worker = await readFile(join(site, "simulation-worker.js"), "utf8");
const app = await readFile(join(site, "app.js"), "utf8");
assert.match(html, /app\.js/);
assert.match(app, /simulation-worker\.js/);
assert.match(worker, /moonsim\.js/);

const api = await import(pathToFileURL(join(site, "moonsim.js")).href);
const response = JSON.parse(api.run_scenario_json(JSON.stringify({
  scenario: "basic_queue",
  seed: 42,
  parameters: {
    entity_count: 2,
    arrival_interval: 1,
    arrival_times: [],
    service_time: 1,
    resource_capacity: 1,
  },
})));
assert.equal(response.ok, true);
assert.equal(response.result.completed, 2);
console.log("Static Web Lab output smoke test passed");
