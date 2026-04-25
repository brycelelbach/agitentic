# agitentic

Agentic git/GitHub helpers, packaged as
[agentskills.io](https://agentskills.io)-compliant skills and shipped as a
Claude Code plugin.

The first skill is **`git-fork`**: fork a GitHub repo and clone it
locally with the contributor-style two-remote layout —
`upstream` for the original repo, `fork` for your fork — in one shot.

## Skills

- **`agitentic:git-fork`** — fork a GitHub repository and set up local
  remotes for contribution work. The local default branch tracks
  `upstream/<default>`; a `fork` remote points at your fork.

Each skill lives under `plugins/agitentic/skills/<name>/` and is a
self-contained agentskills.io skill (`SKILL.md` + a `scripts/`
directory).

## Install (Claude Code)

The repo is a Claude Code plugin marketplace. Install via:

```
/plugin marketplace add robobryce/agitentic
/plugin install agitentic@robobryce-agitentic
```

Then invoke a skill by name, e.g. `/agitentic:git-fork`.

## Use the script directly (no plugin)

The `git-fork` skill is just a wrapper around a self-contained shell
script. You can use it on its own:

```bash
plugins/agitentic/skills/git-fork/scripts/git-fork <repo> [account]
```

Or drop a copy on your `$PATH` named `git-fork` to make it a `git`
subcommand:

```bash
cp plugins/agitentic/skills/git-fork/scripts/git-fork ~/bin/git-fork
git fork brevdev/brev-cli
```

### `git-fork <repo> [account]`

- `<repo>` — `owner/name`, or a GitHub HTTPS / SSH URL.
- `[account]` — destination owner for the fork. Defaults to the
  authenticated `gh` user.

Example:

```bash
$ git-fork brevdev/brev-cli
==> Cloning brevdev/brev-cli (remote: upstream)
==> Forking brevdev/brev-cli → robobryce/brev-cli
==> Adding fork remote → https://github.com/robobryce/brev-cli.git
==> Done.
fork      https://github.com/robobryce/brev-cli.git (fetch)
fork      https://github.com/robobryce/brev-cli.git (push)
upstream  https://github.com/brevdev/brev-cli.git (fetch)
upstream  https://github.com/brevdev/brev-cli.git (push)
```

`git-fork` requires `git` and the [GitHub CLI](https://cli.github.com/)
(`gh`) on your `$PATH`, and `gh` must be authenticated.

## Project structure

```
.claude-plugin/
  marketplace.json           - Claude Code plugin marketplace manifest
plugins/
  agitentic/
    .claude-plugin/
      plugin.json            - plugin manifest
    skills/
      git-fork/
        SKILL.md             - agentskills.io skill (metadata + instructions)
        scripts/
          git-fork           - the script the skill runs
.github/workflows/ci.yml     - lint scripts, validate manifests, sanity-check skills
LICENSE.txt                  - Apache 2.0 with LLVM exception
```

## License

Apache License 2.0 with LLVM exception. See [`LICENSE.txt`](LICENSE.txt).
