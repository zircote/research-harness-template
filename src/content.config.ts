import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { docsSchema } from '@astrojs/starlight/schema';

// One Starlight `docs` collection sourced from TWO real repo-root trees: the canonical
// Diátaxis docs/ and the harness's rendered reports/ outputs. We use a plain `glob()`
// (not Starlight's docsLoader) for two reasons:
//   1. docsLoader's pattern is hardcoded to `**/[^_]*.{md,…}` — its underscore rule guards
//      filenames, not directories, so it cannot exclude reports/_meta/ or the per-topic
//      research-progress.md continuity file. The `!`-negations below do that.
//   2. Both docs/ and reports/ are real repo-root trees. We glob them directly under base
//      `.` rather than symlinking reports/ into the docs tree, so the loader walks plain
//      directories with no symlink indirection.
// Routing/sidebar are unaffected: Starlight derives them from each entry's id. `generateId`
// strips the leading `docs/` so docs keep their existing root routes while reports route under
// `reports/`. Keep the negations and the generateId — gate_m23 enforces their presence.
// (Note: report bodies rendering as title-only is NOT caused by the loader/base — it is the
// gray-matter `safeLoad` crash in the relative-links plugin on js-yaml 4; the patches/
// gray-matter patch fixes it. See CHANGELOG.)
const MD_EXT = /\.(?:markdown|mdown|mkdn|mkd|mdwn|md|mdx)$/i;

export const collections = {
  docs: defineCollection({
    loader: glob({
      base: '.',
      pattern: [
        'docs/**/[^_]*.{markdown,mdown,mkdn,mkd,mdwn,md,mdx}',
        'reports/**/[^_]*.{markdown,mdown,mkdn,mkd,mdwn,md,mdx}',
        '!reports/_meta/**',
        '!reports/**/research-progress.md',
        '!reports/**/findings/**',
        // A topic's README.md is a deterministic repo/GitHub navigation index
        // (scripts/build-topic-readme.sh) with an H1 title and NO MIF/Starlight
        // frontmatter, so it cannot satisfy the docs collection schema (title
        // required). The report itself is the site content; the README stays a
        // repo-nav file. (docs/**/README.md carry frontmatter and remain pages.)
        '!reports/**/README.md',
      ],
      // Strip the leading `docs/` so docs keep their root routes (reports keep their
      // `reports/` prefix), drop the extension, and lowercase to match Starlight's default
      // slug casing (e.g. README.md -> `readme`) so existing doc routes are unchanged.
      generateId: ({ entry }) => entry.replace(/^docs\//, '').replace(MD_EXT, '').toLowerCase(),
    }),
    schema: docsSchema(),
  }),
};
