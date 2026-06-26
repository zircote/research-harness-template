import { defineCollection } from 'astro:content';
import { docsSchema } from '@astrojs/starlight/schema';
import { glob } from 'astro/loaders';

export const collections = {
  docs: defineCollection({
    // Source the harness's top-level Diátaxis docs/ tree. Exclude the local-only
    // proposal drafts (git-ignored, not shipped) and the Jinja instance template.
    loader: glob({
      pattern: ['**/[^_]*.{md,mdx}', '!proposals/**', '!**/*.jinja'],
      base: './docs',
    }),
    schema: docsSchema(),
  }),
};
