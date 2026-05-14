---
name: git-clone
description: Clone a GitHub repository locally with the contributor-style two-remote layout when the fork already exists — `upstream` points at the original repo (local default branch tracks it) and `fork` points at an existing fork. Use when the user already has a fork on GitHub (e.g. created earlier, or on another machine) and wants a fresh local clone wired up with upstream + fork remotes, without re-forking or re-applying settings. Keywords - clone fork, clone with upstream, contributor clone, re-clone fork, two-remote clone.
license: Apache-2.0 WITH LLVM-exception
compatibility: Requires git and the GitHub CLI (`gh`), authenticated.
allowed-tools: Bash
---

# git-clone

Clone a GitHub repository locally and configure two remotes against an
**existing** fork:

- `upstream` → the original repository. The local default branch tracks
  `upstream/<default>`.
- `fork` → the user's (or a specified org's) pre-existing fork.

Unlike `agitentic:git-fork`, this skill does **not** create the fork on
GitHub and does **not** apply repo settings. Use it when the fork already
exists and you just need a local clone wired up the same way.

## When to use this skill

Use this skill when the user asks to:

- "Clone my fork of X with upstream and fork remotes."
- "Re-clone X on this machine" (fork already exists from prior work).
- "Set up a local contributor clone of X — my fork is already on GitHub."

Do **not** use this skill when:

- The fork doesn't exist yet. Use `agitentic:git-fork` instead — it
  creates the fork, clones, and applies repo settings.
- The user just wants a plain clone. Use `git clone` directly.
- The user wants to push an existing local repo up as a new GitHub repo.
  Use `agitentic:git-create` or `gh repo create --source=.`.

## How to invoke

Run the bundled script:

```
scripts/git-clone <repo> [name] [account] [directory]
```

- `<repo>` (required) — the upstream repository. Accepts `owner/name` or
  any GitHub HTTPS / SSH URL (`https://github.com/owner/name`,
  `git@github.com:owner/name.git`, etc.).
- `[name]` (optional) — the name of the existing fork on GitHub (and
  the default local directory). Defaults to the upstream repo name.
  Pass `""` to use the default while still specifying `[account]` or
  `[directory]`.
- `[account]` (optional) — the owner of the existing fork. Defaults to
  the currently authenticated `gh` user. Pass `""` to use the default
  while still specifying `[directory]`.
- `[directory]` (optional) — local directory to clone into. Defaults to
  `[name]`.

The script:

1. Verifies the fork `<account>/<name>` exists on GitHub (via
   `gh repo view`). Fails if not found.
2. Clones `<repo>` into `./<directory>` with the original as `upstream`.
   The local default branch tracks `upstream/<default>`.
3. Adds a `fork` remote pointing at `<account>/<name>`.

The script refuses to overwrite an existing `./<directory>`, and refuses
to run if `<account>/<name>` matches the upstream (there's no fork to
wire up in that case).

## Examples

User: "Clone my fork of brevdev/brev-cli"

Run, from the directory where the user wants the clone to land:

```
scripts/git-clone brevdev/brev-cli
```

User: "Clone nvidia/cccl — my fork is named autocuda-cccl"

```
scripts/git-clone nvidia/cccl autocuda-cccl
```

User: "Clone brevdev/brev-cli — my fork lives under the acme org"

```
scripts/git-clone brevdev/brev-cli "" acme
```

User: "Clone brevdev/brev-cli into ~/work/brev (my fork under my user)"

```
cd ~/work && scripts/git-clone brevdev/brev-cli "" "" brev
```

After the script returns, show the user `git -C <directory> remote -v`
so the two-remote layout is visible.

## Requirements

- `git`
- `gh` (GitHub CLI), authenticated. The skill uses `gh api user --jq
  .login` to discover the default account and `gh repo view` to verify
  the fork exists.
