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
  run "$GIT_CLONE" orig/repo "" myorg my-dir
  [ "$status" -eq 0 ]

  [ -d "$WORK/my-dir/.git" ]
  [ "$(git -C "$WORK/my-dir" config --get remote.upstream.url)" = "https://github.com/orig/repo.git" ]
  [ "$(git -C "$WORK/my-dir" config --get remote.fork.url)"     = "https://github.com/myorg/repo.git" ]
  [ "$(gh_log_matches '^gh repo view myorg/repo --json name$')" -eq 1 ]
  # With [account] explicit, no gh api user call.
  [ "$(gh_log_matches '^gh api user')" -eq 0 ]
}

@test "git-clone honours [name] and wires up a renamed fork" {
  seed_bare_repo "testuser/my-fork"
  run "$GIT_CLONE" orig/repo my-fork
  [ "$status" -eq 0 ]

  # Local clone directory defaults to [name].
  [ -d "$WORK/my-fork/.git" ]
  [ "$(git -C "$WORK/my-fork" config --get remote.upstream.url)" = "https://github.com/orig/repo.git" ]
  [ "$(git -C "$WORK/my-fork" config --get remote.fork.url)"     = "https://github.com/testuser/my-fork.git" ]
  # Existence check used the renamed fork slug.
  [ "$(gh_log_matches '^gh repo view testuser/my-fork --json name$')" -eq 1 ]
}

@test "git-clone combines [name] and [account] for a renamed org fork" {
  seed_bare_repo "myorg/my-fork"
  run "$GIT_CLONE" orig/repo my-fork myorg
  [ "$status" -eq 0 ]

  [ -d "$WORK/my-fork/.git" ]
  [ "$(git -C "$WORK/my-fork" config --get remote.fork.url)" = "https://github.com/myorg/my-fork.git" ]
  [ "$(gh_log_matches '^gh repo view myorg/my-fork --json name$')" -eq 1 ]
}

@test "git-clone [name] with explicit [directory] separates the two" {
  seed_bare_repo "testuser/my-fork"
  run "$GIT_CLONE" orig/repo my-fork "" custom-dir
  [ "$status" -eq 0 ]

  [ -d "$WORK/custom-dir/.git" ]
  [ ! -d "$WORK/my-fork" ]
  [ "$(git -C "$WORK/custom-dir" config --get remote.fork.url)" = "https://github.com/testuser/my-fork.git" ]
}

@test "git-clone errors out when the renamed fork does not exist on GitHub" {
  export STUB_GH_MISSING="testuser/missing-fork"
  run "$GIT_CLONE" orig/repo missing-fork
  [ "$status" -eq 1 ]
  [[ "$output" == *"fork testuser/missing-fork not found"* ]]
  [ ! -d "$WORK/missing-fork" ]
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
  run "$GIT_CLONE" orig/repo "" orig
  [ "$status" -eq 1 ]
  [[ "$output" == *"is the upstream"* ]]
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

@test "git-clone accepts an https URL" {
  run "$GIT_CLONE" https://github.com/orig/repo.git
  [ "$status" -eq 0 ]
  [ -d "$WORK/repo/.git" ]
  [ "$(git -C "$WORK/repo" config --get remote.upstream.url)" = "https://github.com/orig/repo.git" ]
}

@test "git-clone accepts an ssh URL" {
  run "$GIT_CLONE" git@github.com:orig/repo.git
  [ "$status" -eq 0 ]
  [ -d "$WORK/repo/.git" ]
}

@test "git-clone passes \"\" as [account] to use default" {
  run "$GIT_CLONE" orig/repo "" "" custom-dir
  [ "$status" -eq 0 ]
  [ -d "$WORK/custom-dir/.git" ]
  [ "$(git -C "$WORK/custom-dir" config --get remote.fork.url)" = "https://github.com/testuser/repo.git" ]
}

@test "git-clone exits 1 when git is not on PATH" {
  PATH="$AGITENTIC_NO_GIT_NO_GH_PATH" run /bin/bash "$GIT_CLONE" orig/repo
  [ "$status" -eq 1 ]
  [[ "$output" == *"'git' is required"* ]]
}

@test "git-clone exits 1 when gh is not on PATH" {
  PATH="$AGITENTIC_NO_GH_PATH" run /bin/bash "$GIT_CLONE" orig/repo
  [ "$status" -eq 1 ]
  [[ "$output" == *"'gh' (GitHub CLI) is required"* ]]
}
