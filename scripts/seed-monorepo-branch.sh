#!/usr/bin/env bash
# scripts/seed-monorepo-branch.sh
#
# One-shot maintainer runbook for ADR 0001 Steps 10–14 (and Step 15 prep):
# seeds the `cmremote/v0.17.0-aws-lc-rs` monorepo-fork branch from
# `webrtc-rs/webrtc@v0.17.0` with disjoint git history, applies the four
# `ring` -> `aws-lc-rs` substitutions across `dtls/`, `stun/`, `turn/`,
# `webrtc/`, edits the four matching `Cargo.toml` files, drops the
# workspace-scoped CI workflow into place, and (optionally) runs
# `cargo test --workspace`.
#
# This script intentionally does **not** push the branch or create the
# `v0.17.0-cmremote.1` tag — Steps 15 and 16 are gated on a clean
# `cargo test --workspace` plus a maintainer's review of the diff. The
# script prints the exact `git push` and `git tag` commands at the end.
#
# Source of truth:
#   CMRemote/docs/decisions/0001-spike-fork-instructions.md §§10–18
#
# Usage (from inside a clean checkout of CrashMediaIT/webrtc-cmremote):
#   scripts/seed-monorepo-branch.sh           # seed + edit, skip cargo test
#   scripts/seed-monorepo-branch.sh --test    # also run cargo test --workspace
#   scripts/seed-monorepo-branch.sh --force   # delete an existing local
#                                             # cmremote/v0.17.0-aws-lc-rs first
#
# Prerequisites: git, sed (GNU), python3 (used for precise TOML edits),
# and — if --test is passed — a stable Rust toolchain plus the build
# prerequisites for `aws-lc-rs` (cmake on all platforms; NASM on Windows).
#
# The script is idempotent in the sense that re-running it on a fresh
# clone produces the same branch state. It is **not** safe to re-run on
# top of a partially-seeded branch — pass --force, or delete the local
# branch by hand, before re-running.

set -euo pipefail

# ----- configuration ---------------------------------------------------------

UPSTREAM_REMOTE="upstream-monorepo"
UPSTREAM_URL="https://github.com/webrtc-rs/webrtc.git"
UPSTREAM_TAG="v0.17.0"
FORK_BRANCH="cmremote/v0.17.0-aws-lc-rs"
FORK_TAG="v0.17.0-cmremote.1"

RUN_TESTS=0
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --test)  RUN_TESTS=1 ;;
        --force) FORCE=1 ;;
        -h|--help)
            sed -n '2,37p' "$0"
            exit 0
            ;;
        *)
            echo "error: unknown argument: $arg" >&2
            exit 2
            ;;
    esac
done

# ----- helpers ---------------------------------------------------------------

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> warning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==> error:\033[0m %s\n' "$*" >&2; exit 1; }

require_clean_worktree() {
    if [[ -n "$(git status --porcelain)" ]]; then
        die "working tree is not clean; commit or stash changes before seeding"
    fi
}

repo_root() {
    git rev-parse --show-toplevel
}

# ----- preflight -------------------------------------------------------------

command -v git     >/dev/null || die "git is required"
command -v sed     >/dev/null || die "sed is required"
command -v python3 >/dev/null || die "python3 is required (used for TOML edits)"

ROOT="$(repo_root)"
cd "$ROOT"

# Sanity: this script must be run from inside CrashMediaIT/webrtc-cmremote.
ORIGIN_URL="$(git config --get remote.origin.url || true)"
case "$ORIGIN_URL" in
    *CrashMediaIT/webrtc-cmremote*) ;;
    *) die "expected to be run inside a clone of CrashMediaIT/webrtc-cmremote (got origin: $ORIGIN_URL)" ;;
esac

require_clean_worktree

# Refuse to clobber the branch unless --force.
if git show-ref --verify --quiet "refs/heads/${FORK_BRANCH}"; then
    if [[ "$FORCE" -eq 1 ]]; then
        log "deleting existing local branch ${FORK_BRANCH} (--force)"
        # If we're currently on it, jump off first.
        if [[ "$(git symbolic-ref --short -q HEAD || true)" == "${FORK_BRANCH}" ]]; then
            git checkout --quiet --detach
        fi
        git branch -D "${FORK_BRANCH}"
    else
        die "local branch ${FORK_BRANCH} already exists; pass --force to recreate"
    fi
fi

# ----- Step 10 — add upstream-monorepo remote, fetch v0.17.0 -----------------

log "Step 10: ensuring '${UPSTREAM_REMOTE}' remote points at ${UPSTREAM_URL}"
if existing_url="$(git config --get "remote.${UPSTREAM_REMOTE}.url" || true)" && [[ -n "$existing_url" ]]; then
    if [[ "$existing_url" != "$UPSTREAM_URL" ]]; then
        die "remote '${UPSTREAM_REMOTE}' exists but points at '${existing_url}', not '${UPSTREAM_URL}'"
    fi
else
    git remote add "${UPSTREAM_REMOTE}" "${UPSTREAM_URL}"
fi

log "Step 10: fetching tags from ${UPSTREAM_REMOTE}"
git fetch --tags "${UPSTREAM_REMOTE}"

if ! git rev-parse --verify --quiet "refs/tags/${UPSTREAM_TAG}^{commit}" >/dev/null; then
    die "upstream tag ${UPSTREAM_TAG} not found after fetch"
fi

log "Step 10: creating ${FORK_BRANCH} from ${UPSTREAM_TAG} (disjoint from main)"
git checkout -b "${FORK_BRANCH}" "${UPSTREAM_TAG}"

# Sanity: the new branch must share zero history with main. The dtls v0.5.4
# fork lives on a different rooted history; the immutability guarantee in
# ADR 0001 §10 depends on the two never being merged.
if git merge-base --is-ancestor "main" "HEAD" 2>/dev/null; then
    warn "${FORK_BRANCH} unexpectedly contains 'main' as an ancestor; the disjoint-history guarantee in ADR 0001 §10 may be violated"
fi

# ----- Steps 11–14 — sed substitutions, scoped per crate ---------------------

apply_seds() {
    local crate="$1"
    shift
    local -a expressions=("$@")

    # `git ls-files <prefix>` recurses into the prefix and lists every
    # tracked file; we filter to *.rs ourselves so the substitution is
    # byte-deterministic and doesn't touch any untracked maintainer scratch
    # files. Using a prefix (not a `**/*.rs` glob) is required because
    # git's pathspec globbing does not expand `**` in this context.
    local files
    files="$(git ls-files "${crate}/src" | grep -E '\.rs$' | sort -u || true)"
    if [[ -z "$files" ]]; then
        die "no source files found under ${crate}/src/ — has upstream layout drifted?"
    fi

    local sed_args=()
    for e in "${expressions[@]}"; do
        sed_args+=(-e "$e")
    done

    # NUL-terminate filenames for portable xargs (avoids GNU-specific `-d`).
    printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 -n 64 sed -i "${sed_args[@]}"

    # Verification: word-boundary check on `\bring\b`. The runbook's
    # `! grep -rn 'ring' src/` false-positives on String::, Ordering::,
    # from_utf8, server_name, etc.; PR #2 documented the corrected pattern.
    local stray
    stray="$(grep -rn -E '\b(use ring|ring::|extern crate ring)\b' "${crate}/src/" || true)"
    if [[ -n "$stray" ]]; then
        echo "$stray" >&2
        die "Step ${crate}: stray ring references remain after substitution"
    fi
}

log "Step 11: substituting ring -> aws_lc_rs in dtls/src/"
apply_seds dtls \
    's|use ring::|use aws_lc_rs::|g' \
    's|ring::signature::|aws_lc_rs::signature::|g' \
    's|ring::rand::|aws_lc_rs::rand::|g' \
    's|ring::hmac::|aws_lc_rs::hmac::|g'

log "Step 12: substituting ring -> aws_lc_rs in stun/src/"
apply_seds stun \
    's|use ring::|use aws_lc_rs::|g' \
    's|ring::hmac::|aws_lc_rs::hmac::|g'

log "Step 13: substituting ring -> aws_lc_rs in turn/src/"
apply_seds turn \
    's|use ring::|use aws_lc_rs::|g' \
    's|ring::hmac::|aws_lc_rs::hmac::|g'

log "Step 14: substituting ring -> aws_lc_rs in webrtc/src/"
apply_seds webrtc \
    's|use ring::|use aws_lc_rs::|g' \
    's|ring::signature::|aws_lc_rs::signature::|g' \
    's|ring::rand::|aws_lc_rs::rand::|g' \
    's|ring::hmac::|aws_lc_rs::hmac::|g' \
    's|ring::digest::|aws_lc_rs::digest::|g'

# ----- Steps 11–14 — Cargo.toml edits, line-precise via python3 --------------

# We use python3 instead of sed for the manifest edits because the upstream
# `rustls` and `rcgen` lines contain `[`, `]`, and `=` characters that are
# painful to escape correctly across BSD/GNU sed. python3 lets us match the
# exact upstream string captured in the ADR.

python3 - <<'PY'
import pathlib
import sys

class EditError(RuntimeError):
    pass

def edit(path, replacements, *, must_remove=(), must_add=()):
    p = pathlib.Path(path)
    text = p.read_text()
    original = text
    for old, new in replacements:
        if old not in text:
            raise EditError(f"{path}: expected line not found:\n  {old!r}\n"
                            f"upstream layout may have drifted from v0.17.0")
        if text.count(old) != 1:
            raise EditError(f"{path}: expected line is not unique:\n  {old!r}")
        text = text.replace(old, new)
    for tok in must_remove:
        if tok in text:
            raise EditError(f"{path}: post-edit token still present: {tok!r}")
    for tok in must_add:
        if tok not in text:
            raise EditError(f"{path}: post-edit token missing: {tok!r}")
    if text == original:
        raise EditError(f"{path}: no edits applied")
    p.write_text(text)
    print(f"  edited {path}")

try:
    # dtls/Cargo.toml — Step 11: drop ring, swap rustls feature, expand rcgen
    edit(
        "dtls/Cargo.toml",
        [
            (
                'rcgen = "0.13"\n'
                'ring = "0.17.14"\n'
                'rustls = { version = "0.23.27", default-features = false, features = ["std", "ring"] }\n',
                'rcgen = { version = "0.13", default-features = false, features = ["aws_lc_rs", "pem"] }\n'
                'aws-lc-rs = "1"\n'
                'rustls = { version = "0.23.27", default-features = false, features = ["std", "aws_lc_rs"] }\n',
            ),
        ],
        must_remove=('ring = "0.17.14"', '"std", "ring"'),
        must_add=('aws-lc-rs = "1"', '"std", "aws_lc_rs"'),
    )

    # stun/Cargo.toml — Step 12
    edit(
        "stun/Cargo.toml",
        [
            (
                'ring = "0.17.14"\n',
                'aws-lc-rs = "1"\n',
            ),
        ],
        must_remove=('ring = "0.17.14"',),
        must_add=('aws-lc-rs = "1"',),
    )

    # turn/Cargo.toml — Step 13
    edit(
        "turn/Cargo.toml",
        [
            (
                'ring = "0.17.14"\n',
                'aws-lc-rs = "1"\n',
            ),
        ],
        must_remove=('ring = "0.17.14"',),
        must_add=('aws-lc-rs = "1"',),
    )

    # webrtc/Cargo.toml — Step 14: drop ring, expand rcgen feature list
    edit(
        "webrtc/Cargo.toml",
        [
            (
                'rcgen = { version = "0.13", features = ["pem", "x509-parser"] }\n'
                'ring = "0.17.14"\n',
                'rcgen = { version = "0.13", default-features = false, features = ["aws_lc_rs", "pem", "x509-parser"] }\n'
                'aws-lc-rs = "1"\n',
            ),
        ],
        must_remove=('ring = "0.17.14"',),
        must_add=('aws-lc-rs = "1"', '"aws_lc_rs", "pem", "x509-parser"'),
    )
except EditError as e:
    print(f"error: {e}", file=sys.stderr)
    sys.exit(1)
PY

# ----- Step 15 prep — drop the workspace-scoped CI workflow ------------------

TEMPLATE_DIR="${ROOT}/scripts/monorepo-template"
if [[ ! -d "$TEMPLATE_DIR" ]]; then
    # When this branch is checked out from upstream v0.17.0 the scripts/
    # tree from main isn't present; reach into the previous HEAD to grab it.
    die "scripts/monorepo-template/ not found on the new branch — re-run from the main checkout, then this script will copy it forward"
fi

mkdir -p .github/workflows
log "Step 15 prep: installing workspace-scoped CI workflow at .github/workflows/ci.yml"
cp "${TEMPLATE_DIR}/ci.yml" .github/workflows/ci.yml

if [[ -f "${TEMPLATE_DIR}/MAINTENANCE.md" ]]; then
    log "Step 18: installing sibling MAINTENANCE.md on the monorepo branch"
    cp "${TEMPLATE_DIR}/MAINTENANCE.md" MAINTENANCE.md
fi

# ----- commit ----------------------------------------------------------------

git add -A
git -c user.email="cmremote-maintainers@users.noreply.github.com" \
    -c user.name="CMRemote monorepo fork bot" \
    commit -m "Seed cmremote/v0.17.0-aws-lc-rs from webrtc-rs/webrtc@${UPSTREAM_TAG}

Per ADR 0001 §§10–14:
  - drop ring, add aws-lc-rs, swap rustls feature in dtls/Cargo.toml
  - drop ring, add aws-lc-rs in stun/Cargo.toml
  - drop ring, add aws-lc-rs in turn/Cargo.toml
  - drop ring, expand rcgen feature list in webrtc/Cargo.toml
  - mechanical sed: ring:: -> aws_lc_rs:: across dtls/, stun/, turn/, webrtc/
  - install workspace-scoped 5-triple CI matrix (Step 15)
  - install sibling MAINTENANCE.md (Step 18)

Generated by scripts/seed-monorepo-branch.sh."

# ----- Step 15 — optional cargo test ----------------------------------------

if [[ "$RUN_TESTS" -eq 1 ]]; then
    log "Step 15: running cargo test --workspace (this is slow)"
    cargo test --workspace
else
    log "Step 15: skipped (re-run with --test to execute cargo test --workspace)"
fi

# ----- finishing instructions for the maintainer -----------------------------

cat <<EOF

==> Done. The ${FORK_BRANCH} branch is seeded locally with a single
    commit on top of webrtc-rs/webrtc@${UPSTREAM_TAG}. It shares no
    history with 'main' (per ADR 0001 §10).

Next steps for the maintainer (NOT performed by this script):

  1. Verify the diff:

       git log --stat HEAD~1..HEAD
       git diff ${UPSTREAM_TAG}..HEAD

  2. Run cross-platform CI by pushing the branch (Step 15):

       git push -u origin ${FORK_BRANCH}

     Wait for the 5-triple matrix in .github/workflows/ci.yml to go
     green on the push.

  3. Once CI is green, tag the fork (Step 16):

       git tag -a ${FORK_TAG} \\
           -m "CMRemote v0.17.0 monorepo fork: ring -> aws-lc-rs in webrtc/, dtls/, stun/, turn/"
       git push origin ${FORK_TAG}

  4. Open the slice R7.m driver PR in CrashMediaIT/CMRemote
     (Step 17) extending agent-rs/Cargo.toml [patch.crates-io].

  5. Ensure the cmremote/* branch protection rule and v*-cmremote.*
     tag protection rule from GITHUB_SETTINGS.md §§4a–4b cover
     ${FORK_BRANCH} and ${FORK_TAG} (no settings change needed if the
     existing patterns are already in place).
EOF
