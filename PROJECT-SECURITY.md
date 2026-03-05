# Whisperspace Project Security Plan

## Purpose
This document defines a shared, practical security baseline for all Whisperspace projects.
It is internal, operational guidance intended to reduce risk without breaking core usability.

## Scope
Applies to:
- `whisperspace`
- `whisperspace-rules-api`
- `whisperspace-obr-extension`
- `whisperspace-obr-gm`
- `whisperspace-character-builder`
- `whisperspace-docs`
- `whisperspace-developer`
- `whisperspace-rules-parser`
- `whisperspace-sdk`

## Security Principles
1. Usability-first security:
- Security controls must not materially degrade primary user workflows.
- For OBR extensions, avoid forcing GMs/players through manual API key setup or complex auth steps for normal play.

2. Defense in depth:
- Enforce authn/authz server-side for sensitive writes, even if client/UI already gates actions.
- Treat client metadata as untrusted input.

3. Least privilege and explicit trust boundaries:
- Minimize who can write what, where, and when.
- Keep origin/CORS/auth rules explicit and auditable.

4. Operational reliability:
- Favor controls that fail safely and are observable.
- Include rollback paths for security changes.

## Non-Negotiable Constraints
- Keep current single-server topology for now.
- Preserve low-friction OBR usage (no random-GM auth hoops for base extension operation).
- Do not ship security changes that break active table workflows.

## Global Baseline Controls

### A) Authentication and Authorization
- All state-changing API endpoints must enforce server-side authorization.
- Character ownership checks remain mandatory for character write/read scopes.
- GM-only actions in OBR must be validated by role/ownership checks where writes are performed.

### B) CSRF and Session Safety
- Any cookie-authenticated write endpoint must enforce CSRF checks.
- Keep explicit endpoint-level CSRF test coverage to prevent regressions.
- Maintain secure cookie flags appropriate to deployment context.

### C) CORS and Origin Policy
- Maintain explicit allowlists per service (no implicit wildcard for credentialed routes).
- For OBR extension manifests/static assets, keep required Owlbear CORS headers only where needed.

### D) Input Validation and Data Integrity
- Validate all external payloads against schema contracts.
- Reject unknown/invalid shapes for canonical persistence paths.
- Preserve adapter/sanitization layers where cross-project payloads differ.

### E) Rate Limiting and Abuse Controls
- Keep per-endpoint limits for write-heavy and auth bootstrap routes.
- Continue backoff/cooldown behavior for OBR canonical write flows to avoid hammering.
- Add/retain bounded retries only; avoid unbounded loops.

### F) Logging and Observability
- Keep sampled security-relevant telemetry for auth issuance/failures and write failures.
- Avoid logging secrets/tokens/PII in application logs.
- Prefer actionable summary metrics over noisy per-event spam.

### G) Dependency and Release Hygiene
- Run dependency vulnerability checks on release branches.
- Keep a release checklist item for security regression tests (authz/csrf/cors/ownership).
- Keep publish/deploy scripts aligned so runtime files and policy files ship together.

## OBR-Specific Security Policy (Usability-Preserving)

### Accepted Model
- OBR flows may use seamless, room-scoped auth/session bootstrap to preserve table usability.
- Extension UX should remain near-zero setup for normal GMs/players.

### Required Guardrails
- Room-scoped guest/session issuance must be rate-limited and short-lived.
- Sensitive write endpoints still require valid session context and origin policy.
- Ownership-sensitive operations must remain owner/GM constrained.
- Client-side fallback/local queues must not bypass server authorization.

### Explicit Non-Goals (for now)
- Mandatory manual API key provisioning for normal OBR extension usage.
- Security workflows that interrupt game flow for every session.

## Repository Security Status Requirements
Each project section in `PROJECT-OVERVIEW.md` should maintain:
- Current auth model summary.
- Main externally reachable surfaces.
- Current CORS/CSRF posture.
- Known risks and next hardening steps.
- Confirmation that planned changes preserve usability expectations.

## Implementation Phases

### Phase 1 (Immediate)
- Keep this file as the canonical cross-project security plan.
- Fill missing security status in projects with incomplete sections (`developer`, `rules-parser`).
- Add explicit release checklist references to authz/csrf/cors regression validation.

### Phase 2 (Near-term)
- Standardize automated checks across repos where practical:
  - authz regression
  - CSRF enforcement
  - CORS policy correctness
  - dependency audit pass

### Phase 3 (Ongoing)
- Track security incidents and near-misses in internal ops notes.
- Update this plan when architecture or trust assumptions change.

## Change Management Rule
Any security hardening proposal must include:
- user-flow impact assessment,
- rollback plan,
- and explicit statement of whether OBR usability is preserved.

If a hardening change conflicts with critical usability, prefer a compensating control that preserves user experience.
