import assert from "node:assert/strict";
import { writeFile } from "node:fs/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import { join } from "node:path";

const buildDir = fileURLToPath(
  new URL("../_build/js/debug/build/web_api/", import.meta.url),
);
await writeFile(join(buildDir, "package.json"), '{"type":"module"}\n');
const modulePath = join(buildDir, "web_api.js");
const api = await import(pathToFileURL(modulePath).href);

const input = {
  scenario: "basic_queue",
  seed: 42,
  parameters: {
    entity_count: 3,
    arrival_interval: 1,
    arrival_times: [],
    service_time: 2,
    resource_capacity: 1,
  },
};
const output = api.run_scenario_json(JSON.stringify(input));
assert.equal(typeof output, "string", "MoonBit export must return JSON text");
const response = JSON.parse(output);
assert.equal(response.ok, true, "valid scenario should succeed");
assert.equal(
  response.result.completed,
  input.parameters.entity_count,
  "result must come from the requested MoonSim run",
);
assert.equal(response.result.wip, 0, "scenario should drain its WIP");
assert.ok(response.result.throughput > 0, "result should include throughput");

const invalidOutput = api.run_scenario_json("{");
const invalidResponse = JSON.parse(invalidOutput);
assert.equal(invalidResponse.ok, false, "invalid JSON should return an error");
assert.equal(typeof invalidResponse.error, "string");
console.log("MoonBit JavaScript API smoke test passed");
