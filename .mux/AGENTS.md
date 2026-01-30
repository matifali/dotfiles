---
title: AGENTS.md
description: Agent instructions for mux
---

## Coder Workspace GitHub Auth
When running in a Coder workspace (`CODER=1` environment variable is set):
- Obtain GitHub token via: `coder external-auth access-token github`
- Use the token to authenticate `git` and `gh` CLI:
  ```bash
  export GH_TOKEN=$(coder external-auth access-token github)
  # or GITHUB_TOKEN — both work for gh CLI
  gh auth status  # verify auth
  ```

## PR + Release Workflow
- Always include this footer in the body:

  ```md
  ---
  _Generated with `mux` • Model: `<modelString>` • Thinking: `<thinkingLevel>`_
  <!-- mux-attribution: model=<modelString> thinking=<thinkingLevel> -->
  ```
  Prefer sourcing values from `$MUX_MODEL_STRING` and `$MUX_THINKING_LEVEL` (bash tool env).

- Reuse existing PRs; never close or recreate without instruction. Force-push updates.
