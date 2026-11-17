///|
fn run() -> Unit raise Error {
  let args = @env.args()
  guard args.length() == 2 else {
    raise @types.fail("E_USAGE", "usage: moondmn-pricing <input.json>")
  }
  println(@pricing.price_quote(@fs.read_file_to_string(args[1])))
}

///|
fn main {
  run() catch {
    @types.Failure(code, _, _, message) => {
      println(
        Json::object({ "error": Json(code), "message": Json(message) }).stringify(),
      )
      @sys.exit(1)
    }
    _ => {
      println("{\"error\":\"E_IO\",\"message\":\"cannot read input file\"}")
      @sys.exit(1)
    }
  }
}
