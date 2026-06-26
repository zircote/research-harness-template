import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import astroMermaid from "astro-mermaid";
import path from "node:path";

// Rewrite the docs' relative *.md / *.mdx cross-links to their built routes at
// build time. The harness docs keep links as relative *.md paths so they also
// render on GitHub; Starlight does not rewrite them on its own. Implemented inline
// (rather than astro-rehype-relative-markdown-links, whose peer range caps at
// astro <7) so it works on both Astro 6 and Astro 7.
function rehypeRelativeDocLinks({ base }) {
  const docMarkers = ["/src/content/docs/", "/docs/"];
  const toSlug = (rel) => {
    const parts = rel.replace(/\.(md|mdx)$/i, "").split("/");
    const last = parts[parts.length - 1].toLowerCase();
    if (last === "index") parts.pop();
    else parts[parts.length - 1] = last;
    return parts.map((p) => p.toLowerCase()).join("/");
  };
  return (tree, file) => {
    const fp = (file && (file.path || (file.history && file.history[0]))) || "";
    let rel = null;
    for (const m of docMarkers) {
      const i = fp.lastIndexOf(m);
      if (i !== -1) {
        rel = fp.slice(i + m.length);
        break;
      }
    }
    if (rel == null) return;
    const curDir = path.posix.dirname(rel.split(path.sep).join("/"));
    const visit = (node) => {
      if (
        node.type === "element" &&
        node.tagName === "a" &&
        node.properties &&
        typeof node.properties.href === "string"
      ) {
        const href = node.properties.href;
        const m = /^([^#?:]+\.(?:md|mdx))(#.*)?$/i.exec(href);
        if (m && !href.startsWith("/")) {
          const resolved = path.posix.normalize(path.posix.join(curDir, m[1]));
          if (!resolved.startsWith("..")) {
            const url = `${base}/${toSlug(resolved)}/`.replace(/\/{2,}/g, "/");
            node.properties.href = url + (m[2] || "");
          }
        }
      }
      if (node.children) node.children.forEach(visit);
    };
    visit(tree);
  };
}

export default defineConfig({
  site: "https://modeled-information-format.github.io",
  base: "/research-harness",
  markdown: {
    rehypePlugins: [[rehypeRelativeDocLinks, { base: "/research-harness" }]],
  },
  integrations: [
    astroMermaid(),
    starlight({
      title: "MIF Research Harness",
      customCss: ["./src/styles/mif-brand.css"],
      logo: {
        light: "./src/assets/logo-light.svg",
        dark: "./src/assets/logo-dark.svg",
        replacesTitle: true,
      },
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/modeled-information-format/research-harness-template",
        },
      ],
      sidebar: [
        {
          label: "Tutorials",
          items: [{ autogenerate: { directory: "tutorials" } }],
        },
        {
          label: "How-to guides",
          items: [{ autogenerate: { directory: "how-to" } }],
        },
        {
          label: "Reference",
          items: [{ autogenerate: { directory: "reference" } }],
        },
        {
          label: "Explanation",
          items: [{ autogenerate: { directory: "explanation" } }],
        },
        {
          label: "Decisions (ADRs)",
          items: [{ autogenerate: { directory: "adr" } }],
        },
        {
          label: "MIF ecosystem",
          items: [
            { label: "MIF home", link: "https://modeled-information-format.github.io/" },
            { label: "Ecosystem docs", link: "https://modeled-information-format.github.io/docs/" },
            { label: "Specification (mif-spec.dev)", link: "https://mif-spec.dev" },
          ],
        },
      ],
    }),
  ],
});
