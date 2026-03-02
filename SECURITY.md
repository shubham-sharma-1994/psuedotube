# Security Policy

## Supported Versions

Only the latest released version of Noize receives security fixes. We do not backport patches to older versions.

| Version | Supported |
|---------|-----------|
| Latest stable | ✅ Yes |
| Older releases | ❌ No |

---

## Reporting a Vulnerability

**Please do not open a public GitHub issue to report a security vulnerability.** Public disclosure before a fix is available can put users at risk.

Instead, report vulnerabilities privately using one of the following methods:

- **GitHub Private Security Advisory** (preferred): [Report a vulnerability](https://github.com/anandssm/noize/security/advisories/new)
- **Email**: [![Email](https://img.shields.io/badge/Email-gravityappslabin%40gmail.com-blue?style=flat-square)](mailto:gravityappslabin@gmail.com)
- **Support group**: [![Telegram](https://img.shields.io/badge/Support-Telegram-blue?style=flat-square)](https://t.me/noizesupport)
- **Updates channel**: [![Telegram](https://img.shields.io/badge/Updates-Telegram-blue?style=flat-square)](https://t.me/NoizeUpdates)

Please include as much of the following information as possible to help us understand and resolve the issue quickly:

- A clear description of the vulnerability and its potential impact.
- The affected version(s).
- Steps to reproduce or proof-of-concept code.
- Any suggested mitigation or fix.

---

## Response Timeline

| Step | Target time |
|------|-------------|
| Initial acknowledgment | Within **48 hours** |
| Triage and severity assessment | Within **5 business days** |
| Fix or mitigation released | Depends on severity; critical issues are prioritized |

We will keep you informed of our progress and coordinate a public disclosure date with you once a fix is available.

---

## Scope

### In scope

- Security vulnerabilities in the Noize application source code.
- Mishandling of user data (API keys, playback history, downloaded files).
- Authentication or authorization issues.
- Vulnerabilities introduced by dependencies that are directly exploitable via Noize.

### Out of scope

- Vulnerabilities in third-party services Noize connects to (YouTube Music, JioSaavn, LRCLib, etc.). Please report those directly to the respective services.
- Issues that require physical access to the device.
- Denial-of-service attacks requiring large amounts of resources.
- Best-practice suggestions that do not represent a concrete vulnerability.

---

## Disclosure Policy

We follow a **coordinated disclosure** model. We ask that you:

1. Report the issue privately and give us a reasonable window to fix it.
2. Avoid sharing details publicly until we have released a patch.
3. Avoid accessing, modifying, or deleting user data beyond what is necessary to demonstrate the vulnerability.

After a fix is released, we will publicly acknowledge the reporter (with your permission) in the release notes.

---

## Thank You

We genuinely appreciate the security community's efforts to make Noize safer for everyone. Responsible disclosure makes open-source software better for all users.
