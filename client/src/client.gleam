import components/compose
import components/icons
import env
import gleam/dynamic
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre_http
import model/post.{type Post}
import model/user.{type User}
import tempo
import tempo/datetime
import utils/http as http_utils
import utils/markdown

pub fn main() {
  let assert Ok(_) = compose.register()
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

pub type Model {
  Model(user: Option(User), posts: List(Post), editing_post_id: Option(Int))
}

pub type Msg {
  ApiReturnedUser(Result(Option(User), lustre_http.HttpError))
  ApiReturnedPosts(Result(List(Post), lustre_http.HttpError))
  ApiReturnedCreatedPost(Result(Post, lustre_http.HttpError))
  ApiDeletedPost(Result(Post, lustre_http.HttpError))
  ApiEditedPost(Result(Post, lustre_http.HttpError))
  UserCreatedPost(content: String)
  UserDeletedPost(id: Int)
  UserEditingPost(id: Int)
  UserCancelledEdit
  UserEditedPost(id: Int, content: String)
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(
    Model(user: None, posts: [], editing_post_id: None),
    effect.batch([get_user(), get_posts()]),
  )
}

fn render_if_admin(model: Model, element: Element(Msg)) {
  case model.user {
    Some(user) if user.admin -> element
    _ -> html.div([], [])
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div([], [
    view_header(model),
    html.div([], [
      html.h1([attribute.class("text-center text-2xl font-bold pb-8")], [
        html.text("🪷 jeff's stream"),
      ]),
      render_if_admin(
        model,
        compose.compose([compose.on_confirm(UserCreatedPost)]),
      ),
      view_posts_list(model),
    ]),
  ])
}

fn view_header(model: Model) -> Element(Msg) {
  let contents = case model.user {
    Some(user) -> [
      html.a(
        [
          attribute.class(
            "flex gap-1 items-center border border-surface0 rounded-md px-2 py-1 hover:bg-surface0/50",
          ),
          attribute.href("https://github.com/" <> user.login),
        ],
        [icons.github_icon(), html.p([], [html.text(user.login)])],
      ),
      html.a(
        [
          attribute.href(env.api_url <> "/auth/logout"),
          attribute.class(
            "border border-surface0 rounded-md px-2 py-1 hover:bg-surface0/50",
          ),
        ],
        [html.text("Log out")],
      ),
    ]
    None -> [
      html.a(
        [
          attribute.href(env.api_url <> "/auth/login"),
          attribute.class(
            "border border-surface0 rounded-md px-2 py-1 hover:bg-surface0/50 ml-auto",
          ),
        ],
        [html.text("Log in")],
      ),
    ]
  }

  html.header(
    [attribute.class("flex gap-2 py-4 justify-between w-full")],
    contents,
  )
}

fn view_posts_list(model: Model) {
  html.div(
    [attribute.class("mt-8")],
    list.map(model.posts, view_post(model, _)),
  )
}

@external(javascript, "./client.ffi.mjs", "do_confirm")
fn confirm(msg: String) -> Bool

fn view_post(model: Model, post: Post) {
  let handle_delete = fn(_) {
    case confirm("Are you sure you want to delete this post?") {
      True -> UserDeletedPost(post.id) |> Ok
      False -> Error([])
    }
  }
  let handle_edit = fn(_) { UserEditingPost(post.id) |> Ok }

  case model.editing_post_id {
    Some(id) if id == post.id ->
      compose.compose([
        compose.on_confirm(UserEditedPost(id, _)),
        compose.on_cancel(UserCancelledEdit),
        compose.is_edit(True),
        compose.initial_content(post.content),
      ])
    _ -> {
      html.div([attribute.class("p-4 border border-surface0 rounded-md my-2")], [
        html.div([attribute.class("flex justify-between")], [
          html.div([attribute.class("text-subtext0 text-sm")], [
            html.text(
              datetime.to_local(post.created_at)
              |> tempo.accept_imprecision
              |> datetime.format("MMM D, YYYY h:mma"),
            ),
          ]),
          render_if_admin(
            model,
            html.div([attribute.class("flex gap-x-2")], [
              html.button(
                [
                  attribute.class(
                    "text-subtext0 text-sm border border-surface0 rounded-md px-2 py-1 hover:bg-lavender hover:text-text transition duration-200",
                  ),
                  attribute.on("click", handle_edit),
                ],
                [html.text("Edit")],
              ),
              html.button(
                [
                  attribute.class(
                    "text-subtext0 text-sm border border-surface0 rounded-md px-2 py-1 hover:bg-red hover:text-text transition duration-200",
                  ),
                  attribute.on("click", handle_delete),
                ],
                [html.text("Delete")],
              ),
            ]),
          ),
        ]),
        markdown.markdown_view(post.content),
      ])
    }
  }
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
    UserEditingPost(id) -> #(
      Model(..model, editing_post_id: Some(id)),
      effect.none(),
    )
    UserCancelledEdit -> #(Model(..model, editing_post_id: None), effect.none())
    UserEditedPost(id, content) -> #(
      Model(..model, editing_post_id: None),
      edit_post(id, content),
    )
    ApiEditedPost(res) -> {
      case res {
        Ok(post) -> {
          let posts =
            model.posts
            |> list.map(fn(p) {
              case p.id == post.id {
                True -> post
                False -> p
              }
            })
          #(Model(..model, posts:), effect.none())
        }
        Error(_) -> #(model, effect.none())
      }
    }
  }
}

// -----------
// | Effects |
// -----------

fn get_user() -> Effect(Msg) {
  let route = env.api_url <> "/auth/user"
  let expect =
    lustre_http.expect_json(dynamic.optional(user.decoder()), ApiReturnedUser)

  lustre_http.get(route, expect)
}

fn get_posts() -> Effect(Msg) {
  let route = env.api_url <> "/posts"
  let expect =
    lustre_http.expect_json(dynamic.list(post.decoder()), ApiReturnedPosts)

  lustre_http.get(route, expect)
}

fn create_post(content: String) -> Effect(Msg) {
  let route = env.api_url <> "/posts"
  let expect = lustre_http.expect_json(post.decoder(), ApiReturnedCreatedPost)

  lustre_http.post(
    route,
    json.object([#("content", json.string(content))]),
    expect,
  )
}

fn edit_post(id: Int, content: String) -> Effect(Msg) {
  let route = env.api_url <> "/posts/" <> int.to_string(id)
  let expect = lustre_http.expect_json(post.decoder(), ApiEditedPost)

  http_utils.patch(
    route,
    json.object([#("content", json.string(content))]),
    expect,
  )
}

fn delete_post(id: Int) -> Effect(Msg) {
  let route = env.api_url <> "/posts/" <> int.to_string(id)
  let expect = lustre_http.expect_json(post.decoder(), ApiDeletedPost)
  http_utils.delete(route, expect)
}
