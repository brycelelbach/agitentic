#!/usr/bin/env bats
#
# End-to-end tests for git-clone. Unlike git-fork, git-clone expects the
# fork to already exist on GitHub — so every test seeds *both* bare
# repos up front.

setup() {
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/lib.bash"
  GIT_CLONE="$(agitentic_script git-clone)"

  TMP="$(mktemp -d)"
  setup_gh_stub "$TMP"
  seed_bare_repo "orig/repo"
  seed_bare_repo "testuser/repo"

  WORK="$TMP/work"
  mkdir -p "$WORK"
  cd "$WORK"
}

teardown() {
  rm -rf "$TMP"
}

gh_log_matches() {
  grep -E -c "$1" "$STUB_GH_LOG" || true
}

@test "git-clone clones upstream and wires up fork remote" {
  run "$GIT_CLONE" orig/repo
  [ "$status" -eq 0 ]

  [ -d "$WORK/repo/.git" ]
  [ "$(git -C "$WORK/repo" config --get remote.upstream.url)" = "https://github.com/orig/repo.git" ]
  [ "$(git -C "$WORK/repo" config --get remote.fork.url)"     = "https://github.com/testuser/repo.git" ]

  # Fork existence was verified, but no fork/edit calls were made.
  [ "$(gh_log_matches '^gh repo view testuser/repo --json name$')" -eq 1 ]
  [ "$(gh_log_matches '^gh repo fork ')" -eq 0 ]
  [ "$(gh_log_matches '^gh repo edit ')" -eq 0 ]
}

@test "git-clone honours [account] and [directory]" {
  seed_bare_repo "myorg/repo"
  run "$GIT_CLONE" orig/repo myorg my-dir
  [ "$status" -eq 0 ]

  [ -d "$WORK/my-dir/.git" ]
  [ "$(git -C "$WORK/my-dir" config --get remote.upstream.url)" = "https://github.com/orig/repo.git" ]
  [ "$(git -C "$WORK/my-dir" config --get remote.fork.url)"     = "https://github.com/myorg/repo.git" ]
  [ "$(gh_log_matches '^gh repo view myorg/repo --json name$')" -eq 1 ]
  # With [account] explicit, no gh api user call.
  [ "$(gh_log_matches '^gh api user')" -eq 0 ]
}

@test "git-clone errors out when the fork does not exist on GitHub" {
  export STUB_GH_MISSING="testuser/repo"
  run "$GIT_CLONE" orig/repo
  [ "$status" -eq 1 ]
  [[ "$output" == *"fork testuser/repo not found"* ]]
  # Nothing should have been cloned locally.
  [ ! -d "$WORK/repo" ]
}

@test "git-clone refuses when [account] is the upstream owner" {
  run "$GIT_CLONE" orig/repo orig
  [ "$status" -eq 1 ]
  [[ "$output" == *"is the upstream owner"* ]]
  # Should reject before any gh or clone call.
  [ "$(gh_log_matches '^gh repo ')" -eq 0 ]
  [ ! -d "$WORK/repo" ]
}

@test "git-clone refuses when target directory already exists" {
  mkdir "$WORK/repo"
  run "$GIT_CLONE" orig/repo
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}
