import MarkdownIt from "markdown-it";
import Shiki from "@shikijs/markdown-it";

const md = MarkdownIt();
md.use(
  await Shiki({
    themes: {
      light: "catppuccin-latte",
      dark: "catppuccin-macchiato",
    },
  }),
);

export function parse_markdown(content) {
  return md.render(content);
}
