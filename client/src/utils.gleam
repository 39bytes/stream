import gleam/http
import gleam/http/request
import lustre/effect
import lustre_http

pub fn http_delete(url, expect) {
  case request.to(url) {
    Ok(req) ->
      req |> request.set_method(http.Delete) |> lustre_http.send(expect)
    Error(_) ->
      effect.from(fn(dispatch) {
        dispatch(expect.run(Error(lustre_http.BadUrl(url))))
      })
  }
}
