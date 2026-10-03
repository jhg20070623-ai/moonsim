///|
pub struct ScenarioRequest {
  scenario : String
  seed : Int
  parameters : Json
} derive(FromJson)

///|
pub extend ScenarioRequest with FromJson::{from_json}

///|
pub struct ApiResponse {
  ok : Bool
  result : Json
  error : Json
} derive(ToJson)

///|
pub extend ApiResponse with ToJson::{to_json}

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
  @json.to_json(response).stringify()
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
