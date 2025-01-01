import decipher
import gleam/dict
import gleam/dynamic
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import lustre
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element, element}
import lustre/element/html
import lustre/event
import utils/markdown

pub const name: String = "stream-compose"

pub fn register() {
  let app = lustre.component(init, update, view, dict.new())
  lustre.register(app, name)
}

type Model {
  Model(content: String, tab: Tab)
}

type Tab {
  Compose
  Preview
}

fn tab_to_string(tab: Tab) {
  case tab {
    Compose -> "Compose"
    Preview -> "Preview"
  }
}

type Msg {
  UserChangedContent(content: String)
  UserClickedPost
  UserChangedTab(tab: Tab)
}

fn init(_) -> #(Model, Effect(Msg)) {
  #(Model(content: "", tab: Compose), effect.none())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserChangedContent(content) -> {
      io.debug(content)
      #(Model(..model, content:), effect.none())
    }
    UserClickedPost -> #(model, event.emit("post", json.string(model.content)))
    UserChangedTab(tab) -> #(Model(..model, tab:), effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  view_compose_area(model)
}

pub fn compose(attributes: List(Attribute(msg))) {
  element(name, attributes, [])
}

pub fn on_post(handler: fn(String) -> msg) -> Attribute(msg) {
  use event <- event.on("post")
  use content <- result.try(decipher.at(["detail"], dynamic.string)(event))

  Ok(handler(content))
}

fn view_compose_area(model: Model) -> Element(Msg) {
  let handle_post = fn(_) { Ok(UserClickedPost) }

  html.div(
    [
      attribute.class(
        "flex flex-col w-full gap-4 border border-surface0 rounded-md p-4",
      ),
    ],
    [
      view_tabs(model),
      case model.tab {
        Compose -> view_edit_input(model)
        Preview -> view_preview(model)
      },
      html.button(
        [
          attribute.class(
            "px-3 py-1.5 bg-lavender rounded-md text-background hover:bg-lavender/80 transition duration-200 w-fit ml-auto",
          ),
          event.on("click", handle_post),
        ],
        [html.text("Post")],
      ),
    ],
  )
}

fn view_tabs(model: Model) {
  let tabs = [Compose, Preview] |> list.map(view_tab(model, _))

  html.div([attribute.class("flex gap-x-2 text-sm text-subtext0")], tabs)
}

fn view_tab(model: Model, tab: Tab) -> Element(Msg) {
  let handle_click = fn(_) { Ok(UserChangedTab(tab)) }

  html.button(
    [
      attribute.class("text-sm"),
      attribute.classes([
        #("underline font-bold text-pink", model.tab == tab),
        #("text-subtext0", model.tab != tab),
      ]),
      attribute.on("click", handle_click),
    ],
    [html.text(tab_to_string(tab))],
  )
}

fn view_edit_input(model: Model) -> Element(Msg) {
  let on_change = fn(event) {
    let path = ["target", "value"]
    event
    |> decipher.at(path, dynamic.string)
    |> result.map(UserChangedContent)
  }

  html.textarea(
    [
      attribute.class("bg-background resize-none w-full h-48 outline-none"),
      attribute.name("content"),
      attribute.placeholder("Any thoughts...?"),
      attribute.on("change", on_change),
    ],
    model.content,
  )
}

fn view_preview(model: Model) -> Element(Msg) {
  html.div([attribute.class("overflow-scroll h-48")], [
    markdown.markdown_view(model.content),
  ])
}
