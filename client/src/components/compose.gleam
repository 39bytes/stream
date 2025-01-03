import decipher
import env
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Decoder, type Dynamic}
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import lustre
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element, element}
import lustre/element/html
import lustre/event
import lustre_http
import model/attachment.{type Attachment}
import utils/http as http_utils
import utils/markdown

pub const name: String = "stream-compose"

pub fn register() {
  let app = lustre.component(init, update, view, on_attribute_change())
  lustre.register(app, name)
}

type Model {
  Model(content: String, tab: Tab, is_edit: Bool)
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
  UserClickedConfirm
  UserClickedCancel
  UserChangedTab(tab: Tab)
  UserPastedAttachment(data: Dynamic, cursor_position: Int)
  ApiReturnedAttachmentLink(Result(Attachment, lustre_http.HttpError))
  ParentSetEdit(edit: Bool)
}

fn init(_) -> #(Model, Effect(Msg)) {
  #(Model(content: "", tab: Compose, is_edit: False), effect.none())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserChangedContent(content) -> {
      #(Model(..model, content:), effect.none())
    }
    UserClickedConfirm -> {
      #(
        Model(..model, content: ""),
        event.emit("confirm", json.string(model.content)),
      )
    }
    UserClickedCancel -> #(model, event.emit("cancel", json.null()))
    UserChangedTab(tab) -> #(Model(..model, tab:), effect.none())
    UserPastedAttachment(attachment, cursor_position) -> {
      #(
        Model(
          ..model,
          content: insert_upload_placeholder(model.content, cursor_position),
        ),
        upload_attachment(attachment),
      )
    }
    ApiReturnedAttachmentLink(res) -> {
      case res {
        Ok(attachment) -> {
          #(
            Model(
              ..model,
              content: replace_upload_placeholder(model.content, attachment.url),
            ),
            effect.none(),
          )
        }
        Error(e) -> {
          io.debug(e)
          #(model, effect.none())
        }
      }
    }
    ParentSetEdit(is_edit) -> {
      #(Model(..model, is_edit:), effect.none())
    }
  }
}

pub fn compose(attributes: List(Attribute(msg))) {
  element(name, attributes, [])
}

pub fn on_confirm(handler: fn(String) -> msg) -> Attribute(msg) {
  use event <- event.on("confirm")
  use content <- result.try(decipher.at(["detail"], dynamic.string)(event))

  Ok(handler(content))
}

pub fn on_cancel(handler: msg) -> Attribute(msg) {
  use _ <- event.on("cancel")

  Ok(handler)
}

pub fn initial_content(content: String) {
  attribute.attribute("content", content)
}

pub fn is_edit(edit: Bool) {
  attribute.attribute("edit", bool.to_string(edit))
}

fn on_attribute_change() -> Dict(String, Decoder(Msg)) {
  dict.from_list([
    #("content", fn(val) {
      val |> dynamic.string |> result.map(UserChangedContent)
    }),
    #("edit", fn(val) {
      val
      |> dynamic.string
      |> result.map(fn(b) {
        case b {
          "True" -> True
          _ -> False
        }
      })
      |> io.debug
      |> result.map(ParentSetEdit)
    }),
  ])
}

fn view(model: Model) -> Element(Msg) {
  let handle_post = fn(_) { Ok(UserClickedConfirm) }
  let handle_cancel = fn(_) { Ok(UserClickedCancel) }

  let confirm_text = case model.is_edit {
    True -> "Edit"
    False -> "Post"
  }

  let cancel_button =
    html.button(
      [
        attribute.class(
          "px-3 py-1.5 border border-surface0 rounded-md text-text hover:bg-lavender/80 transition duration-200 w-fit ml-auto",
        ),
        event.on("click", handle_cancel),
      ],
      [html.text("Cancel")],
    )
  let confirm_button =
    html.button(
      [
        attribute.class(
          "px-3 py-1.5 bg-lavender rounded-md text-background hover:bg-lavender/80 transition duration-200 w-fit ml-auto",
        ),
        event.on("click", handle_post),
      ],
      [html.text(confirm_text)],
    )

  let buttons = case model.is_edit {
    True -> [cancel_button, confirm_button]
    False -> [confirm_button]
  }

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
      html.div([attribute.class("flex gap-x-2 ml-auto w-fit")], buttons),
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

@external(javascript, "../files.ffi.mjs", "on_paste")
fn on_paste(event: Dynamic) -> Dynamic

fn view_edit_input(model: Model) -> Element(Msg) {
  let on_change = fn(event) {
    let path = ["target", "value"]
    event
    |> decipher.at(path, dynamic.string)
    |> result.map(UserChangedContent)
  }

  let handle_paste = fn(event) {
    use cursor_position <- result.try(
      event |> decipher.at(["target", "selectionStart"], dynamic.int),
    )
    let data = on_paste(event)

    Ok(UserPastedAttachment(data:, cursor_position:))
  }

  html.textarea(
    [
      attribute.class("bg-background resize-none w-full h-48 outline-none"),
      attribute.name("content"),
      attribute.placeholder("Any thoughts...?"),
      attribute.on("change", on_change),
      event.on("paste", handle_paste),
    ],
    model.content,
  )
}

fn view_preview(model: Model) -> Element(Msg) {
  html.div([attribute.class("overflow-scroll h-48")], [
    markdown.markdown_view(model.content),
  ])
}

const upload_placeholder = "[[uploading]]"

fn insert_upload_placeholder(content: String, cursor_position: Int) {
  let #(before, after) =
    content |> string.to_graphemes() |> list.split(cursor_position)

  string.join(before, "") <> upload_placeholder <> string.join(after, "")
}

fn replace_upload_placeholder(content: String, url: String) {
  let url = case env.mode {
    "development" ->
      string.replace(
        url,
        each: "http://localhost:1234",
        with: "http://localhost:3000",
      )
    _ -> url
  }

  let replacement = "![image](" <> url <> ")"

  string.replace(content, each: upload_placeholder, with: replacement)
}

fn upload_attachment(data: Dynamic) -> Effect(Msg) {
  let route = env.api_url <> "/attachments/upload"
  let expect =
    http_utils.expect_json(attachment.decoder(), ApiReturnedAttachmentLink)

  effect.from(http_utils.send_form_data(route, data, expect, _))
}
