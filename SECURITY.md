# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| 0.2.x | Yes |
| < 0.2.0 | No |

This project has not yet been published to pub.dev. Security fixes land on
`main` of [alaeddine-zen/flutter_reels_composer](https://github.com/alaeddine-zen/flutter_reels_composer)
and are tagged with the package version that contains them.

## Reporting a vulnerability

**Do not** open a public GitHub issue for security problems.

Report privately via
[GitHub Security Advisories](https://github.com/alaeddine-zen/flutter_reels_composer/security/advisories/new).

Please include:

- Affected package(s) and version (`0.2.0`, commit SHA, or branch)
- Platform (Android / iOS) and Flutter version
- A description of the issue and impact
- Steps or a minimal proof of concept **only if it is safe to share**

You should receive an acknowledgement within **7 days**. If the report is
accepted, we will work on a fix and credit you unless you ask otherwise.

## Scope

In scope:

- Path traversal or unexpected file writes in export / draft storage
- Command injection via unsanitized FFmpeg arguments
- Permission / sandbox bypass in the example or packages
- Secrets accidentally committed to this repository

Out of scope:

- Vulnerabilities in upstream plugins (`ffmpeg_kit_flutter_new_min`,
  `camerawesome`, `photo_manager`, `permission_handler`, etc.) — report those
  upstream as well, and tell us if this repo needs a version bump
- Issues that require a compromised device or a jailbroken/rooted OS
- Missing features (use a feature request)

## FFmpeg note

Export shells out to FFmpeg Kit. Host apps must not pass unsanitized user
paths into a custom `ExportPort`. The bundled adapters escape `"` in paths;
treat media paths as untrusted input anyway.
