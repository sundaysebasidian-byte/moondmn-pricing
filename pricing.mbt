///|
let cached_model : Result[@model.Model, @types.EngineError] = Ok(
  @moondmn.parse_model(model_xml),
) catch {
  error => Err(error)
}

///|
/// Evaluate the embedded model, parsed once per process. Returns exact JSON.
/// Required inputs: age, claims, insuredValue, paymentMonthly and startDate.
pub fn price_quote(input : String) -> String raise @types.EngineError {
  let object = @json.parse(input) catch {
    _ => raise @types.fail("E_INPUT_JSON", "input must be valid JSON")
  }
  guard object is Object(fields) else {
    raise @types.fail("E_INPUT", "input must be an object")
  }
  let required = [
    "age", "claims", "insuredValue", "paymentMonthly", "startDate",
  ]
  guard fields.length() == required.length() &&
    required.all(fn(key) { fields.contains(key) }) else {
    raise @types.fail("E_INPUT", "provide exactly the five documented inputs")
  }
  let valid_types = match
    (
      fields.get("age"),
      fields.get("claims"),
      fields.get("insuredValue"),
      fields.get("paymentMonthly"),
      fields.get("startDate"),
    ) {
    (
      Some(Number(_)),
      Some(Number(_)),
      Some(Number(_)),
      Some(True | False),
      Some(String(_)),
    ) => true
    _ => false
  }
  guard valid_types else {
    raise @types.fail(
      "E_INPUT", "input types do not match the documented schema",
    )
  }
  let valid = @moondmn.feel_eval(
    "(age instance of number) and (age >= 18) and (age <= 80) and (floor(age) = age) and (claims instance of number) and (claims >= 0) and (claims <= 10) and (floor(claims) = claims) and (insuredValue instance of number) and (insuredValue > 0) and (insuredValue <= 1000000) and (paymentMonthly instance of boolean) and (startDate instance of string) and (date(startDate) != null)",
    context=input,
  )
  guard valid == "true" else {
    raise @types.fail(
      "E_INPUT", "input types or values are outside the documented domain",
    )
  }
  let model = match cached_model {
    Ok(model) => model
    Err(error) => raise error
  }
  @moondmn.evaluate_decision(model, "Quote", input)
}
