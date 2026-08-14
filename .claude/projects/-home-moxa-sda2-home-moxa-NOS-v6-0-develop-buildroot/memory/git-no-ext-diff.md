---
name: git-no-ext-diff
description: "User's git has git-meld.sh as external diff — always use --no-ext-diff or meld GUI pops up"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 06089eea-89b1-4ba6-91e6-624dca2bad18
---

The user's git config has `diff.external = /home/moxa/git-meld.sh`, so any `git diff` / `git show` / `git log -p` that emits a patch body launches the **meld GUI** — in a 100+ repo loop that means 100+ windows.

**Why:** user explicitly complained 2026-06-15 ("git diff會觸發meld，請您確認無誤就好，不用一直把meld叫出來"). They want the *conclusion*, not the diff shown.

**How to apply:** always add `--no-ext-diff` to git diff/show/log that would print a patch (belt-and-suspenders: `git -c diff.external= ... --no-ext-diff`). `--name-only` / `--stat` are safe. And when verifying, report the verdict — don't dump diffs at them.
