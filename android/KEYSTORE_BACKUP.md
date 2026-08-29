# Android Release Signing Key — Backup & Restore

This app is signed for Play Store release using an **upload keystore**. If this
file is lost, you cannot publish updates to the existing Play Store listing
under `dev.gillin.ef_race_pages` — Google can reset the upload key (since
Play App Signing is used) but it requires an identity-verification process
that takes several days. Back this up now.

## What you need to back up

Two things, together:

1. **The keystore file**: `~/upload-keystore.jks`
   (also referenced as `storeFile` in `android/key.properties`)
2. **`android/key.properties`** — contains the passwords and alias needed to
   use the keystore. This file is gitignored and never committed.

Keystore details for reference:
- Alias: `upload`
- Format: PKCS12 (store password and key password are the same value)
- Validity: 10,000 days from creation (~year 2053)

## Backing it up

Store both files together in a password manager that supports file
attachments (1Password, Bitwarden, etc.) — this keeps them encrypted and
synced automatically. Keep a second, independent copy in a different location
(e.g. an encrypted USB drive, or another family member's cloud storage) —
two copies in two different systems is the standard bar.

```bash
# From this machine, copy both files somewhere you can attach to your
# password manager entry:
cp ~/upload-keystore.jks ~/Desktop/upload-keystore.jks
cp android/key.properties ~/Desktop/key.properties
```

Attach both files to a single password manager entry (e.g. "EF Race Pages —
Android upload keystore"), then delete the Desktop copies:

```bash
rm ~/Desktop/upload-keystore.jks ~/Desktop/key.properties
```

**Never commit `upload-keystore.jks` or `key.properties` to git.** Both are
already covered by `android/.gitignore` (`key.properties`, `**/*.jks`,
`**/*.keystore`).

## Restoring on a new machine

1. Clone this repo as usual.
2. Pull the two backed-up files from your password manager.
3. Place the keystore file wherever you like on the new machine (matching the
   original path is simplest): `~/upload-keystore.jks`
4. Place `key.properties` at `android/key.properties` in the repo. If you put
   the keystore somewhere other than `~/upload-keystore.jks`, edit the
   `storeFile` line in `key.properties` to match the new path.
5. Build a release bundle to confirm signing works:
   ```bash
   flutter build appbundle --release
   ```
   If it completes without a signing error, the setup is correct.

## Play App Signing note

If Play App Signing is enabled for this app (recommended, and default for new
apps), Google holds the actual *app signing key* and only needs your upload
key to authenticate uploads. If you ever lose the upload keystore entirely
(no backups), you can request an upload key reset from Google Play Console
support instead of losing the app permanently — but that process takes days
and requires proof of ownership, so it's a fallback, not a substitute for
backing this up.
