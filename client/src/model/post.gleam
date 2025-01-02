import gleam/dynamic
import tempo.{type DateTime}
import tempo/datetime

pub type Post {
  Post(id: Int, content: String, created_at: DateTime)
}

pub fn decoder() {
  dynamic.decode3(
    Post,
    dynamic.field("id", dynamic.int),
    dynamic.field("content", dynamic.string),
    dynamic.field("created_at", datetime.from_dynamic_string),
  )
}
