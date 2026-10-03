# Web Backend Decision

Date: 2026-10-03  
Toolchain: `moon 0.1.20260920 (914d7da 2026-09-20)`

## Decision

Use MoonBit's JavaScript backend for the browser-facing `web_api` package in v0.2.0. Keep the simulation engine and scenario runners implemented in MoonBit. The browser adapter will accept and return JSON strings; it will not reimplement model behavior in JavaScript.

## Evidence

The official [MoonBit FFI documentation](https://docs.moonbitlang.com/en/latest/language/ffi.html) lists Wasm, Wasm GC, and JavaScript backends. It documents `foreign_library` plus `#export_name` for exported functions, and notes that Wasm host interaction depends on the host. The [package configuration documentation](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html) documents backend selection and `moon.pkg` declarations. The official [MoonBit core JSON API](https://mooncakes.io/docs/moonbitlang/core/json) provides JSON parsing, typed `FromJson`/`ToJson` conversion, and stringification.

Local checks on the current toolchain found:

- The MoonSim core builds with `moon build --target wasm`, `moon build --target wasm-gc`, and `moon build --target js`.
- The implemented web_api package compiles for wasm, wasm-gc, and js. The browser entrypoint remains the JS build because the direct String ABI probe exposed host-boundary friction on the two Wasm targets.
- A minimal `foreign_library` package exporting `String -> String` with `#export_name` also builds for all three backends.
- Calling the generated JavaScript export with a JSON string from Node returns that string directly.
- The implemented run_scenario_json MoonBit export builds for JavaScript, and node web_api/smoke.mjs verifies successful metrics output and a JSON-formatted validation error.
- Calling the Wasm export with a JavaScript JSON string fails at the host boundary: the linear Wasm build reports `memory access out of bounds`, and the Wasm GC build reports a JS/Wasm reference type incompatibility. Neither exported artifact has imports, but a direct JSON-string call still needs additional ABI or glue handling.

## Rationale and scope

The first browser API is a narrow JSON-in/JSON-out boundary. The JavaScript backend is the smallest verified host interface for that boundary and avoids adding a custom string allocator, encoding protocol, or runtime glue solely for JSON exchange. This decision is based on a local interop probe, not on a claim that MoonBit's Wasm backends cannot run in browsers.

Only the adapter package targets JavaScript. The reusable simulation and scenario logic remain MoonBit code and are invoked by the generated MoonBit module. Revisit Wasm or Wasm GC if the project later adopts a documented, tested string ABI that removes the current host-boundary friction.

## Build command

From the repository root, build the browser adapter with the current Moon CLI syntax:

```sh
moon build --target js web_api
```

The local toolchain help lists `wasm`, `wasm-gc`, and `js` as valid `--target` values. Node validates the exported JSON API; browser UI integration and static hosting remain later implementation and verification steps.
