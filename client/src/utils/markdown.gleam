import lustre/attribute
import lustre/element/html

@external(javascript, "../markdown.ffi.mjs", "parse_markdown")
pub fn parse_markdown(content: String) -> String

pub fn markdown_view(content: String) {
  html.div(
    [
      attribute.attribute("dangerous-unescaped-html", parse_markdown(content)),
      attribute.class(
        "prose dark:prose-invert prose-headings:text-text prose-strong:text-text prose-p:text-text prose-a:text-lavender hover:prose-a:text-lavender/70",
      ),
    ],
    [],
  )
}
