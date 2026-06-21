#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"

VERSION=""
NOTARY_PROFILE="${MIMO_NOTARY_KEYCHAIN_PROFILE:-${MIMO_NOTARY_PROFILE:-}}"
RUN_QA=1
CREATE_TAG=0
PUSH_TAG=0
CREATE_GITHUB_RELEASE=0
DRAFT_RELEASE=0
ALLOW_DIRTY="${MIMO_RELEASE_ALLOW_DIRTY:-0}"

usage() {
  cat >&2 <<USAGE
usage: $0 <version> --notary-profile <profile> [options]

Build a versioned Mimo Desktop Pet DMG, submit it to Apple notarization,
staple the ticket, and verify the final artifact.

Options:
  --notary-profile <profile>   notarytool keychain profile name
  --skip-qa                    skip pre-release unit/docs checks
  --tag                        create annotated git tag v<version> after notarization
  --push-tag                   push v<version> after creating/validating the tag
  --github-release             create a GitHub release with the DMG and checksum
  --draft                      create the GitHub release as a draft
  -h, --help                   show this help

Environment:
  MIMO_NOTARY_KEYCHAIN_PROFILE notarytool keychain profile fallback
  MIMO_APP_BUILD               forwarded to package_release.sh as CFBundleVersion
  MIMO_CODESIGN_IDENTITY       forwarded Developer ID Application identity override
  MIMO_RELEASE_ALLOW_DIRTY=1   allow a dirty worktree

Before first use, store credentials once:
  xcrun notarytool store-credentials <profile> --apple-id <apple-id> --team-id DZZW99M6D8
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notary-profile)
      if [[ $# -lt 2 ]]; then
        usage
        exit 2
      fi
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --skip-qa)
      RUN_QA=0
      shift
      ;;
    --tag)
      CREATE_TAG=1
      shift
      ;;
    --push-tag)
      CREATE_TAG=1
      PUSH_TAG=1
      shift
      ;;
    --github-release)
      CREATE_TAG=1
      PUSH_TAG=1
      CREATE_GITHUB_RELEASE=1
      shift
      ;;
    --draft)
      DRAFT_RELEASE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$VERSION" ]]; then
        VERSION="$1"
        shift
      else
        usage
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$VERSION" || -z "$NOTARY_PROFILE" ]]; then
  usage
  exit 2
fi

if [[ ! "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([.-][A-Za-z0-9]+)?$ ]]; then
  echo "version must look like 0.0.1, got: $VERSION" >&2
  exit 2
fi

TAG="v$VERSION"
RELEASE_DIR="$ROOT_DIR/dist/release/$TAG"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
RELEASE_NOTES="$RELEASE_DIR/github-release-notes.md"

cd "$REPO_ROOT"

if [[ "$ALLOW_DIRTY" != "1" && -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  echo "worktree is not clean; commit or stash changes before release" >&2
  git status --short
  exit 1
fi

if [[ "$CREATE_TAG" == "1" ]]; then
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    TAG_COMMIT="$(git rev-list -n 1 "$TAG")"
    HEAD_COMMIT="$(git rev-parse HEAD)"
    if [[ "$TAG_COMMIT" != "$HEAD_COMMIT" ]]; then
      echo "tag $TAG already exists and does not point at HEAD" >&2
      exit 1
    fi
  fi
fi

echo "Validating notary keychain profile: $NOTARY_PROFILE"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null

if [[ "$RUN_QA" == "1" ]]; then
  echo "Running pre-release checks..."
  (
    cd "$ROOT_DIR"
    swift test --quiet
    ./script/check_docs_contract.py
  )
  git diff --check
fi

echo "Building and submitting notarization for $TAG..."
"$ROOT_DIR/script/package_release.sh" "$VERSION" --notarize --notary-profile "$NOTARY_PROFILE"

echo "Verifying notarized release artifact..."
hdiutil verify "$DMG_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
codesign --verify --verbose=2 "$DMG_PATH"
spctl -a -vv "$APP_BUNDLE"
spctl -a -vv --type open "$DMG_PATH"
shasum -a 256 -c "$CHECKSUM_PATH"

if [[ "$CREATE_TAG" == "1" ]]; then
  if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    git tag -a "$TAG" -m "Mimo Desktop Pet $TAG"
  fi
fi

if [[ "$PUSH_TAG" == "1" ]]; then
  git push origin "$TAG"
fi

if [[ "$CREATE_GITHUB_RELEASE" == "1" ]]; then
  mkdir -p "$RELEASE_DIR"
  cat >"$RELEASE_NOTES" <<NOTES
Mimo Desktop Pet $TAG

- macOS 14+ companion app.
- Developer ID signed and Apple notarized DMG.
- Drag Mimo Desktop Pet.app to Applications after opening the DMG.

SHA-256:
\`\`\`
$(cat "$CHECKSUM_PATH")
\`\`\`
NOTES

  if gh release view "$TAG" >/dev/null 2>&1; then
    echo "GitHub release $TAG already exists" >&2
    exit 1
  fi

  GH_ARGS=(release create "$TAG" "$DMG_PATH" "$CHECKSUM_PATH" --title "Mimo Desktop Pet $TAG" --notes-file "$RELEASE_NOTES")
  if [[ "$DRAFT_RELEASE" == "1" ]]; then
    GH_ARGS+=(--draft)
  fi
  gh "${GH_ARGS[@]}"
fi

echo "Notarized release is ready:"
echo "  $APP_BUNDLE"
echo "  $DMG_PATH"
echo "  $CHECKSUM_PATH"
