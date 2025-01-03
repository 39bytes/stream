import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/fetch.{type FetchError, type FetchResponse}
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response, Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/result
import lustre_http.{
  InternalServerError, JsonError, NetworkError, NotFound, OtherError,
  Unauthorized,
}

pub fn delete(url, expect) {
  case request.to(url) {
    Ok(req) ->
      req |> request.set_method(http.Delete) |> lustre_http.send(expect)
    Error(_) -> panic
  }
}

pub fn patch(url, body, expect) {
  case request.to(url) {
    Ok(req) ->
      req
      |> request.set_method(http.Patch)
      |> request.set_header("Content-Type", "application/json")
      |> request.set_body(json.to_string(body))
      |> lustre_http.send(expect)
    Error(_) -> panic
  }
}

@external(javascript, "../files.ffi.mjs", "send_with_form_data")
fn send_with_form_data(
  url: String,
  form_data: Dynamic,
) -> Promise(Result(FetchResponse, FetchError))

pub fn send_form_data(
  url: String,
  form_data: Dynamic,
  expect: fn(Result(Response(String), lustre_http.HttpError)) -> msg,
  dispatch: fn(msg) -> Nil,
) -> Nil {
  send_with_form_data(url, form_data)
  |> promise.try_await(fn(resp) {
    promise.resolve(Ok(fetch.from_fetch_response(resp)))
  })
  |> promise.try_await(fetch.read_text_body)
  |> promise.map(fn(response) {
    case response {
      Ok(res) -> expect(Ok(res))
      Error(_) -> expect(Error(NetworkError))
    }
  })
  |> promise.rescue(fn(_) { expect(Error(NetworkError)) })
  |> promise.tap(dispatch)

  Nil
}

pub fn expect_json(
  decoder: dynamic.Decoder(a),
  to_msg: fn(Result(a, lustre_http.HttpError)) -> msg,
) {
  fn(response) {
    response
    |> result.then(response_to_result)
    |> result.then(fn(body) {
      case json.decode(from: body, using: decoder) {
        Ok(json) -> Ok(json)
        Error(json_error) -> Error(JsonError(json_error))
      }
    })
    |> to_msg
  }
}

fn response_to_result(
  response: Response(String),
) -> Result(String, lustre_http.HttpError) {
  case response {
    Response(status: status, headers: _, body: body)
      if 200 <= status && status <= 299
    -> Ok(body)
    Response(status: 401, headers: _, body: _) -> Error(Unauthorized)
    Response(status: 404, headers: _, body: _) -> Error(NotFound)
    Response(status: 500, headers: _, body: body) ->
      Error(InternalServerError(body))
    Response(status: code, headers: _, body: body) ->
      Error(OtherError(code, body))
  }
}
