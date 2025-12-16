---
title: AGENTS.md
description: Agent instructions for mux
---

## PR + Release Workflow
- Always include this footer in the body:

  ```md
  ---
  _Generated with `mux` • Model: `<modelString>` • Thinking: `<thinkingLevel>`_
  <!-- mux-attribution: model=<modelString> thinking=<thinkingLevel> -->
  ```
  Prefer sourcing values from `$MUX_MODEL_STRING` and `$MUX_THINKING_LEVEL` (bash tool env).

- Reuse existing PRs; never close or recreate without instruction. Force-push updates.