import gleam/dynamic.{type Dynamic}
import gleam/fetch.{type FetchError, type FetchResponse}
import gleam/http
import gleam/http/request.{type Request}
import gleam/javascript/promise.{type Promise}
import lustre/effect
import lustre_http.{type Expect, NetworkError}

pub const api_url = "http://localhost:1234/api"

pub fn delete(url, expect) {
  case request.to(url) {
    Ok(req) ->
      req |> request.set_method(http.Delete) |> lustre_http.send(expect)
    Error(_) ->
      effect.from(fn(dispatch) {
        dispatch(expect.run(Error(lustre_http.BadUrl(url))))
      })
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
  expect: Expect(msg),
  dispatch: fn(msg) -> Nil,
) -> Nil {
  send_with_form_data(url, form_data)
  |> promise.try_await(fn(resp) {
    promise.resolve(Ok(fetch.from_fetch_response(resp)))
  })
  |> promise.try_await(fetch.read_text_body)
  |> promise.map(fn(response) {
    case response {
      Ok(res) -> expect.run(Ok(res))
      Error(_) -> expect.run(Error(NetworkError))
    }
  })
  |> promise.rescue(fn(_) { expect.run(Error(NetworkError)) })
  |> promise.tap(dispatch)

  Nil
}
