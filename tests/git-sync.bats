#!/usr/bin/env bats
#
# End-to-end tests for git-sync against synthetic upstream + fork bare
# repos built by make_contributor_fixture in tests/lib.bash. No gh auth
# or network access required.

setup() {
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/lib.bash"
  GIT_SYNC="$(agitentic_script git-sync)"
  # BATS_TEST_TMPDIR isn't set before bats 1.6; allocate one explicitly.
  TMP="$(mktemp -d)"
  make_contributor_fixture "$TMP"
  cd "$TMP/local"
}

teardown() {
  rm -rf "$TMP"
}

# ---------------------------------------------------------------------------
# Fast-forward sync (the current-main behaviour)
# ---------------------------------------------------------------------------

@test "git-sync fast-forwards local main and pushes to fork" {
  local upstream_head before
  upstream_head="$(git rev-parse upstream/main)"
  before="$(git rev-parse main)"
  [ "$before" != "$upstream_head" ] # fixture put us behind

  run "$GIT_SYNC"
  [ "$status" -eq 0 ]

  [ "$(git rev-parse main)"      = "$upstream_head" ]
  [ "$(git rev-parse fork/main)" = "$upstream_head" ]
}

# ---------------------------------------------------------------------------
# --prune (forward-compat: skips until git-sync implements --prune)
#
# Asserts:
#   - ff-ancestor branch (strict ancestor of upstream/main)        → pruned
#   - patch-equivalent branch (same change via cherry-pick)         → pruned
#   - novel branch (commit not on upstream at all)                  → kept
#   - current branch (checked out at prune time)                    → kept
#   - main (the synced branch itself)                               → kept
# ---------------------------------------------------------------------------

prune_supported() {
  "$GIT_SYNC" --help 2>&1 | grep -q -- '--prune'
}

@test "git-sync --prune deletes merged branches, keeps novel / current / synced" {
  # Soft skip so this stays green on main until PR#7 (--prune) lands.
  # Avoids bats' skip() because bats <1.6 dereferences
  # $BATS_TEARDOWN_STARTED unguarded, which trips set -u.
  if ! prune_supported; then
    echo "# (soft-skip) git-sync --prune not implemented on this branch"
    return 0
  fi

  git fetch -q upstream main

  # ff-ancestor: strict ancestor of upstream/main → should be pruned.
  git branch ff-ancestor upstream/main~

  # patch-equivalent: same tree change as upstream/main's tip but from a
  # different parent. `git cherry` treats it as already-merged.
  git checkout -q -b patch-src upstream/main~
  git cherry-pick upstream/main >/dev/null
  git branch -f patch-equivalent
  git checkout -q main
  git branch -D patch-src >/dev/null

  # novel: has a commit not on upstream at all → should be kept.
  git branch novel
  git checkout -q novel
  git commit -q --allow-empty -m "novel commit"
  git checkout -q main

  # current: sit on this during the run → must be kept.
  git branch current-branch upstream/main~
  git checkout -q current-branch

  run "$GIT_SYNC" --prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted ff-ancestor"* ]]
  [[ "$output" == *"deleted patch-equivalent"* ]]
  [[ "$output" != *"deleted novel"* ]]
  [[ "$output" != *"deleted current-branch"* ]]
  [[ "$output" != *"deleted main"* ]]

  # Confirm the refs themselves.
  ! git rev-parse --verify --quiet refs/heads/ff-ancestor      >/dev/null
  ! git rev-parse --verify --quiet refs/heads/patch-equivalent >/dev/null
  git rev-parse --verify --quiet refs/heads/novel            >/dev/null
  git rev-parse --verify --quiet refs/heads/current-branch   >/dev/null
}
