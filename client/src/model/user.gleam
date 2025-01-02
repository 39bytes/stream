import gleam/dynamic
import gleam/option.{type Option}

pub type User {
  User(id: Int, login: String, name: String, email: Option(String), admin: Bool)
}

pub fn decoder() {
  dynamic.decode5(
    User,
    dynamic.field("id", dynamic.int),
    dynamic.field("login", dynamic.string),
    dynamic.field("name", dynamic.string),
    dynamic.field("email", dynamic.string |> dynamic.optional),
    dynamic.field("admin", dynamic.bool),
  )
}
