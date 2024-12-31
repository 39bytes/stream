import decipher
import gleam/dynamic
import gleam/http/request
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre_http
import utils

const api_url = "http://localhost:1234/api"

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

pub type Post {
  Post(id: Int, content: String)
}

pub type User {
  User(id: Int, login: String, name: String, email: Option(String), admin: Bool)
}

pub type Model {
  Model(user: Option(User), posts: List(Post))
}

pub type Msg {
  ApiReturnedUser(Result(Option(User), lustre_http.HttpError))
  ApiReturnedPosts(Result(List(Post), lustre_http.HttpError))
  ApiReturnedCreatedPost(Result(Post, lustre_http.HttpError))
  ApiDeletedPost(Result(Post, lustre_http.HttpError))
  UserCreatedPost(content: String)
  UserDeletedPost(id: Int)
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(Model(user: None, posts: []), effect.batch([get_user(), get_posts()]))
}

fn view(model: Model) -> Element(Msg) {
  html.div([], [
    view_header(model),
    html.div([attribute.class("")], [
      html.h1([attribute.class("text-center text-2xl font-bold pb-8")], [
        html.text("🪷 jeff's stream"),
      ]),
      view_create_post(),
      view_posts_list(model),
    ]),
  ])
}

fn view_header(model: Model) -> Element(Msg) {
  let contents = case model.user {
    Some(user) -> [
      html.p([], [html.text(user.login)]),
      html.a([attribute.href(api_url <> "/auth/logout")], [html.text("Log out")]),
    ]
    None -> [
      html.a([attribute.href(api_url <> "/auth/login")], [html.text("Log in")]),
    ]
  }

  html.header([attribute.class("flex gap-2 p-4 justify-end")], contents)
}

fn view_create_post() -> Element(Msg) {
  let handle_click = fn(event) {
    let path = ["target", "previousElementSibling", "value"]
    event
    |> decipher.at(path, dynamic.string)
    |> result.map(UserCreatedPost)
  }

  html.div(
    [
      attribute.class(
        "flex flex-col w-full items-end gap-4 border border-surface0 rounded-md p-4",
      ),
    ],
    [
      html.textarea(
        [
          attribute.class("bg-background resize-none w-full h-24 outline-none"),
          attribute.name("content"),
          attribute.placeholder("Any thoughts...?"),
        ],
        "",
      ),
      html.button(
        [
          attribute.class("px-3 py-1.5 bg-lavender rounded-md text-background"),
          event.on("click", handle_click),
        ],
        [html.text("Post")],
      ),
    ],
  )
}

fn view_posts_list(model: Model) {
  html.div([attribute.class("mt-8")], list.map(model.posts, view_post))
}

@external(javascript, "./app.ffi.mjs", "parse_markdown")
fn parse_markdown(content: String) -> String

fn view_post(post: Post) {
  let handle_delete = fn(_) { UserDeletedPost(post.id) |> Ok }

  html.div([attribute.class("p-4 border border-surface0 rounded-md")], [
    html.div([attribute.class("flex justify-between")], [
      html.div([attribute.class("text-subtext0")], [
        html.text("id: " <> post.id |> int.to_string),
      ]),
      html.button(
        [
          attribute.class("text-subtext0 text-sm"),
          attribute.on("click", handle_delete),
        ],
        [html.text("Delete")],
      ),
    ]),
    html.div(
      [
        attribute.attribute(
          "dangerous-unescaped-html",
          parse_markdown(post.content),
        ),
      ],
      [],
    ),
  ])
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ApiReturnedUser(res) -> {
      case res {
        Ok(user) -> #(Model(..model, user:), effect.none())
        Error(_) -> #(model, effect.none())
      }
    }
    ApiReturnedPosts(res) -> {
      case res {
        Ok(posts) -> #(Model(..model, posts:), effect.none())
        Error(_) -> #(model, effect.none())
      }
    }
    UserCreatedPost(content) -> #(model, create_post(content))
    ApiReturnedCreatedPost(res) -> {
      case res {
        Ok(post) -> #(
          Model(..model, posts: [post, ..model.posts]),
          effect.none(),
        )
        Error(_) -> #(model, effect.none())
      }
    }
    UserDeletedPost(id) -> #(model, delete_post(id))
    ApiDeletedPost(res) -> {
      case res {
        Ok(post) -> #(
          Model(
            ..model,
            posts: model.posts |> list.filter(fn(p) { p.id != post.id }),
          ),
          effect.none(),
        )
        Error(_) -> #(model, effect.none())
      }
    }
  }
}

fn post_decoder() {
  dynamic.decode2(
    Post,
    dynamic.field("id", dynamic.int),
    dynamic.field("content", dynamic.string),
  )
}

fn user_decoder() {
  dynamic.decode5(
    User,
    dynamic.field("id", dynamic.int),
    dynamic.field("login", dynamic.string),
    dynamic.field("name", dynamic.string),
    dynamic.field("email", dynamic.string |> dynamic.optional),
    dynamic.field("admin", dynamic.bool),
  )
}

fn get_user() -> Effect(Msg) {
  let route = api_url <> "/auth/user"
  let expect =
    lustre_http.expect_json(dynamic.optional(user_decoder()), ApiReturnedUser)

  lustre_http.get(route, expect)
}

fn get_posts() -> Effect(Msg) {
  let route = api_url
  let expect =
    lustre_http.expect_json(dynamic.list(post_decoder()), ApiReturnedPosts)

  case request.to(route) {
    Ok(req) -> req |> lustre_http.send(expect)
    Error(_) ->
      effect.from(fn(dispatch) {
        dispatch(expect.run(Error(lustre_http.BadUrl(route))))
      })
  }
  lustre_http.get(route, expect)
}

fn create_post(content: String) -> Effect(Msg) {
  let route = api_url <> "/posts"
  let expect = lustre_http.expect_json(post_decoder(), ApiReturnedCreatedPost)

  lustre_http.post(
    route,
    json.object([#("content", json.string(content))]),
    expect,
  )
}

fn delete_post(id: Int) -> Effect(Msg) {
  let route = api_url <> "/posts/" <> int.to_string(id)
  let expect = lustre_http.expect_json(post_decoder(), ApiDeletedPost)
  utils.http_delete(route, expect)
}
