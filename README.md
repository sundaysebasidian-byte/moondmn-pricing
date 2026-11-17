# MoonDMN insurance pricing example

By **moondmn-pricing contributors**. This is an example by the MoonDMN authors,
using the published **`sundaysebasidian-byte/moondmn@0.2.2`** package from mooncakes.
It demonstrates downstream integration; it is not an independent adoption claim.
The rates are illustrative, not an actuarial or lending product.

## Reproduce

Requires MoonBit **0.1.20261104** (moonc v0.10.20), Python 3 and `xmllint`.
Node.js is needed for JS tests; `moonrun` from the toolchain runs wasm-gc tests.
Run these commands from this module's directory:

```sh
export MOON_HOME=/tmp/moon-new
export PATH="$MOON_HOME/bin:$PATH"
moon version
moon update
# Already recorded in moon.mod; these reproduce the registry declarations:
moon add sundaysebasidian-byte/moondmn@0.2.2
moon add moonbitlang/x@0.5.7
moon fmt
moon fmt --check
moon check --deny-warn --target native
moon test --target native
moon check --deny-warn --target js
moon test --target js
moon check --deny-warn --target wasm-gc
moon test --target wasm-gc
python3 scripts/validate-model.py
python3 scripts/test-cli.py
python3 scripts/check-personal-data.py
moon run cmd/main --target native -- samples/standard.json
moon package --list
moon package
moon publish --dry-run
```

`moon add` resolves registry dependencies; there are no local paths or workspace
overrides. The direct `moonbitlang/x` dependency supplies the native CLI's file
and exit APIs. The library runs on native, JS and wasm-gc; the file CLI is native
only. On this toolchain, unauthenticated `moon publish --dry-run` stops with
`Registry login is required; run moon login`. No credentials were supplied, and
no publication was attempted. `moon package` independently verifies local archive
creation; this does not establish that the registry would accept publication.

The standard sample's exact stdout is checked twice by the CLI test:

```json
{"risk":"standard","basePremium":400,"surcharges":0,"annualPremium":400,"validUntil":"2026-01-31","coverageEnd":"2027-01-01"}
```

## Library API

Import `sundaysebasidian-byte/moondmn-pricing` with alias `pricing` in your
`moon.pkg`. Call `@pricing.price_quote(input_json)` to obtain a JSON string;
errors raise MoonDMN's public `@types.EngineError` (`Failure(code, line, column,
message)`, imported from `sundaysebasidian-byte/moondmn/feel/types`).

The `.dmn` file is embedded by a built-in `:embed` pre-build step. The library
calls the public `parse_model` once per process and caches that result, then
uses `evaluate_decision(model, "Quote", input)` for each request. It does not
read the model from a machine-specific path at runtime or expose the cached
mutable model. Model parse failures remain explicit on every call.

Input must be an object with exactly these fields:

| Field | Accepted value |
| --- | --- |
| `age` | Integer, 18 through 80 inclusive |
| `claims` | Integer, 0 through 10 inclusive |
| `insuredValue` | Number, greater than 0 and at most 1000000 |
| `paymentMonthly` | Boolean |
| `startDate` | Valid FEEL date string, e.g. `2026-01-01` |

The library uses JSON shape checks and FEEL predicates for validation, retaining
the original JSON numeric text for exact decimal evaluation. Malformed JSON is
`E_INPUT_JSON`; wrong shape, types or out-of-range values are `E_INPUT`. Engine
failures retain their upstream codes. The CLI prints one JSON line and exits 0
on success; usage, unreadable files and invalid inputs exit 1 with `error` and
`message`. It reports `E_USAGE` or `E_IO` for CLI-specific failures. Dates come
only from input, and no wall clock is read. JSON key order is fixed by the
model's context expression; numbers are JSON numbers, not padded currency text.

## Rules and model validity

`models/insurance.dmn` uses the standard DMN 1.3 MODEL namespace. Its dependency
chain is `Risk -> BasePremium -> AnnualPremium -> Quote`; `Surcharges` also feeds
`AnnualPremium`. `BasePremium` invokes the typed `annualBase` BKM.

| Decision | Hand-derived rule |
| --- | --- |
| `Risk` (FIRST) | Claims >=3: high, rate .04; otherwise age <25: young, .03; otherwise age >=65: senior, .025; otherwise standard, .02 |
| `BasePremium` | BKM calculates `decimal(insuredValue * Risk.rate, 2)` (half-even) |
| `Surcharges` (COLLECT SUM) | Add 50 for any claims, 24 for monthly payments, 100 for value >50000; explicit default 0 when no rule matches |
| `AnnualPremium` | `decimal(sum([BasePremium, Surcharges]), 2)` |
| `Quote` | Return decision results plus `startDate + P30D` validity and `startDate + P1Y` coverage end |

For the standard sample: 20000 * .02 = 400; no fee rules match, so fees = 0;
400 + 0 = 400. January 1 + 30 days = January 31; +1 year = January 1 next year.
Tests document hand calculations for all FIRST branches and precedence, all
eight fee combinations, thresholds, exact decimal rounding, leap-day/year
arithmetic and invalid inputs. Expected values are manually derived; **no Java
or other reference DMN engine was used**, even if available locally.

`validate-model.py` checks against the official [OMG DMN 1.3 schemas](https://www.omg.org/spec/DMN/1.3/)
using `xmllint`. Schema URLs and SHA-256 hashes are pinned in
`evidence/schema-sources.json`; downloads stay in an ignored local cache.
This validates standard XML structure, independently of MoonDMN's parser.
This example is not a TCK suite submission and has not been opened in a graphical
DMN editor or evaluated by another engine.

MoonDMN's [conformance documentation](https://github.com/sundaysebasidian-byte/moondmn/blob/main/docs/conformance.md)
and [0.2.2 evidence](https://github.com/sundaysebasidian-byte/moondmn/blob/main/docs/evidence/0.2.2/README.md)
report **TCK Level 2: 116/116; Level 3: 3271/3291**, with TCK commit
`1e349176e5ae689d924a2a2c7a8df25c220d8b07`. These are upstream evidence figures,
not counts from this example and not a claim of full DMN conformance. The local
upstream evidence heading still says unreleased; the registry dependency was
resolved successfully at 0.2.2 during this example's verification.

`ci/ci.yml` is an inert GitHub Actions template outside `.github/workflows`.
It has not run on GitHub. No remote, push, publication or deployment is configured.
The example is licensed under Apache-2.0; dependency licenses remain their own.
