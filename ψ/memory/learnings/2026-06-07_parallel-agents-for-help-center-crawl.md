---
title: Parallel agent swarms for help center crawling — 5 agents cut 30-min crawl to 4-min batches
tags: [research, agents, parallel, web-crawl, help-center, officeboy]
created: 2026-06-07
source: rrr-session
project: github.com/dryoungdo/officeboy-oracle
gate_hook: use-parallel-agents-for-independent-article-downloads
---

# Parallel agent swarms for help center crawling

When downloading articles from a structured help center (like ByteHR's 170+ articles across 12 categories), spawning 5 parallel agents — each handling a group of categories — reduced total download time from ~30 minutes sequential to ~4 minutes per batch.

**Pattern**: Group articles by category, assign each group to an agent, let them WebFetch + compile independently. Each agent writes to its own output file — no file conflicts.

**Limitation discovered**: WebFetch's AI summarization compresses original content. For NotebookLM document preparation where raw text matters, a raw download approach (curl + html-to-markdown) may be better than WebFetch's AI-processed summaries.

**When to apply**: Any research task involving 20+ independent articles from a single help center or documentation site. Always default to parallel agents when articles are independent (no cross-references needed during download).
