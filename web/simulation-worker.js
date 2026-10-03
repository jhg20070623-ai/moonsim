import * as moonSim from "./moonsim.js";

self.addEventListener("message", ({ data }) => {
  const { id, operation, request } = data;
  try {
    const input = JSON.stringify(request);
    const output = operation === "experiment"
      ? moonSim.run_experiment_json(input)
      : moonSim.run_scenario_json(input);
    self.postMessage({ id, response: JSON.parse(output) });
  } catch (error) {
    self.postMessage({ id, error: error instanceof Error ? error.message : String(error) });
  }
});
