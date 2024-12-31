import decipher
import gleam/dynamic
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre_http
import utils

const api_url = "http://localhost:3000"

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

pub type Post {
  Post(id: Int, content: String)
}

pub type Model {
  Model(posts: List(Post))
}

pub type Msg {
  ApiReturnedPosts(Result(List(Post), lustre_http.HttpError))
  ApiReturnedCreatedPost(Result(Post, lustre_http.HttpError))
  ApiDeletedPost(Result(Post, lustre_http.HttpError))
  UserCreatedPost(content: String)
  UserDeletedPost(id: Int)
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(Model(posts: []), get_posts())
}

fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("py-8")], [
    html.h1([attribute.class("text-center text-2xl font-bold py-8")], [
      html.text("🪷 jeff's stream"),
    ]),
    view_create_post(),
    view_posts_list(model),
  ])
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
    html.div([], [html.text(post.content)]),
  ])
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ApiReturnedPosts(res) -> {
      case res {
        Ok(posts) -> #(Model(posts:), effect.none())
        Error(_) -> #(model, effect.none())
      }
    }
    UserCreatedPost(content) -> #(model, create_post(content))
    ApiReturnedCreatedPost(res) -> {
      case res {
        Ok(post) -> #(Model(posts: [post, ..model.posts]), effect.none())
        Error(_) -> #(model, effect.none())
      }
    }
    UserDeletedPost(id) -> #(model, delete_post(id))
    ApiDeletedPost(res) -> {
      case res {
        Ok(post) -> #(
          Model(posts: model.posts |> list.filter(fn(p) { p.id != post.id })),
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

fn get_posts() -> Effect(Msg) {
  let expect =
    lustre_http.expect_json(dynamic.list(post_decoder()), ApiReturnedPosts)
  lustre_http.get(api_url, expect)
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
