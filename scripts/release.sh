#!/usr/bin/env bash
#
# Cut a release.
#
# Every step here exists because something looked done and was not: a tag that
# pointed at a red commit, a visibility change that never applied, a Marketplace
# publish that silently did nothing. The script does the mechanical parts and
# then checks the result rather than assuming it.
#
# Usage:
#   scripts/release.sh 0.3.0
#   scripts/release.sh 0.3.0 --dry-run
#
set -euo pipefail

VERSION="${1:-}"
DRY_RUN="false"
for arg in "$@"; do
    if [ "${arg}" = "--dry-run" ]; then DRY_RUN="true"; fi
done

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
die()  { echo "${RED}error:${OFF} $*" >&2; exit 1; }
ok()   { echo "${GREEN}✓${OFF} $*"; }
warn() { echo "${YELLOW}!${OFF} $*"; }
step() { echo; echo "${DIM}── $* ──${OFF}"; }
run()  { if [ "${DRY_RUN}" = "true" ]; then echo "${DIM}would run:${OFF} $*"; else "$@"; fi; }

# ── 0. Arguments ─────────────────────────────────────────────────────────────
if [ -z "${VERSION}" ]; then
    die "usage: scripts/release.sh <version> [--dry-run]   (e.g. 0.3.0, without a leading v)"
fi
case "${VERSION}" in
    v*) die "pass the version without a leading 'v' (got '${VERSION}')" ;;
esac
if ! printf '%s' "${VERSION}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'; then
    die "'${VERSION}' is not semver (expected N.N.N, optionally -suffix)"
fi
TAG="v${VERSION}"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "Releasing ${TAG} of ${REPO}"
if [ "${DRY_RUN}" = "true" ]; then warn "dry run — nothing will be pushed"; fi

# ── 1. The tree must be clean, current, and on the default branch ────────────
step "Preflight"
DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "${BRANCH}" != "${DEFAULT_BRANCH}" ]; then
    die "on '${BRANCH}', expected '${DEFAULT_BRANCH}' — releases are cut from the default branch"
fi
if [ -n "$(git status --porcelain)" ]; then
    die "working tree is dirty — commit or stash first"
fi
git fetch -q origin
LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse "origin/${DEFAULT_BRANCH}")"
if [ "${LOCAL}" != "${REMOTE}" ]; then
    die "local ${DEFAULT_BRANCH} differs from origin — pull or push first"
fi
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    die "tag ${TAG} already exists locally"
fi
if gh release view "${TAG}" >/dev/null 2>&1; then
    die "release ${TAG} already exists on ${REPO}"
fi
ok "on ${DEFAULT_BRANCH}, clean, in sync with origin, ${TAG} is free"

# ── 2. Release notes come from the CHANGELOG ─────────────────────────────────
# Deliberately not generated. If nobody wrote down what changed, that is a
# reason to stop, not a reason to publish an empty release.
step "Release notes"
if [ ! -f CHANGELOG.md ]; then die "no CHANGELOG.md"; fi
NOTES="$(awk -v tag="## ${TAG}" '
    $0 == tag { found = 1; next }
    found && /^## / { exit }
    found { print }
' CHANGELOG.md | sed -e '/./,$!d' | awk 'BEGIN{RS="";ORS="\n"}1')"
if [ -z "${NOTES}" ]; then
    die "CHANGELOG.md has no '## ${TAG}' section — write the notes first"
fi
echo "${NOTES}" | sed 's/^/  /'
ok "notes extracted from CHANGELOG.md"

# ── 3. Never tag a commit CI has not blessed ─────────────────────────────────
step "CI"
SHA="$(git rev-parse HEAD)"
echo "waiting for checks on ${SHA:0:7} ..."
DEADLINE=$(( $(date +%s) + 1800 ))
STATUS=""
while true; do
    STATUS="$(gh run list --commit "${SHA}" --limit 20 --json status,conclusion \
        -q 'if length == 0 then "none" elif all(.[]; .status == "completed") then (if any(.[]; .conclusion != "success") then "failure" else "success" end) else "running" end' 2>/dev/null || echo none)"
    case "${STATUS}" in
        success|failure) break ;;
        none)
            warn "no workflow runs found for this commit"
            break ;;
    esac
    if [ "$(date +%s)" -gt "${DEADLINE}" ]; then die "timed out waiting for CI"; fi
    sleep 10
done
if [ "${STATUS}" = "failure" ]; then
    die "CI is red on ${SHA:0:7} — a tag must not point at a broken commit"
fi
if [ "${STATUS}" = "success" ]; then ok "CI green on ${SHA:0:7}"; fi

# ── 4. Tag, push, release ────────────────────────────────────────────────────
step "Tag and publish"
run git tag -a "${TAG}" -m "${TAG}"
run git push origin "${TAG}"
if [ "${DRY_RUN}" = "true" ]; then
    echo "${DIM}would run:${OFF} gh release create ${TAG} --title ${TAG} --notes <CHANGELOG section>"
else
    printf '%s\n' "${NOTES}" | gh release create "${TAG}" --title "${TAG}" --notes-file -
fi
ok "released ${TAG}"

if [ "${DRY_RUN}" = "true" ]; then echo; warn "dry run finished — nothing was pushed"; exit 0; fi

# ── 5. Verify, rather than assume ────────────────────────────────────────────
step "Verify"
sleep 3
if gh release view "${TAG}" --json tagName -q .tagName >/dev/null 2>&1; then
    ok "release ${TAG} exists"
else
    die "release ${TAG} was not created"
fi
if git ls-remote --tags origin "refs/tags/${TAG}" | grep -q .; then
    ok "tag ${TAG} is on origin"
else
    die "tag ${TAG} did not reach origin"
fi

# Marketplace publication is a manual, 2FA-gated UI step — it cannot be done
# from here, and it silently does nothing if the org has not accepted the
# Developer Agreement. So check the listing rather than trust that it happened.
if [ -f action.yml ]; then
    NAME="$(grep -m1 '^name:' action.yml | sed -E "s/^name: *['\"]?//; s/['\"]? *$//")"
    SLUG="$(printf '%s' "${NAME}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -E 's/^-+//; s/-+$//')"
    URL="https://github.com/marketplace/actions/${SLUG}"
    CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "${URL}" || echo 000)"
    if [ "${CODE}" = "200" ]; then
        ok "Marketplace listing live — ${URL}"
    else
        warn "Marketplace listing not found (HTTP ${CODE} for ${URL})"
        echo "    Publishing is a manual UI step and is easy to believe you have done:"
        echo "      1. https://github.com/${REPO}/releases/edit/${TAG}"
        echo "      2. Accept the Marketplace Developer Agreement (org-level) if the box is padlocked"
        echo "      3. Tick 'Publish this release to the GitHub Marketplace', pick a category, Update release"
        echo "    Re-check with: curl -s -o /dev/null -w '%{http_code}' ${URL}"
    fi
fi

echo
ok "done — https://github.com/${REPO}/releases/tag/${TAG}"
