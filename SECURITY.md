# Security Policy

## Supported versions

Only the latest released version of `libqrencode-ng` is supported with
security fixes.

| Version | Supported |
| ------- | --------- |
| 5.x     | Yes       |
| < 5.0   | No        |

For issues affecting upstream libqrencode (4.x and earlier from
<https://github.com/fukuchi/libqrencode>), please report them to the
upstream maintainer. We may still backport upstream fixes when relevant.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a security-sensitive bug.

Use GitHub's private vulnerability reporting instead:

  <https://github.com/paolostivanin/libqrencode-ng/security/advisories/new>

Alternatively, you can email the maintainer directly:

  Paolo Stivanin <info@paolostivanin.com>

A useful report includes:

* The affected version (`qrencode-ng -V` or git revision).
* A description of the vulnerability and its impact.
* A proof-of-concept input (a small file or short C snippet) that triggers
  the issue.
* Whether the bug is exploitable from the library API alone, from the CLI,
  or only with specific build options.

## What to expect

* Acknowledgement of the report within 7 days.
* An initial assessment (confirmed / not reproducible / out of scope) within
  14 days.
* Coordination on a fix and a disclosure timeline. We aim to publish a fix
  within 90 days of confirmation, sooner for high-severity issues.

## Scope

In scope:

* Memory safety bugs (buffer overflows, out-of-bounds reads/writes,
  use-after-free) reachable from public API or the `qrencode-ng` CLI tool.
* Crashes / hangs / unbounded memory use triggered by attacker-controlled
  input.
* Issues in the build system that produce an insecure binary by default.

Out of scope:

* DoS attacks that require obviously abusive parameters (e.g. passing
  `-s 1000000` to the CLI). Validate parameters at the application
  boundary; see the warning in [`README.md`](README.md).
* Issues that only reproduce on platforms not supported by this fork
  (Windows, macOS).
* Issues in third-party dependencies (`libpng`, `iconv`); please report
  those upstream.
