const presets = {
  basic_queue: {
    title: "Basic Queue",
    arrivalTimes: "0, 1, 3, 7, 8",
    fields: [
      ["entity_count", "Entities", 5, 0, 10000],
      ["arrival_interval", "Arrival interval", 2, 0, 2147483647],
      ["service_time", "Service time", 2, 0, 2147483647],
      ["resource_capacity", "Resource capacity", 1, 1, 2147483647],
    ],
  },
  manufacturing_line: {
    title: "Manufacturing Line",
    fields: [
      ["entity_count", "Entities", 20, 0, 10000],
      ["arrival_interval", "Arrival interval", 6, 0, 2147483647],
      ...Array.from({ length: 7 }, (_, i) => [
        `station_${i + 1}_time`, `WS${i + 1} process time`, [12, 8, 6, 10, 5, 4, 9][i], 0, 2147483647,
      ]),
      ...Array.from({ length: 7 }, (_, i) => [
        `station_${i + 1}_capacity`, `WS${i + 1} capacity`, 1, 1, 2147483647,
      ]),
    ],
  },
  logistics_batching: {
    title: "Logistics Batching",
    arrivalTimes: "0, 1, 2, 3, 4, 12, 13, 14, 15, 16, 24, 25, 26, 27, 28, 35, 36",
    fields: [
      ["entity_count", "Entities", 17, 0, 10000],
      ["delivery_delay", "Delivery delay", 2, 0, 2147483647],
      ["fixed_time_threshold", "Fixed time threshold", 5, 1, 2147483647],
      ["fixed_batch_threshold", "Fixed batch size", 3, 1, 2147483647],
      ["hybrid_batch_threshold", "Hybrid batch size", 3, 1, 2147483647],
      ["hybrid_timeout", "Hybrid timeout", 5, 1, 2147483647],
    ],
  },
};

const form = document.querySelector("#scenario-form");
const fieldsNode = document.querySelector("#parameter-fields");
const errorNode = document.querySelector("#error-message");
const runButton = document.querySelector("#run-button");
const runningState = document.querySelector("#running-state");
const emptyState = document.querySelector("#empty-state");
const resultView = document.querySelector("#result-view");
const downloadButton = document.querySelector("#download-button");
const runsField = document.querySelector("#runs-field");
let scenario = "basic_queue";
let worker;
let pending;
let requestId = 0;
let exportPayload = null;
let lastSubmission = null;

function field(label, key, value, min, max, className = "") {
  const id = `param-${key}`;
  return `<label class="form-field ${className}"><span>${label}</span><input id="${id}" name="${key}" type="number" min="${min}" max="${max}" step="1" value="${value}" required></label>`;
}

function renderFields() {
  const definitions = presets[scenario].fields;
  const entity = definitions.find((item) => item[0] === "entity_count");
  const interval = definitions.find((item) => item[0] === "arrival_interval");
  const other = definitions.filter((item) => item !== entity && item !== interval);
  const manufacturing = scenario === "manufacturing_line";
  const arrivals = presets[scenario].arrivalTimes;
  let html = `<p class="group-caption">${manufacturing ? "Line inputs" : "Scenario inputs"}</p>`;
  html += field(entity[1], entity[0], entity[2], entity[3], entity[4]);
  if (interval) html += field(interval[1], interval[0], interval[2], interval[3], interval[4]);
  if (arrivals) {
    const optional = scenario === "basic_queue";
    html += `<label class="form-field arrival-pattern-field"><span>Arrival ticks <span class="hint">${optional ? "optional; clear to use interval" : "one non-decreasing tick per entity"}</span></span><textarea id="param-arrival_times_text" name="arrival_times_text" rows="2" spellcheck="false">${arrivals}</textarea></label>`;
  }
  if (manufacturing) {
    html += '<p class="group-caption">Processing times · integer ticks</p>';
    html += other.slice(0, 7).map(([key, label, value, min, max]) => field(label, key, value, min, max)).join("");
    html += '<p class="group-caption">Station capacities · units</p>';
    html += other.slice(7).map(([key, label, value, min, max]) => field(label, key, value, min, max)).join("");
  } else {
    html += other.map(([key, label, value, min, max]) => field(label, key, value, min, max)).join("");
  }
  fieldsNode.innerHTML = html;
  runsField.hidden = scenario === "logistics_batching";
  document.querySelector("#form-note").textContent = scenario === "logistics_batching"
    ? "Compares all three policies using the same seed and arrival pattern. Maximum 10,000 entities."
    : "Maximum 10,000 entities and 20 replications, based on the documented browser benchmark.";
}

function selectedValues() {
  return Object.fromEntries(new FormData(form).entries());
}

function integer(values, key) {
  return Number.parseInt(values[key], 10);
}

function buildRequest(values, selectedScenario = scenario, policy = null) {
  const count = integer(values, "entity_count");
  const interval = values.arrival_interval === undefined ? 0 : integer(values, "arrival_interval");
  const seed = integer(values, "seed");
  let parameters;
  if (selectedScenario === "basic_queue") {
    parameters = {
      entity_count: count,
      arrival_interval: interval,
      arrival_times: parseArrivalTimes(values.arrival_times_text, count, false),
      service_time: integer(values, "service_time"),
      resource_capacity: integer(values, "resource_capacity"),
    };
  } else if (selectedScenario === "manufacturing_line") {
    parameters = {
      entity_count: count,
      arrival_interval: interval,
      processing_times: Array.from({ length: 7 }, (_, i) => integer(values, `station_${i + 1}_time`)),
      station_capacities: Array.from({ length: 7 }, (_, i) => integer(values, `station_${i + 1}_capacity`)),
    };
  } else {
    parameters = {
      entity_count: count,
      arrival_times: parseArrivalTimes(values.arrival_times_text, count, true),
      delivery_delay: integer(values, "delivery_delay"),
      policy_type: policy,
      fixed_time_threshold: integer(values, "fixed_time_threshold"),
      fixed_batch_threshold: integer(values, "fixed_batch_threshold"),
      hybrid_batch_threshold: integer(values, "hybrid_batch_threshold"),
      hybrid_timeout: integer(values, "hybrid_timeout"),
    };
  }
  return { scenario: selectedScenario, seed, parameters };
}

function parseArrivalTimes(text, count, required) {
  const trimmed = String(text ?? "").trim();
  if (!trimmed) {
    if (required) throw new Error("Enter one arrival tick for each logistics entity.");
    return [];
  }
  const tokens = trimmed.split(/[\s,]+/).filter(Boolean);
  const arrivals = tokens.map((token) => Number(token));
  if (arrivals.some((tick) => !Number.isSafeInteger(tick) || tick < 0)) {
    throw new Error("Arrival ticks must be non-negative whole numbers.");
  }
  if (arrivals.length !== count) {
    throw new Error(`Enter exactly ${count} arrival ticks to match the entity count.`);
  }
  if (arrivals.some((tick, index) => index > 0 && tick < arrivals[index - 1])) {
    throw new Error("Arrival ticks must be in non-decreasing order.");
  }
  return arrivals;
}

function getWorker() {
  if (!worker) {
    worker = new Worker("./simulation-worker.js", { type: "module" });
    worker.addEventListener("message", ({ data }) => {
      if (!pending || data.id !== pending.id) return;
      const { resolve, reject } = pending;
      window.clearTimeout(pending.timeout);
      pending = null;
      data.error ? reject(new Error(data.error)) : resolve(data.response);
    });
    worker.addEventListener("error", (event) => {
      if (!pending) return;
      window.clearTimeout(pending.timeout);
      pending.reject(new Error(event.message || "Simulation worker failed to load."));
      pending = null;
      worker.terminate();
      worker = null;
    });
  }
  return worker;
}

function runInWorker(operation, request) {
  const currentWorker = getWorker();
  if (pending) return Promise.reject(new Error("A simulation is already running."));
  const id = ++requestId;
  return new Promise((resolve, reject) => {
    const timeout = window.setTimeout(() => {
      if (!pending || pending.id !== id) return;
      pending = null;
      worker?.terminate();
      worker = null;
      reject(new Error("Simulation timed out. Reduce the entity count and try again."));
    }, 30000);
    pending = { id, resolve, reject, timeout };
    currentWorker.postMessage({ id, operation, request });
  });
}

function format(value, digits = 2) {
  return Number.isFinite(value) ? new Intl.NumberFormat(undefined, { maximumFractionDigits: digits }).format(value) : "—";
}

function metricValue(result, key, aggregate) {
  const metric = result[key];
  return aggregate ? metric.mean : metric;
}

function metricRange(result, key, aggregate) {
  if (!aggregate) return "";
  const item = result[key];
  return `${format(item.min)}–${format(item.max)}`;
}

function renderKpis(result, aggregate) {
  const metrics = [
    ["Completed", "completed", "entities"],
    ["Cycle time", "cycle_time", "ticks"],
    ["Waiting time", "waiting_time", "ticks"],
    ["Final WIP", "wip", "entities"],
    ["Throughput", "throughput", "entities / tick"],
  ];
  document.querySelector("#kpi-grid").innerHTML = metrics.map(([label, key, unit]) => {
    const value = metricValue(result, key, aggregate);
    const range = metricRange(result, key, aggregate);
    return `<article class="kpi-card"><div class="kpi-label">${label}</div><div class="kpi-value">${format(value)}<span class="kpi-unit">${unit}</span></div>${range ? `<div class="kpi-range">observed ${range}</div>` : ""}</article>`;
  }).join("");
}

function renderResourceChart(resources) {
  if (!Array.isArray(resources) || resources.length === 0) return "";
  return `<article class="viz-card"><h3>Resource utilization</h3><p class="viz-subtitle">Busy time as a share of available capacity</p><div class="resource-list">${resources.map((resource) => {
    const percent = Math.max(0, Math.min(100, resource.utilization * 100));
    return `<div class="resource-row"><span class="resource-name">${escapeHtml(resource.name)}</span><div class="bar-track" role="img" aria-label="${escapeHtml(resource.name)} utilization ${format(percent, 1)} percent"><div class="bar-fill" style="width:${percent}%"></div></div><span class="resource-value">${format(percent, 1)}%<span class="resource-capacity">×${resource.capacity}</span></span></div>`;
  }).join("")}</div></article>`;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character]);
}

function renderExperiment(result) {
  const cards = [
    ["Completed", "completed", "entities"],
    ["Cycle time", "cycle_time", "ticks"],
    ["Waiting time", "waiting_time", "ticks"],
    ["Mean WIP", "mean_wip", "entities"],
    ["Throughput", "throughput", "entities / tick"],
  ];
  document.querySelector("#kpi-grid").innerHTML = cards.map(([label, key, unit]) => {
    const m = result[key];
    return `<article class="kpi-card"><div class="kpi-label">${label}</div><div class="kpi-value">${format(m.mean)}<span class="kpi-unit">${unit}</span></div><div class="kpi-range">observed ${format(m.min)}–${format(m.max)}</div></article>`;
  }).join("");
  document.querySelector("#visualizations").innerHTML = `<article class="viz-card"><h3>Replication spread</h3><p class="viz-subtitle">Mean and observed min–max for ${result.run_count} independent seeds</p><div class="logistics-table-wrap"><table class="compare-table"><thead><tr><th>Metric</th><th>Mean</th><th>Minimum</th><th>Maximum</th></tr></thead><tbody>${cards.map(([label, key]) => `<tr><td class="policy-name">${label}</td><td>${format(result[key].mean)}</td><td>${format(result[key].min)}</td><td>${format(result[key].max)}</td></tr>`).join("")}</tbody></table></div></article>`;
}

function svgBars(values, labels, colors, title) {
  const width = 430;
  const height = 180;
  const left = 35;
  const right = 10;
  const top = 10;
  const baseline = 145;
  const plotWidth = width - left - right;
  const max = Math.max(...values, 0);
  const scaleMax = max === 0 ? 1 : max * 1.15;
  const slot = plotWidth / values.length;
  const barWidth = Math.min(38, slot * .52);
  const y = (value) => baseline - ((value / scaleMax) * (baseline - top));
  const grid = [0, .5, 1].map((ratio) => {
    const py = baseline - ratio * (baseline - top);
    const tick = scaleMax * ratio;
    return `<line x1="${left}" y1="${py}" x2="${width - right}" y2="${py}" stroke="#edf1ed"/><text x="${left - 7}" y="${py + 3}" text-anchor="end" font-size="9" fill="#9aa59d">${format(tick, 1)}</text>`;
  }).join("");
  const bars = values.map((value, index) => {
    const x = left + slot * index + (slot - barWidth) / 2;
    const topY = y(value);
    return `<rect x="${x}" y="${topY}" width="${barWidth}" height="${Math.max(1, baseline - topY)}" rx="4" fill="${colors[index]}"/><text x="${x + barWidth / 2}" y="${Math.max(10, topY - 5)}" text-anchor="middle" font-size="9" fill="#4d6255">${format(value)}</text>`;
  }).join("");
  const names = labels.map((label, index) => `<text x="${left + slot * index + slot / 2}" y="164" text-anchor="middle" font-size="9" fill="#718077">${label}</text>`).join("");
  return `<svg class="compare-chart" viewBox="0 0 ${width} ${height}" role="img" aria-label="${escapeHtml(title)}">${grid}${bars}${names}</svg>`;
}

function renderLogistics(results) {
  const policies = ["fixed_time", "fixed_batch", "hybrid"];
  const labels = ["Fixed time", "Fixed batch", "Hybrid"];
  const colors = ["#347859", "#e0a167", "#87a9b0"];
  const metricDefs = [
    ["Waiting time", (result) => result.waiting_time],
    ["Throughput", (result) => result.throughput],
    ["Batch count", (result) => result.batch_statistics?.batch_count ?? 0],
    ["Overdue entities", (result) => result.batch_statistics?.overdue_entities ?? 0],
  ];
  const charts = metricDefs.map(([title, getter]) => {
    const values = policies.map((policy) => getter(results[policy]));
    return `<article class="viz-card"><h3>${title}</h3><p class="viz-subtitle">Same entities, arrivals, and seed for each policy</p>${svgBars(values, labels, colors, `${title} by batching policy`)}</article>`;
  }).join("");
  const rows = policies.map((policy, index) => {
    const result = results[policy];
    const stats = result.batch_statistics;
    return `<tr><td class="policy-name"><span class="legend-mark ${index === 1 ? "orange" : index === 2 ? "blue" : ""}"></span>${labels[index]}</td><td>${format(result.completed, 0)} / ${format(result.parameters.entity_count, 0)}</td><td>${format(result.waiting_time)}</td><td>${format(result.throughput, 4)}</td><td>${format(stats?.batch_count ?? 0, 0)}</td><td>${format(stats?.overdue_entities ?? 0, 0)}</td></tr>`;
  }).join("");
  return `${charts}<article class="viz-card logistics-table-wrap"><h3>Policy results</h3><p class="viz-subtitle">Values returned by the three MoonSim model runs</p><table class="compare-table"><thead><tr><th>Release policy</th><th>Completed</th><th>Waiting time</th><th>Throughput</th><th>Batches</th><th>Overdue</th></tr></thead><tbody>${rows}</tbody></table></article>`;
}

function showRunSummary(text, seed) {
  document.querySelector("#run-summary").innerHTML = `<strong>${escapeHtml(text)}</strong><span class="seed-chip">seed ${seed}</span>`;
}

function displaySingle(result, request, rawResponse) {
  emptyState.hidden = true;
  resultView.hidden = false;
  showRunSummary(`${presets[scenario].title} · ${format(result.events_processed, 0)} events processed`, request.seed);
  renderKpis(result, false);
  document.querySelector("#visualizations").innerHTML = renderResourceChart(result.resource_utilization);
  exportPayload = { request, response: rawResponse };
}

function displayExperiment(result, request, rawResponse) {
  emptyState.hidden = true;
  resultView.hidden = false;
  showRunSummary(`${presets[scenario].title} · ${result.run_count} replications`, request.seed);
  renderExperiment(result);
  exportPayload = { request, response: rawResponse };
}

function displayLogistics(results, requests) {
  emptyState.hidden = true;
  resultView.hidden = false;
  showRunSummary("Logistics batching · 3 policy runs", requests[0].seed);
  const completed = Object.values(results).every((item) => item.completed === requests[0].parameters.entity_count && item.wip === 0);
  document.querySelector("#kpi-grid").innerHTML = [
    ["Policies completed", Object.values(results).filter((item) => item.completed === requests[0].parameters.entity_count).length, "of 3"],
    ["Entities per policy", requests[0].parameters.entity_count, "entities"],
    ["All runs drained", completed ? "Yes" : "No", "final WIP = 0"],
    ["Seed", requests[0].seed, "same for each policy"],
    ["Policies compared", "3", "fixed time · batch · hybrid"],
  ].map(([label, value, unit]) => `<article class="kpi-card"><div class="kpi-label">${label}</div><div class="kpi-value">${value}<span class="kpi-unit">${unit}</span></div></article>`).join("");
  document.querySelector("#visualizations").innerHTML = renderLogistics(results);
  exportPayload = { requests, responses: results };
}

async function submit(event) {
  event?.preventDefault();
  errorNode.hidden = true;
  errorNode.textContent = "";
  if (!form.reportValidity()) return;
  const values = selectedValues();
  const seed = integer(values, "seed");
  const entityCount = integer(values, "entity_count");
  const runs = scenario === "logistics_batching" ? 1 : integer(values, "runs");
  if (!Number.isSafeInteger(seed) || seed < 0 || !Number.isSafeInteger(entityCount) || entityCount < 0 || entityCount > 10000 || runs < 1 || runs > 20) {
    errorNode.textContent = "Check the inputs. Entity count must be 0–10,000, seed must be non-negative, and replications must be 1–20.";
    errorNode.hidden = false;
    return;
  }
  runButton.disabled = true;
  runningState.hidden = false;
  emptyState.hidden = true;
  resultView.hidden = true;
  downloadButton.disabled = true;
  try {
    if (scenario === "logistics_batching") {
      const policyNames = ["fixed_time", "fixed_batch", "hybrid"];
      const requests = policyNames.map((policy) => buildRequest(values, scenario, policy));
      const responses = [];
      for (const request of requests) {
        responses.push(await runInWorker("scenario", request));
      }
      const failed = responses.find((response) => !response.ok);
      if (failed) throw new Error(failed.error || "MoonSim rejected this request.");
      const results = Object.fromEntries(policyNames.map((policy, index) => [policy, responses[index].result]));
      displayLogistics(results, requests);
      lastSubmission = { scenario, seed, requests };
    } else {
      const request = buildRequest(values);
      const operation = runs === 1 ? "scenario" : "experiment";
      const payload = runs === 1 ? request : { ...request, runs };
      const response = await runInWorker(operation, payload);
      if (!response.ok) throw new Error(response.error || "MoonSim rejected this request.");
      if (runs === 1) displaySingle(response.result, request, response);
      else displayExperiment(response.result, payload, response);
      lastSubmission = { scenario, seed, request: payload };
    }
    downloadButton.disabled = false;
    if (new URLSearchParams(location.search).has("smoke")) {
      document.body.dataset.smoke = "passed";
      document.body.dataset.completed = resultView.querySelector(".kpi-card .kpi-value")?.textContent ?? "";
    }
  } catch (error) {
    emptyState.hidden = false;
    resultView.hidden = true;
    errorNode.textContent = error instanceof Error ? error.message : String(error);
    errorNode.hidden = false;
    if (new URLSearchParams(location.search).has("smoke")) {
      document.body.dataset.smoke = "failed";
      document.body.dataset.error = errorNode.textContent;
    }
  } finally {
    runningState.hidden = true;
    runButton.disabled = false;
  }
}

document.querySelectorAll(".scenario-choice").forEach((button) => {
  button.addEventListener("click", () => {
    scenario = button.dataset.scenario;
    document.querySelectorAll(".scenario-choice").forEach((choice) => {
      const active = choice === button;
      choice.classList.toggle("active", active);
      choice.setAttribute("aria-pressed", String(active));
    });
    renderFields();
    errorNode.hidden = true;
  });
});

document.querySelector("#reset-button").addEventListener("click", () => {
  renderFields();
  document.querySelector("#seed").value = "42";
  document.querySelector("#runs").value = "1";
  errorNode.hidden = true;
});
form.addEventListener("submit", submit);
downloadButton.addEventListener("click", () => {
  if (!exportPayload) return;
  const blob = new Blob([JSON.stringify(exportPayload, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `moonsim-${lastSubmission?.scenario ?? "result"}-seed-${lastSubmission?.seed ?? "0"}.json`;
  anchor.click();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
});

renderFields();
if (new URLSearchParams(location.search).has("smoke")) {
  submit(new Event("submit", { cancelable: true }));
}
