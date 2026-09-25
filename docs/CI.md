# CI policy

- **One check per open PR:** `PR Android CI` → single signed universal APK.
- Runs on: PR opened, reopened, or new commit on an open PR.
- Does **not** run after merge into `main`.
- Full multi-platform release: Actions → **Flutter Release Builds** → Run workflow (manual).

Updated: 2026-09-25.
