# App Store Connect API Key Notarization

This guide covers the App Store Connect API key path for notarizing Mimo
Desktop Pet releases without relying on Apple ID login prompts.

Use this path when `xcrun notarytool store-credentials` is inconvenient or when
the release should run from a command that only receives an API key file, key
ID, and issuer ID.

## Safety Boundary

The API key private file is a credential.

- Do not commit `.p8` files. This repository ignores `*.p8`, but still keep
  private keys outside the repository.
- Do not paste the private key contents, key ID, issuer ID, or Apple account
  details into chat.
- Codex can help navigate and explain the App Store Connect screen, but the
  human account owner should do the final API key creation and `.p8` download.
- If Codex is using Computer Use, it should stop before clicking the final
  create/download action unless the user explicitly approves that exact step.

The `.p8` file can only be downloaded at key creation time. If an existing
active key is visible in App Store Connect but its `.p8` file is missing, create
a new key and revoke the old one when it is no longer needed.

## App Store Connect Setup

Apple's official flow is documented in:

- [Creating API Keys for App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
- [App Store Connect API get started](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/)
- [TN3147: Migrating to the latest notarization tool](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool)

Use the Team Key flow for this project:

1. Open App Store Connect:
   <https://appstoreconnect.apple.com/access/integrations/api>
2. Confirm the intended Apple Developer Program team is selected in the account
   menu.
3. Go to `Users and Access` -> `Integrations` -> `App Store Connect API`.
4. Select `Team Keys`.
5. If a usable active key already exists and you still have its downloaded
   `.p8` file, reuse it.
6. If no usable key exists, create a new key with a clear name, for example
   `MimoDesktopPet Notarization`.
7. Save these values somewhere local and private:
   - the downloaded `AuthKey_<KEYID>.p8` file
   - the key ID
   - the issuer ID shown on the Team Keys screen

For Team Keys, `notarytool` requires the issuer ID. For Individual Keys, omit
the issuer ID.

## Local Key Storage

Put the private key outside this repository:

```bash
mkdir -p "$HOME/Developer/AuthKeys"
chmod 700 "$HOME/Developer/AuthKeys"
mv "$HOME/Downloads/AuthKey_<KEYID>.p8" "$HOME/Developer/AuthKeys/"
chmod 600 "$HOME/Developer/AuthKeys/AuthKey_<KEYID>.p8"
```

Replace `<KEYID>` with the key ID shown by App Store Connect. Do not paste the
actual value into tracked docs.

## Validate The Credentials

Before building the DMG, validate the key with `notarytool`:

```bash
xcrun notarytool history \
  --key "$HOME/Developer/AuthKeys/AuthKey_<KEYID>.p8" \
  --key-id "<KEYID>" \
  --issuer "<ISSUER_UUID>"
```

Expected result: the command returns notarization history or an empty successful
history response.

Common failures:

- `401 Unauthorized`: wrong key ID, wrong issuer ID, revoked key, wrong team,
  or Team/Individual key mismatch.
- `Issuer ID is required`: a Team Key was used without `--issuer`.
- `file not found`: the `.p8` path is wrong or the file was not moved from
  Downloads.

## Build, Notarize, And Prepare A GitHub Release

Run the release wrapper from the repository root:

```bash
desktop/MimoDesktopPet/script/version_and_notarize.sh 0.0.1 \
  --asc-key "$HOME/Developer/AuthKeys/AuthKey_<KEYID>.p8" \
  --asc-key-id "<KEYID>" \
  --asc-issuer "<ISSUER_UUID>" \
  --github-release \
  --draft
```

Use `--draft` until the GitHub release notes and attached DMG are inspected.
Remove `--draft` only when the release should be published immediately.

The command validates the API key, runs release checks, builds the signed DMG,
submits it to Apple notarization, staples the ticket, verifies Gatekeeper
acceptance, creates `v0.0.1`, pushes the tag, and creates the GitHub release
when `--github-release` is present.

## Environment Variable Alternative

If you prefer not to put credentials in the shell history, export them for the
current shell session:

```bash
export MIMO_NOTARY_ASC_KEY_PATH="$HOME/Developer/AuthKeys/AuthKey_<KEYID>.p8"
export MIMO_NOTARY_ASC_KEY_ID="<KEYID>"
export MIMO_NOTARY_ASC_ISSUER_ID="<ISSUER_UUID>"

desktop/MimoDesktopPet/script/version_and_notarize.sh 0.0.1 \
  --github-release \
  --draft
```

Do not add these exports to tracked shell scripts or repository docs with real
values.

## What Codex Can Safely Do

Codex can:

- check that the release scripts accept API key flags
- validate that the `.p8` path exists, without printing file contents
- run `xcrun notarytool history` after the user provides local paths and IDs
- run the release wrapper and report notarization, Gatekeeper, tag, and GitHub
  release state

Codex should not:

- read or print the `.p8` file contents
- click final API key creation or download actions without an action-time user
  confirmation
- paste real key IDs or issuer IDs into committed files
- commit generated DMGs, app bundles, notarization logs, or downloaded keys
