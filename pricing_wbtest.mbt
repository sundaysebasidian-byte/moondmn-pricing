///|
fn quote_input(
  age : Int32,
  claims : Int32,
  value : String,
  monthly : Bool,
  start~ : String = "2026-01-01",
) -> String {
  "{\"age\":\{age},\"claims\":\{claims},\"insuredValue\":\{value},\"paymentMonthly\":\{monthly},\"startDate\":\"\{start}\"}"
}

///|
fn expected_quote(
  tier : String,
  base : String,
  fees : Int32,
  total : String,
  valid~ : String = "2026-01-31",
  end~ : String = "2027-01-01",
) -> String {
  "{\"risk\":\"\{tier}\",\"basePremium\":\{base},\"surcharges\":\{fees},\"annualPremium\":\{total},\"validUntil\":\"\{valid}\",\"coverageEnd\":\"\{end}\"}"
}

///|
test "FIRST rules, boundaries and priority use hand-derived rates" {
  // Each base is 20000 * rate; a positive claim count adds 50.
  // FIRST: >=3 claims takes precedence even over young/senior ages.
  let cases = [
    (18, 0, "young", "600", 0, "600"),
    (24, 0, "young", "600", 0, "600"),
    (25, 0, "standard", "400", 0, "400"),
    (64, 2, "standard", "400", 50, "450"),
    (65, 0, "senior", "500", 0, "500"),
    (80, 0, "senior", "500", 0, "500"),
    (40, 3, "high", "800", 50, "850"),
    (18, 3, "high", "800", 50, "850"),
    (80, 10, "high", "800", 50, "850"),
  ]
  for (age, claims, tier, base, fees, total) in cases {
    assert_eq(
      price_quote(quote_input(age, claims, "20000", false)),
      expected_quote(tier, base, fees, total),
    )
  }
}

///|
test "COLLECT SUM all eight combinations, including no match default" {
  // Standard rate .02: 20000 -> 400, 60000 -> 1200.
  // Independently add claims 50, monthly 24 and value >50000 100.
  // The explicit table default is 0; without it empty COLLECT SUM is null.
  let cases = [
    (0, false, "20000", "400", 0, "400"),
    (1, false, "20000", "400", 50, "450"),
    (0, true, "20000", "400", 24, "424"),
    (0, false, "60000", "1200", 100, "1300"),
    (1, true, "20000", "400", 74, "474"),
    (1, false, "60000", "1200", 150, "1350"),
    (0, true, "60000", "1200", 124, "1324"),
    (1, true, "60000", "1200", 174, "1374"),
    (0, false, "50000", "1000", 0, "1000"),
    (0, false, "50000.01", "1000", 100, "1100"),
    (0, false, "1000000", "20000", 100, "20100"),
  ]
  for (claims, monthly, value, base, fees, total) in cases {
    assert_eq(
      price_quote(quote_input(40, claims, value, monthly)),
      expected_quote("standard", base, fees, total),
    )
  }
}

///|
test "BKM decimal half-even rounding and exact JSON numbers" {
  // 12345.67*.02=246.9134 -> 246.91; .25*.02=.005 -> .00;
  // .75*.02=.015 -> .02, both half-even at two places.
  for
    (value, expected) in [
      ("12345.67", "246.91"),
      ("0.25", "0"),
      ("0.75", "0.02"),
    ] {
    assert_eq(
      price_quote(quote_input(40, 0, value, false)),
      expected_quote("standard", expected, 0, expected),
    )
  }
}

///|
test "explicit input date, leap-day and month/year boundaries" {
  // 30 elapsed days from Feb 29 -> Mar 30; +P1Y clamps to Feb 28.
  for
    (start, valid, end) in [
      ("2024-02-29", "2024-03-30", "2025-02-28"),
      ("2026-12-15", "2027-01-14", "2027-12-15"),
      ("2026-01-31", "2026-03-02", "2027-01-31"),
    ] {
    assert_eq(
      price_quote(quote_input(40, 0, "20000", false, start~)),
      expected_quote("standard", "400", 0, "400", valid~, end~),
    )
  }
}

///|
test "bad JSON, shape, types, ranges and date produce stable error codes" {
  let long_number = StringBuilder()
  for i = 0; i < 10001; i = i + 1 {
    long_number.write_char('1')
  }
  let cases = [
    ("{", "E_INPUT_JSON"),
    ("[]", "E_INPUT"),
    ("null", "E_INPUT"),
    ("{}", "E_INPUT"),
    (
      "{\"age\":40,\"claims\":0,\"insuredValue\":20000,\"paymentMonthly\":false,\"extra\":0}",
      "E_INPUT",
    ),
    (
      "{\"age\":\"40\",\"claims\":0,\"insuredValue\":20000,\"paymentMonthly\":false,\"startDate\":\"2026-01-01\"}",
      "E_INPUT",
    ),
    (
      "{\"age\":40,\"claims\":null,\"insuredValue\":20000,\"paymentMonthly\":false,\"startDate\":\"2026-01-01\"}",
      "E_INPUT",
    ),
    (
      "{\"age\":40,\"claims\":0,\"insuredValue\":\"20000\",\"paymentMonthly\":false,\"startDate\":\"2026-01-01\"}",
      "E_INPUT",
    ),
    (
      "{\"age\":40,\"claims\":0,\"insuredValue\":20000,\"paymentMonthly\":0,\"startDate\":\"2026-01-01\"}",
      "E_INPUT",
    ),
    (
      "{\"age\":40,\"claims\":0,\"insuredValue\":20000,\"paymentMonthly\":false,\"startDate\":null}",
      "E_INPUT",
    ),
    (
      "{\"age\":40.5,\"claims\":0,\"insuredValue\":20000,\"paymentMonthly\":false,\"startDate\":\"2026-01-01\"}",
      "E_INPUT",
    ),
    (
      "{\"age\":40,\"claims\":0.5,\"insuredValue\":20000,\"paymentMonthly\":false,\"startDate\":\"2026-01-01\"}",
      "E_INPUT",
    ),
    (quote_input(17, 0, "20000", false), "E_INPUT"),
    (quote_input(81, 0, "20000", false), "E_INPUT"),
    (quote_input(40, -1, "20000", false), "E_INPUT"),
    (quote_input(40, 11, "20000", false), "E_INPUT"),
    (quote_input(40, 0, "0", false), "E_INPUT"),
    (quote_input(40, 0, "-1", false), "E_INPUT"),
    (quote_input(40, 0, "1000000.01", false), "E_INPUT"),
    (quote_input(40, 0, "1e1000001", false), "E_DECIMAL_RANGE"),
    (quote_input(40, 0, long_number.to_string(), false), "E_DECIMAL_SYNTAX"),
    (quote_input(40, 0, "20000", false, start="2026-02-30"), "E_INPUT"),
    (quote_input(40, 0, "20000", false, start="invalid"), "E_INPUT"),
    (
      quote_input(40, 0, "20000", false, start="999999999" + "-12-31"),
      "E_DATE_RANGE",
    ),
  ]
  for (input, expected) in cases {
    let code = try {
      ignore(price_quote(input))
      "unexpected success"
    } catch {
      @types.Failure(code, _, _, _) => code
    }
    assert_eq(code, expected)
  }
}

///|
test "duplicate JSON keys retain the strict reader E_JSON error" {
  let input =
    #|{"age":40,"claims":0,"insuredValue":20000,"paymentMonthly":false,"startDate":"2026-01-01","age":50}
  let code = try {
    ignore(price_quote(input))
    "unexpected success"
  } catch {
    @types.Failure(code, _, _, _) => code
  }
  assert_eq(code, "E_JSON")
}

///|
test "cached model remains unchanged across successive quote inputs" {
  assert_eq(
    price_quote(quote_input(18, 3, "20000", true)),
    expected_quote("high", "800", 74, "874"),
  )
  assert_eq(
    price_quote(quote_input(40, 0, "20000", false)),
    expected_quote("standard", "400", 0, "400"),
  )
}
