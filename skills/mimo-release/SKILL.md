---
name: mimo-release
description: Build, version, notarize, validate, tag, and optionally publish Mimo Desktop Pet macOS DMG releases. Use when preparing v0.0.x GitHub releases, submitting Apple notarization, checking Developer ID/Gatekeeper status, or attaching installable DMGs for this repository.
---

# Mimo Release

Use this skill for release work in this repository only. Keep generated app
bundles, DMGs, screenshots, and notarization logs out of git; `dist/` is ignored.

## Prerequisites

- Run from `/Users/biwakonbu/github/mimo-codex-pets`.
- Keep the worktree clean before a release command.
- Ensure a `Developer ID Application` certificate is available:
  `security find-identity -p codesigning -v`.
- Either store Apple notary credentials once before submitting:
  `xcrun notarytool store-credentials MimoDesktopPet --apple-id <apple-id> --team-id DZZW99M6D8`.
- Or create/download an App Store Connect API team key and keep the `.p8` file
  outside this repository. If the user is unsure about this setup, follow
  `desktop/MimoDesktopPet/docs/notarization-asc-api-key.md`.
- Use the stored profile name through `--notary-profile MimoDesktopPet` or
  `MIMO_NOTARY_KEYCHAIN_PROFILE=MimoDesktopPet`.
- Use API key auth through `--asc-key <AuthKey.p8> --asc-key-id <key-id>
  --asc-issuer <issuer-uuid>` or the matching `MIMO_NOTARY_ASC_*` env vars.

## Main Command

For a notarized local artifact:

```bash
desktop/MimoDesktopPet/script/version_and_notarize.sh 0.0.1 --notary-profile MimoDesktopPet
```

For a notarized local artifact using App Store Connect API key auth:

```bash
desktop/MimoDesktopPet/script/version_and_notarize.sh 0.0.1 \
  --asc-key /secure/path/AuthKey_XXXXXXXXXX.p8 \
  --asc-key-id XXXXXXXXXX \
  --asc-issuer <issuer-uuid>
```

For a full GitHub-ready release after notarization:

```bash
desktop/MimoDesktopPet/script/version_and_notarize.sh 0.0.1 \
  --notary-profile MimoDesktopPet \
  --github-release
```

Add `--draft` with `--github-release` when the release should be reviewed before
publication. Add `--skip-qa` only when the same commit already passed the QA
gate in the current turn.

## What The Command Does

1. Verifies the worktree is clean.
2. Validates the notarytool keychain profile or App Store Connect API key.
3. Runs `swift test --quiet`, docs contract, and `git diff --check` unless
   `--skip-qa` is used.
4. Calls `desktop/MimoDesktopPet/script/package_release.sh <version> --notarize`.
5. Builds a release `.app` with `CFBundleShortVersionString=<version>`.
6. Signs the app and DMG with Developer ID and hardened runtime.
7. Submits the DMG to Apple notarization, waits for acceptance, staples the
   ticket, and validates the staple.
8. Verifies the final app and DMG with `codesign`, `spctl`, `hdiutil`, and
   SHA-256.
9. When requested, creates `v<version>`, pushes it, and creates the GitHub
   release with the DMG and checksum.

## Failure Handling

- `Unnotarized Developer ID`: notarization did not run or did not staple; rerun
  `version_and_notarize.sh` with a valid notary profile.
- `No Keychain password item found`: create the profile with `notarytool
  store-credentials` or use `--asc-key` API key auth instead.
- `401 Unauthorized` with API key auth: confirm key ID, issuer ID, team access,
  and whether the key is a team key. Team keys need `--asc-issuer`; individual
  keys should omit issuer.
- Existing tag points elsewhere: stop and ask before deleting or moving tags.
- GitHub release already exists: do not overwrite automatically; inspect with
  `gh release view v<version>`.

## Artifacts

Expected output paths:

```text
desktop/MimoDesktopPet/dist/release/v<version>/MimoDesktopPet.app
desktop/MimoDesktopPet/dist/release/v<version>/MimoDesktopPet-<version>.dmg
desktop/MimoDesktopPet/dist/release/v<version>/MimoDesktopPet-<version>.dmg.sha256
```

Report the exact notarization, Gatekeeper, tag, and GitHub release state in the
final answer.
