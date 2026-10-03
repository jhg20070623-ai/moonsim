///|
pub struct ScenarioRequest {
  scenario : String
  seed : Int
  parameters : Json
} derive(FromJson)

///|
pub extend ScenarioRequest with FromJson::{from_json}

///|
/// Request payload for an experiment replication run.
pub struct ExperimentRequest {
  scenario : String
  seed : Int
  runs : Int
  parameters : Json
} derive(FromJson)

///|
pub extend ExperimentRequest with FromJson::{from_json}

///|
pub struct ApiResponse {
  ok : Bool
  result : Json
  error : Json
} derive(ToJson)

///|
pub extend ApiResponse with ToJson::{to_json}

///|
/// Browser-facing bounds, justified by docs/browser-limits.md.
const MAX_BROWSER_ENTITIES : Int = 10000

///|
const MAX_BROWSER_RUNS : Int = 20

///|
#export_name("run_scenario_json")
pub fn run_scenario_json(input_json : String) -> String {
  let request : Result[ScenarioRequest, String] = try {
    let parsed = @json.parse(input_json)
    let request : ScenarioRequest = @json.from_json(parsed)
    Ok(request)
  } catch {
    _ => Err("request must be valid JSON with scenario, seed, and parameters")
  }
  let response = match request {
    Err(message) =>
      ApiResponse::{
        ok: false,
        result: Json::null(),
        error: Json::string(message),
      }
    Ok(request) =>
      match scenario_config(request) {
        Err(message) =>
          ApiResponse::{
            ok: false,
            result: Json::null(),
            error: Json::string(message),
          }
        Ok(config) =>
          match validate_browser_entity_count(config) {
            Err(message) =>
              ApiResponse::{
                ok: false,
                result: Json::null(),
                error: Json::string(message),
              }
            Ok(_) =>
              match @scenarios.run_scenario(config) {
                Err(message) =>
                  ApiResponse::{
                    ok: false,
                    result: Json::null(),
                    error: Json::string(message),
                  }
                Ok(result) =>
                  ApiResponse::{
                    ok: true,
                    result: @json.to_json(result),
                    error: Json::null(),
                  }
              }
          }
      }
  }
  @json.to_json(response).stringify()
}

///|
#export_name("run_experiment_json")
pub fn run_experiment_json(input_json : String) -> String {
  let request : Result[ExperimentRequest, String] = try {
    let parsed = @json.parse(input_json)
    let request : ExperimentRequest = @json.from_json(parsed)
    Ok(request)
  } catch {
    _ =>
      Err(
        "request must be valid JSON with scenario, seed, runs, and parameters",
      )
  }
  let response = match request {
    Err(message) =>
      ApiResponse::{
        ok: false,
        result: Json::null(),
        error: Json::string(message),
      }
    Ok(request) =>
      match
        scenario_config(ScenarioRequest::{
          scenario: request.scenario,
          seed: request.seed,
          parameters: request.parameters,
        }) {
        Err(message) =>
          ApiResponse::{
            ok: false,
            result: Json::null(),
            error: Json::string(message),
          }
        Ok(config) =>
          match validate_browser_entity_count(config) {
            Err(message) =>
              ApiResponse::{
                ok: false,
                result: Json::null(),
                error: Json::string(message),
              }
            Ok(_) =>
              if request.runs > MAX_BROWSER_RUNS {
                ApiResponse::{
                  ok: false,
                  result: Json::null(),
                  error: Json::string(
                    "runs exceeds the measured browser limit of 20",
                  ),
                }
              } else {
                match
                  @scenarios.ExperimentRunner::new(request.seed, request.runs) {
                  Err(message) =>
                    ApiResponse::{
                      ok: false,
                      result: Json::null(),
                      error: Json::string(message),
                    }
                  Ok(runner) =>
                    match runner.run(config) {
                      Err(message) =>
                        ApiResponse::{
                          ok: false,
                          result: Json::null(),
                          error: Json::string(message),
                        }
                      Ok(result) =>
                        ApiResponse::{
                          ok: true,
                          result: @json.to_json(result),
                          error: Json::null(),
                        }
                    }
                }
              }
          }
      }
  }
  @json.to_json(response).stringify()
}

///|
fn validate_browser_entity_count(
  config : @scenarios.ScenarioConfig,
) -> Result[Unit, String] {
  if @scenarios.scenario_entity_count(config) > MAX_BROWSER_ENTITIES {
    Err("entity_count exceeds the measured browser limit of 10000")
  } else {
    Ok(())
  }
}

///|
fn scenario_config(
  request : ScenarioRequest,
) -> Result[@scenarios.ScenarioConfig, String] {
  match request.scenario {
    "basic_queue" => {
      let parameters : Result[@scenarios.BasicQueueParameters, String] = try {
        let parameters : @scenarios.BasicQueueParameters = @json.from_json(
          request.parameters,
        )
        Ok(parameters)
      } catch {
        _ => Err("parameters do not match the basic_queue schema")
      }
      match parameters {
        Err(message) => Err(message)
        Ok(value) =>
          Ok(@scenarios.ScenarioConfig::basic_queue(value, request.seed))
      }
    }
    "manufacturing_line" => {
      let parameters : Result[@scenarios.ManufacturingParameters, String] = try {
        let parameters : @scenarios.ManufacturingParameters = @json.from_json(
          request.parameters,
        )
        Ok(parameters)
      } catch {
        _ => Err("parameters do not match the manufacturing_line schema")
      }
      match parameters {
        Err(message) => Err(message)
        Ok(value) =>
          Ok(@scenarios.ScenarioConfig::manufacturing_line(value, request.seed))
      }
    }
    "logistics_batching" => {
      let parameters : Result[@scenarios.LogisticsParameters, String] = try {
        let parameters : @scenarios.LogisticsParameters = @json.from_json(
          request.parameters,
        )
        Ok(parameters)
      } catch {
        _ => Err("parameters do not match the logistics_batching schema")
      }
      match parameters {
        Err(message) => Err(message)
        Ok(value) =>
          Ok(@scenarios.ScenarioConfig::logistics_batching(value, request.seed))
      }
    }
    _ =>
      Err(
        "scenario must be basic_queue, manufacturing_line, or logistics_batching",
      )
  }
}
