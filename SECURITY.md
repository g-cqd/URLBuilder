# Security Policy

## Scope

`URLBuilder` validates and encodes URL components according to RFC 3986, WHATWG URL, and IDNA rules to prevent URL-parsing differentials, CRLF/header injection, host spoofing, and accidental credential exposure. Use the throwing `URLBuilder.build` API for untrusted input.

## Reporting a Vulnerability

Report security issues privately via [GitHub Security Advisories](https://github.com/g-cqd/URLBuilder/security/advisories/new).
