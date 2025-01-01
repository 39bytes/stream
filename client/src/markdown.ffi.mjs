import MarkdownIt from "markdown-it";
import { fromHighlighter } from "@shikijs/markdown-it/core";
import { createHighlighterCore } from "shiki/core";
import { createOnigurumaEngine } from "shiki/index.mjs";

const highlighter = await createHighlighterCore({
  themes: [
    import("shiki/themes/catppuccin-macchiato.mjs"),
    import("shiki/themes/catppuccin-latte.mjs"),
  ],
  langs: [
    import("shiki/langs/typescript.mjs"),
    import("shiki/langs/tsx.mjs"),
    import("shiki/langs/rust.mjs"),
    import("shiki/langs/python.mjs"),
    import("shiki/langs/gleam.mjs"),
    import("shiki/langs/c.mjs"),
    import("shiki/langs/haskell.mjs"),
    import("shiki/langs/ruby.mjs"),
    import("shiki/langs/css.mjs"),
    import("shiki/langs/html.mjs"),
  ],
  engine: createOnigurumaEngine(import("shiki/wasm")),
});

const md = MarkdownIt({ linkify: true });
md.use(
  fromHighlighter(highlighter, {
    themes: {
      light: "catppuccin-latte",
      dark: "catppuccin-macchiato",
    },
  }),
);
md.linkify.set({ fuzzyEmail: false });

export function parse_markdown(content) {
  return md.render(content);
}
