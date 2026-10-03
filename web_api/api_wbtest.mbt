///|
fn response_json(input : String) -> Json raise {
  let output = run_scenario_json(input)
  @json.parse(output) catch {
    _ => fail("Web API returned invalid JSON")
  }
}

///|
fn response_field(value : Json, key : String) -> Json raise {
  match value {
    Json::Object(fields) =>
      match fields.get(key) {
        None => fail("response is missing field: \{key}")
        Some(field) => field
      }
    _ => fail("Web API response is not a JSON object")
  }
}

///|
fn is_number(value : Json, expected : Double) -> Bool {
  match value {
    Json::Number(number, ..) => number == expected
    _ => false
  }
}

///|
test "Web API runs a parameterized basic queue and returns structured metrics" {
  let response = response_json(
    "{\"scenario\":\"basic_queue\",\"seed\":42,\"parameters\":{\"entity_count\":3,\"arrival_interval\":1,\"arrival_times\":[],\"service_time\":2,\"resource_capacity\":1}}",
  )
  assert_true(response_field(response, "ok") is Json::True)
  let result = response_field(response, "result")
  assert_true(is_number(response_field(result, "completed"), 3.0))
  assert_true(is_number(response_field(result, "wip"), 0.0))
  assert_true(response_field(result, "resource_utilization") is Json::Array(_))
}

///|
test "Web API executes manufacturing and serializes resource results" {
  let response = response_json(
    "{\"scenario\":\"manufacturing_line\",\"seed\":17,\"parameters\":{\"entity_count\":2,\"arrival_interval\":6,\"processing_times\":[1,1,1,1,1,1,1],\"station_capacities\":[1,1,1,1,1,1,1]}}",
  )
  assert_true(response_field(response, "ok") is Json::True)
  let result = response_field(response, "result")
  assert_true(is_number(response_field(result, "completed"), 2.0))
  match response_field(result, "resource_utilization") {
    Json::Array(resources) => assert_eq(resources.length(), 7)
    _ => fail("manufacturing resources are not a JSON array")
  }
}

///|
test "Web API includes policy-specific logistics statistics" {
  let response = response_json(
    "{\"scenario\":\"logistics_batching\",\"seed\":42,\"parameters\":{\"entity_count\":3,\"arrival_times\":[0,1,2],\"delivery_delay\":1,\"policy_type\":\"fixed_batch\",\"fixed_time_threshold\":5,\"fixed_batch_threshold\":3,\"hybrid_batch_threshold\":3,\"hybrid_timeout\":5}}",
  )
  assert_true(response_field(response, "ok") is Json::True)
  let result = response_field(response, "result")
  assert_true(is_number(response_field(result, "completed"), 3.0))
  match response_field(result, "batch_statistics") {
    Json::Object(stats) => assert_true(stats.get("batch_count") is Some(_))
    _ => fail("logistics statistics are not a JSON object")
  }
}

///|
test "Web API returns a JSON error object for malformed input JSON" {
  let response = response_json("{")
  assert_true(response_field(response, "ok") is Json::False)
  assert_true(response_field(response, "error") is Json::String(_))
}

///|
test "Web API rejects a request missing required envelope fields" {
  let response = response_json("{\"scenario\":\"basic_queue\"}")
  assert_true(response_field(response, "ok") is Json::False)
  assert_true(response_field(response, "error") is Json::String(_))
}

///|
test "Web API rejects unknown scenario names" {
  let response = response_json(
    "{\"scenario\":\"unknown\",\"seed\":42,\"parameters\":{}}",
  )
  assert_true(response_field(response, "ok") is Json::False)
  assert_true(response_field(response, "error") is Json::String(_))
}

///|
test "Web API rejects parameters that do not match a scenario schema" {
  let response = response_json(
    "{\"scenario\":\"manufacturing_line\",\"seed\":42,\"parameters\":{\"entity_count\":3}}",
  )
  assert_true(response_field(response, "ok") is Json::False)
  assert_true(response_field(response, "error") is Json::String(_))
}

///|
test "Web API reports model validation errors without panicking" {
  let response = response_json(
    "{\"scenario\":\"basic_queue\",\"seed\":42,\"parameters\":{\"entity_count\":2,\"arrival_interval\":1,\"arrival_times\":[],\"service_time\":2,\"resource_capacity\":0}}",
  )
  assert_true(response_field(response, "ok") is Json::False)
  assert_true(response_field(response, "result") is Json::Null)
  assert_true(response_field(response, "error") is Json::String(_))
}

///|
test "Web API applies the request seed and entity count" {
  let response = response_json(
    "{\"scenario\":\"basic_queue\",\"seed\":99,\"parameters\":{\"entity_count\":2,\"arrival_interval\":5,\"arrival_times\":[],\"service_time\":1,\"resource_capacity\":1}}",
  )
  let result = response_field(response, "result")
  assert_true(is_number(response_field(result, "seed"), 99.0))
  assert_true(is_number(response_field(result, "completed"), 2.0))
}
