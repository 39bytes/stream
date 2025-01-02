import gleam/dynamic

pub type Attachment {
  Attachment(url: String)
}

pub fn decoder() {
  dynamic.decode1(Attachment, dynamic.field("url", dynamic.string))
}
