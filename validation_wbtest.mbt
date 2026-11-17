///|
test "parenthesized FEEL type checks compose with validation predicates" {
  // Explicit grouping avoids ambiguity between type names and boolean operators.
  assert_eq(
    @moondmn.feel_eval(
      "(age instance of number) and (age >= 18)",
      context="{\"age\":40}",
    ),
    "true",
  )
  assert_eq(
    @moondmn.feel_eval(
      "(startDate instance of string) and (date(startDate) != null)",
      context="{\"startDate\":\"2026-01-01\"}",
    ),
    "true",
  )
}
