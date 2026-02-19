# Whisperspace Project Overview

## Scope
Whisperspace is a multi-repo ecosystem for a TTRPG ruleset. The goal is to maintain a single source of truth for rules data and reuse it across apps and extensions (character builders, VTT integrations, docs, and developer tooling) without duplicating data.

All project directories live in `/hdd/sites/stuartpringle` on an Ubuntu server and are served via Apache2 where applicable.

## Repositories And Roles
- `whisperspace`
  - Public-facing website.
  - Statamic site.
  - URL: `https://whisperspace.com`
- `whisperspace-rules-api`
  - Rules API, character API, and calc endpoints for Whisperspace.
  - Primary API surface for apps and VTT extensions.
  - URL: `https://rules-api.whisperspace.com`
  - Key entrypoints: `https://rules-api.whisperspace.com/rules-api/latest` and `https://rules-api.whisperspace.com/character-api/`
- `whisperspace-obr-extension`
  - Owlbear.rodeo VTT extension.
  - URL: `https://obr.whisperspace.com`
- `whisperspace-character-builder`
  - Main character builder application.
  - URL: `https://builder.whisperspace.com`
- `whisperspace-developer`
  - Developer documentation for the API and extension workflows.
  - URL: `https://developer.whisperspace.com`
- `whisperspace-docs`
  - Public rules reference and search.
  - URL: `https://docs.whisperspace.com`
- `whisperspace-rules-parser`
  - Internal pipeline that pulls the master rules document from Google Docs and outputs normalized YAML for downstream use.
  - No public URL.
- `whisperspace-sdk`
  - Shared schema and utilities used by multiple projects (API validation, character record types, shared data model).
  - Consumed by the rules API and client apps to stay aligned on types and schema.
  - No public URL.

## Overall Objective
Create a modular ecosystem where rules data is authored once (in the master rules document) and propagated through a single pipeline to all apps, extensions, and documentation. This enables consistent updates and minimizes duplication.

Planned progression:
1. Launch the core character builder (`builder.whisperspace.com`).
2. Extend the builder into VTT integrations for Owlbear.rodeo, Foundry, and Roll20, each with its own character builder UX.
3. Embed rules reference directly inside each VTT.
4. Add bi-directional linking so characters can move between the main builder and VTTs with minimal friction.

## Rules Data Workflow (This Repo)
The canonical rules data is produced by the Rules Parser and published through this repo.

Workflow:
1. Run the parser to pull and normalize rules content.
2. Sync output into this repo.
3. Publish to the live API.

Quick publish rules in this repo:
```bash
npm run rules:publish
```

## Hosting Notes
All services run on an Ubuntu host and are served via Apache2. Public-facing endpoints are mapped to their corresponding subdomains listed above.

## Versioning And Compatibility Matrix
Track cross-repo compatibility here (update on releases):

| Date | Rules API Version | SDK Version | Character Builder Version | OBR Extension Version | Notes |
| --- | --- | --- | --- | --- | --- |
| 2026-02-11 | | | | | Initial matrix placeholder |

## Cross-Repo Release Checklist
Use this when rules or schemas change:

1. Update the master rules document.
2. Run `whisperspace-rules-parser` to regenerate YAML.
3. In `whisperspace-rules-api`, run `npm run rules:publish`.
4. Update `whisperspace-sdk` schema/types if the data model changed.
5. Update `whisperspace-character-builder` to align with new schema/fields.
6. Update VTT extensions (Owlbear, Foundry, Roll20) to align with new schema/fields.
7. Update `whisperspace-docs` and `whisperspace-developer` for any user-facing changes.
8. Verify API endpoints and schema endpoints on `rules-api.whisperspace.com`.

## Shared Contracts Index
Canonical contracts and where they live:

- Rules data (JSON): `https://rules-api.whisperspace.com/rules-api/latest/`
- Rules metadata: `https://rules-api.whisperspace.com/rules-api/latest/meta.json`
- Calc schemas: `https://rules-api.whisperspace.com/rules-api/calc/schemas/index.json`
- Character record schema (source of truth): `/hdd/sites/stuartpringle/whisperspace-sdk/schema/character-record.v1.json`
- Character schema endpoint: `https://rules-api.whisperspace.com/character-api/schema.json`

## Status Rollup (Fill In)
Use this section to keep a single-source, cross-repo status summary.

### whisperspace
- Current status: Production Statamic site is live at `https://whisperspace.com`, with newsletter functionality and reCAPTCHA-protected forms.
- Recent milestones:
- Upgraded to `anakadote/statamic-recaptcha:^3.0`.
- Added backward-compatible reCAPTCHA version mapping in `config/recaptcha.php` so legacy `RECAPTCHA_VERSION=3/2` env values continue to work with the addon’s new `enterprise|v3|v2` config expectations.
- Captured runtime integration notes in this repo’s `README.md` for future addon upgrades (cache clear + vendor publish steps).
- Applied frontend hardening pass: guarded hero-title animation script on templates that do not render `.animated-title`, aligned mobile/desktop nav CTA condition to `Get In Touch`, and removed stale JS references to legacy mobile menu IDs.
- Added allowlist HTML sanitization for archetype descriptions before Alpine `x-html` rendering, preserving paragraph formatting while reducing DOM injection risk.
- Updated repo hygiene to ignore Statamic `users/` and stop tracking committed user account file(s) containing credential hashes.
- Improved frontend image delivery: compressed/width-bounded WebP Glide backgrounds, responsive archetype image `srcset`, lazy/async loading for below-the-fold images, and Apache cache headers for static assets.
- Added a repeatable image optimization script (`scripts/optimize-image-formats.sh`) and generated AVIF/WebP variants for key website assets; above-the-fold hero background/ship now use static AVIF/WebP with PNG fallback.
- Added AVIF transparency safeguards: skip AVIF generation for alpha-channel source images and use WebP+PNG fallback for the transparent hero ship asset.
- Refreshed website Rules section presentation: transformed markdown rule items into grouped card-grid UI with hover animation for better readability/scanability.
- Improved Archetypes section UX: preloaded carousel images for smoother transitions, stabilized image viewport sizing to reduce layout shift, and moved next/previous controls onto the image as overlay navigation buttons.
- Further Archetypes polish: thumbnails now render above the main image, description area uses fixed-height shell for stability, image-shell fallback uses themed gradient (not flat black), and edge nav/hover zoom interactions were refined.
- Archetypes interaction UX expanded: main image click now opens a framed modal view, edge nav controls were narrowed and intensified visually on hover, and description content width was increased for better visual alignment.
- About section UX refreshed: lead copy, "At a glance" bullets, and author details now render with section-specific card/callout styling on `https://whisperspace.com` while preserving CMS-managed markdown editing.
- Tuned website reCAPTCHA v3 to reduce false-positive bot flags across browser profiles by disabling page-load form gating and lowering threshold to `0.35`; cleared app caches after rollout.
- Updated website starfield rendering so the animated stars now persist across full-page scroll (global fixed canvas) with scroll-driven parallax drift instead of clipping at hero section bounds.
- Added shared navigation hosting on `whisperspace.com` via canonical JSON (`/nav/main-menu.v1.json`) with CORS headers so other Whisperspace subdomain apps can render the same top-level menu and compute active state consistently by host/path/hash.
- Fixed production Vite manifest lookup for shared navigation by adding `resources/js/shared-nav.js` to the Vite input list so deploy builds include it.
- Next steps:
- Normalize `.env` to explicit string mode (`RECAPTCHA_VERSION=v3`) across environments during next deploy window.
- Keep reCAPTCHA addon/config publish steps in release runbook whenever Statamic addons are upgraded.

### whisperspace-rules-api
- Current status: Rules + calc + character APIs are live, with MySQL-backed character storage stable and calc contracts now supporting equipment/feat `gameplayEffects` deltas.
- Recent milestones:
- Added `gameplayEffects` field support across weapons/armour/items/feats contracts in this repo.
- Updated calc derivation endpoints to apply gameplay deltas to attributes, derived stats, and skill modifiers (with floor-at-zero behavior for skill ranks).
- Compact Backpack and similar gear now map gameplay effects via programmatic text parsing from source rules wording (with explicit field override support).
- Published `skill_tooltips.json` in ID-keyed form (`skills.<skill_id>`, `attributes.<attribute_id>`) with label-keyed compatibility maps to unblock builder tooltip lookup.
- Expanded gameplay effect key normalization in calc parsing (aliases like `cuf` and `carryingCapacity` now resolve to canonical keys).
- README calc docs expanded with gameplay-effects contract and request/response examples.
- Next steps:
- Align builder + OBR payloads to always pass equipped gameplay effects into calc endpoints.
- Backfill gameplay effects for additional gear/feat entries as rules content is formalized.
- Clarify calc integration gotchas in downstream docs/clients (avoid double-counting gameplay effects from top-level lists + gear payloads).
- Fixed inherited global Basic Auth prompt on `rules-api.whisperspace.com` root by adding a publish-root `.htaccess` override and wiring `rules:publish` to copy it into `dist/.htaccess`.

### whisperspace-obr-extension
- Current status: OBR sheet migration work is active in `/hdd/sites/stuartpringle/whisperspace-obr-extension`, and the project now builds successfully against current `@whisperspace/sdk` exports.
- Recent milestones:
- Unblocked TypeScript build by removing stale imports to legacy `packages/core/src/*` modules and replacing with current SDK exports/local helpers.
- Switched combat/damage hook usage to `getHookBus` from `@whisperspace/sdk`.
- Added local ammo helper (`src/rules/weapons.ts`) to preserve weapon ammo-max behavior after core-module decoupling.
- Hardened initiative status parsing for inventory unions that include `hacker_gear` entries without `statusEffects`.
- Restored strict typing in `SkillsPanel` by inlining a local learned-skill focus map helper and removing legacy core dependency.
- Added a local compatibility `CharacterRecordV1` adapter type in `src/rules/schema.ts` because current SDK exports `CharacterSheetV1` only.
- Verified end-to-end compile with `npm run build` in `whisperspace-obr-extension` on 2026-02-17.
- Added backward-compatible `rules.html` route in `whisperspace-obr-extension/public/rules.html` that redirects to `https://docs.whisperspace.com/` (hash preserved), covering older same-origin rules links from legacy extension flows.
- Removed stale `packages/core/src` include from `whisperspace-obr-extension/tsconfig.json` so new migration work is constrained to repo-local `src/`.
- Restored initiative token focus UX in OBR extension: clicking avatar entries now selects and centers the token via current OBR SDK APIs.
- Fixed OBR calc CORS regression by aliasing `@whisperspace/sdk` in `whisperspace-obr-extension` to a local shim that targets `https://rules-api.whisperspace.com/rules-api/calc` (instead of `https://whisperspace.com/rules-api/calc`).
- Documented explicit OBR extension deployment policy: after each change batch, run `npm run build` in `whisperspace-obr-extension` so hosted `dist/` is updated and validate manifest/calc endpoint behavior.
- Added OBR extension import/sync UX: token sheet now supports `Import JSON` and `Sync Public Link` (builder copy-link URL or character id), backed by `GET /character-api/characters/:id` for public character pull-in.
- Updated Character API CORS allowlist to include `https://obr.whisperspace.com` alongside builder origin so OBR can fetch public character records cross-origin.
- Added OBR `Export JSON` and interoperability normalization so builder/OBR JSON exchange is cleaner (supports builder `armours`/`equippedArmourId` and gameplay-effects fallback during import).
- OBR extension model alignment batch landed: canonical `gameplayEffects` usage, multi-armour (`armours[]` + `equippedArmourId`) support, equipped-weapon UX, and initiative/damage paths now resolving equipped gear instead of first-slot assumptions.
- OBR inventory/effects parity follow-up landed: `hacker_gear` template/import/edit support is now in-panel, and gameplay-effects chip editors are now used across feats, inventory, weapons, and equipped armour.
- OBR gameplay-effects parity now includes a builder-style guided composer in the shared editor (`category`/`target`/`amount` -> canonical `target+N` string) so effect-entry format is consistent across builder and OBR.
- OBR tab/layout parity pass landed: removed standalone Combat tab, moved weapon/armour editors into Inventory tab, moved Combat Log into Initiative tab, and added a dedicated Settings tab for JSON sync/import/export + token binding actions.
- OBR gameplay-effect editor controls are now toggle-revealed (`Gameplay Effects` / `Hide Gameplay Effects`) so chips stay visible while edit fields are opt-in.
- OBR inventory/equipment UX parity follow-up landed: credits controls + `Acquire/Buy` mode are now inventory-tab-first, buy mode enforces credits and sell refunds, Gear add section is collapsible/grid-based, and armour editing now uses per-item card flow with explicit `Equip`/`Unequip`/`Remove`.
- OBR follow-up UX pass landed: add flows are now button-gated (`Add Gear/Weapon/Armour` -> `Cancel`), inventory add-field layout was tightened (`bulk/qty/cost/uses` 2x2), initiative tab label now surfaces as `Combat`, and GM can directly edit initiative values with automatic re-sort.
- OBR row-flow polish landed: gear-add controls now live directly in Inventory section (no separate Gear section), weapons/armour now use inventory-like collapsed row summaries, buy-mode remove actions expose sell intent in tooltips, and carried armour can remain fully unequipped.
- OBR ownership/permissions pass landed: claiming already-owned tokens is blocked, non-GM users are restricted to their own bound sheet, legacy back-to-my-sheet navigation was removed, and GM settings now support `Unset Character From <owner>` while viewing another player’s token sheet.
- OBR combat/utility follow-up landed: top header token-id line removed, a new `Test` tab now supports token-to-token distance measuring, and initiative row combat actions now strictly use equipped gear semantics (`Attack` uses equipped weapon or unarmed fallback, `Reload` requires equipped weapon, PROT shows equipped armour only with `0` default when unequipped).
- OBR range-band starter landed: shared ground-band mapping (`Melee` through `Extreme`) now derives from the current rules distance table, and `Test -> Measure` now shows both feet conversion (`1 unit = 5 ft`) and resolved range band labels.
- OBR targeting/range-context pass landed: non-GM right-click sheet/initiative actions are now hidden on tokens not owned by that player, a new token `Target` action stores target metadata on the owner token, and `Test -> Attack Targeted` now enforces rules-api range logic (melee out-of-range auto-fail, ranged Very Near penalty die, +2 DC per farther band, 3+ farther bands auto-miss).
- OBR target UX follow-up landed: target selection now renders a per-player red target-ring attachment on the targeted token, and `Attack Targeted` confirms equipped-weapon ammo decrement/persist behavior where ammo applies.
- OBR targeting semantics were expanded: right-click now swaps between `Target`/`Untarget` per token state, target rings now encode ally/enemy (`player-owned non-GM` => teal, otherwise red), and ring padding was tightened for a closer fit.
- OBR combat-tab attacks now conditionally inherit targeted/range-aware behavior: when a target exists they apply range-band penalties/DC adjustments and auto-miss constraints; when no target exists they retain legacy direct-roll behavior.
- OBR combat follow-up: targeted hits now auto-apply resulting damage/stress to the targeted token sheet and append effect entries to combat log, and manual Combat-panel `Apply Damage` flow was stabilized to avoid wound-state flicker from redundant stress callback writes.
- OBR targeted-hit application now includes an ownership-safe fallback: if attacker-side cross-token writes fail due permissions, effect payloads carry `autoApplyToTarget` and the target owner client applies the hit locally to its own sheet.
- OBR targeted-hit apply routing was tightened to avoid silent non-owner write attempts: attackers now choose direct apply only for owner/GM contexts, otherwise they always emit target-owner auto-apply payloads.
- OBR combat-log persistence moved to a scene-global metadata model (`whisperspace.obr.sheet/globalCombatLog`), so sheet panels now render shared recent history (latest 4) regardless of which tabs were open when rolls occurred; Test tab now also surfaces live current-token position coordinates.
- OBR initiative avatar focus behavior was corrected to center camera from live item bounds (`getItemBounds().center`) instead of stale cached token positions.
- OBR initiative focus follow-up now reads clicked token live item position at click time (fallback to bounds center), tightening token-location source correctness for camera centering.
- OBR camera-focus diagnostics are temporarily enabled in initiative-avatar focus flow, with viewport transform snapshots logged around center/zoom operations and a new center-then-restore-zoom attempt (animate to bounds, then reset previous scale).
- OBR focus UX follow-up: temporary camera debug logging has been removed, header token thumbnail now supports click-to-center behavior, and my-sheet load now auto-centers once on the bound character token.
- Next steps:
- Continue porting remaining legacy OBR sheet behavior from `whisperspace-obr-sheet` into this extension repo.
- Align any remaining record/adapter usage with final SDK character type naming once shared SDK contract is finalized.
- Smoke test extension behavior in Owlbear Rodeo (initiative, combat rolls, damage apply, token save/load) after each migration batch.

### whisperspace-character-builder
- Builder preview modals now present cleaned field labels (no raw IDs, pretty skill names) with two-column detail layout and improved selector action-row wrapping for `Preview` + `Buy` controls.
- Builder equipment selectors now expose `Preview` modals for weapons, armour, and gear entries so users can inspect full catalog detail before adding/buying.
- Builder armour action buttons were normalized to the same padded sizing as other row action controls for consistent touch/click targets.
- Builder credits adjustments are now handled via a dedicated modal flow (`Add/Remove`) launched from Equipment credits display, reducing control clutter in the gear summary row.
- Current status: Production React/Vite builder is live at `https://builder.whisperspace.com` with rules-driven character creation, local drafts, and authenticated cloud save.
- Recent milestones:
- Added account UX polish in the Save dialog (clear login/signup/reset messaging and readable auth errors).
- Clarified save permissions in UI copy: `private` (just you) vs `public` (anyone).
- Save flow now uses staged modals (save menu -> auth when needed -> save options by target).
- Save options are conditional by target (only show `New copy` when an existing local/cloud record exists).
- Reset action now confirms and restores latest saved local/cloud copy when available.
- Began visual alignment with `whisperspace.com` (dark contact/footer treatment and starfield-inspired panel styling).
- Skills UX refresh: grouped/collapsible trees, search-by-name, no slug labels, compact +/- rank controls, and tooltip hints.
- Added inline SVG skill-group icons for attribute/focus trees.
- Added authenticated account menu under username with `My Characters` top-level nav and a username dropdown (`Settings`, `Log out`).
- Implemented Character List page (search/sort/capacity slots/name-link/copy-link/edit, right-aligned numeric columns) with unsaved-change guard when switching edits.
- Polished account-submenu behavior on protected routes: `/characters` and `/settings` now keep the submenu expanded with proper active highlighting, `/characters` action copy now uses `New Character`, and character rows gained consistent hover-highlight affordances.
- Updated builder navigation + budgeting UX: non-builder pages now present `Continue Building`, default landing preference fallback is `My Characters`, and `Skills & Attributes` now uses an `Add / Remove` skill-points modal with spent-point removal safeguards and warning feedback.
- Refined `Skills & Attributes` layout by removing the direct total skill-points input, adding an explicit `Skill Points` budget heading, and relocating `Learning Focus` directly below that budget section.
- Reworked builder account navigation presentation: submenu links now render inline as an indented tree under the user entry (not a detached floating dropdown), and the account menu group sits slightly higher in the header layout.
- Simplified builder account menu structure by removing the separate user-name parent item and rendering `My Characters`, `Settings`, and `Log out` directly as indented entries in the same primary menu list.
- Finalized builder account menu presentation as a flat normal menu list (no submenu indentation), while styling `Log out` with a lighter danger treatment for clearer action distinction.
- Aligned builder header `Log out` styling to the shared destructive-action button pattern (`ghost danger`) used by inventory remove actions for consistent affordance.
- Updated builder equipment-purchase UX labels: weapon/armour/item catalog dropdowns now include inline cost text (`Name (<cost> credits)`) in both `Buy` and `Acquire` modes, while `Buy` buttons no longer append per-item cost text.
- Added builder sci-fi name generation for character naming (`Generate` action beside name in Origin) and refreshed Review tab presentation with richer summary metadata, skill-point budget pills, and equipped-armour-aware loadout display.
- Refined builder UX edge cases: default landing redirect now triggers only after explicit login (not refresh/deep links), and roll dialogs for Motivation/Background/credits remain visible until closed so dice outcomes are clearly surfaced.
- Corrected builder dice-modal render scope so roll dialogs mount in the main builder page (not only the characters page), restoring visible roll animation/results for Origin `Roll Motivation` and `Roll Background`.
- Reworked builder roll presentation to non-modal overlays: 3D die animation now runs across the screen and result text appears in a bottom-right toast (`Rolled 1d12: <result>` + contextual detail like credits/background/motivation) before auto-dismiss.
- Enhanced builder roll animation fidelity: toasts now pop more prominently and linger longer, die/toast lifetime increased by ~1s, die visuals now track roll type (`d10`/`d12`), launch vectors are randomized (force + direction + start face), and result numbers are hidden until motion ends.
- Upgraded builder `d10`/`d12` roll visuals from ring approximations to polyhedron-style face constructions (kite faces for `d10`, pentagonal faces for `d12`) for closer geometric alignment with tabletop dice conventions.
- Follow-up dice geometry pass kept face numbers visible during roll animation and adjusted d10/d12 orientation transforms to improve visible face-edge contact/alignment (notably d12 cap/band joins).
- Rolled back builder visual dice overlays per UX direction: Origin roll actions now resolve via direct RNG without on-screen dice/toast, while retaining the modular dice abstraction in code for future optional dice-module restoration.
- Updated builder Origin layout to place `Credits` directly above `Generate Starting Money`, and initiated Character View enhancements with a card-based summary layout (hero metadata, metrics, and detailed sections for attributes/skills/equipment/health/background/notes).
- Expanded builder Character View semantics: page header now resolves to character name with focus/updated/motivation metadata, metrics now label `Cool Under Fire` explicitly and show equipped-armour `Protection` (with durability-aware zeroing), and Equipment now supports constrained weapon equip logic (max two equipped, two-handed exclusivity, and `Req` attribute validation with explicit failure messaging).
- Builder UI consistency pass: weapon action-button spacing now matches armour controls, desktop header account nav remains right-aligned on Character View, and `CUF Loss` was removed from Health cards for cleaner summary surfaces.
- Builder auth/session isolation hardening: character list state now clears on account identity change, stale in-flight list responses are ignored after user switches, and `/auth/session` is always server-validated (no trust-only cached authenticated session) to prevent cross-account character visibility.
- Builder auth UX copy update: login now shows `Username or Password incorrect` for `invalid_credentials` responses instead of exposing raw API error codes.
- Builder character-access UX updates: logout from `/character/:id` now routes back to the builder homepage, and `My Characters` rows now expose a persisted `Public`/`Private` visibility toggle next to `Copy Link`.
- Builder auth-guard timing fix: refreshing protected pages (`/characters`, `/settings`) now waits for initial session verification before redirecting, preventing false redirects to builder while still unauthenticated users are blocked.
- Builder visibility toggle update: `My Characters` now uses a true switch control for `Private/Public`, and visibility updates no longer send `If-Unmodified-Since` so browser preflight/CORS succeeds on cross-origin `PUT ...?visibility=...` requests.
- Builder character-row action layout refinement: visibility switch now appears immediately left of `Copy Link` on `My Characters` rows.
- Builder view-page ownership action: when a logged-in user is viewing their own character at `/character/:id`, the header action now reads `Edit` and loads that character directly into builder edit mode (instead of generic `Continue Building`).
- Character API ownership hardening: `GET /character-api/characters` is now authenticated and owner-scoped (admins excepted), preventing cross-account leaks even when records are public; added integration regression script `scripts/test-character-ownership.sh` (`npm run test:character-auth`).
- Character API list endpoint now includes a second defense-in-depth owner check during response assembly, so non-owner rows are dropped even if upstream query behavior is changed/misconfigured.
- Release gate hardening: `npm run rules:publish` now runs `npm run test:character-auth` before continuing, so character ownership isolation is validated on each publish (with explicit opt-out via `WS_SKIP_CHARACTER_AUTH_TEST=1` only when required).
- Enforced character-limit checks before creating new cloud/local copies.
- Added Settings page with account summary and persistent builder preferences.
- Hid empty character slots while list search filtering is active.
- Header/footer now use shared template rendering across builder/view/characters/settings pages.
- Back-to-builder button now appears under page title on non-builder pages.
- Added sort-direction indicators to Character List headers.
- Synced favicon assets from `whisperspace.com` into the character builder.
- Improved account menu hit-area sizing to resolve finicky hover/click behavior.
- Prototyped `augmented-ui` styling on builder shells (cards, tabs, modal cards, gear cards, primary CTAs).
- Increased augmented-ui prototype intensity for clearer visual comparison.
- Fixed OAuth/session cache behavior so stale cached null sessions do not mask fresh authenticated state after redirect.
- Added auth guard redirect from protected pages (`/characters`, `/settings`) to builder when logged out.
- Moved Previous/Next controls into the builder content card.
- Added drag-and-drop reordering for inventory and weapon cards.
- Increased vertical padding on gear cards for readability.
- Refactored gear step order and grouping: Weapons, Armour, then Items.
- Added collapsed-by-default item/weapon rows with click-to-expand card details.
- Added explicit drag handles to item/weapon rows to make reorder interactions discoverable.
- Added compact item quantity controls and weapon ammo controls (minus/reload) in collapsed rows.
- Added gameplay-effects editor/tag UX for items, weapons, and armour (typed target + signed amount, removable chips).
- Updated catalog search so matching owned gear appears alongside rule-catalog results.
- Unified cut-corner panel spacing to shared 25px top/bottom padding treatment and strengthened destructive-button hover contrast.
- Added collapsed-row column headers for weapon/item readability and icon-based reload control.
- Updated gear search behavior to filter both catalog options and current inventory/weapon rows.
- Gameplay effect add forms now auto-close after creating an effect tag.
- Improved drag/reorder reliability with explicit HTML5 drag payload handling.
- Reordered builder step flow to mirror character-creation progression (`Origin`, `Archetype`, `Feats`, `Skills`, `Attributes`, `Equipment`, `Review`).
- Consolidated builder progression by merging `Skills` + `Attributes` into one step (`Skills & Attributes`) with attributes displayed first.
- Updated `Skills & Attributes` presentation with explicit section headers and metric cards (main attributes + CUF/Speed/Carrying Capacity).
- Added hover/visual polish on attribute cards and skill rows; tooltip display now resolves from Rules API tooltip labels with safer fallback behavior.
- Moved background controls into `Origin`; `Archetype` now renders narrative guidance text sourced from Rules API content.
- Builder now sends normalized gameplay effects into calc derive endpoints so effects like `reflex+1` influence displayed derived attributes.
- Builder now extracts narrative copy from direct `rules.json` text nodes and decouples tooltip fetch from skills fetch so missing tooltip payloads do not break skills UI.
- Gear reorder handles now use stronger HTML5 drag payload/drop parsing semantics for better browser compatibility.
- Character builder Review step now uses a polished dashboard-style layout aligned with the project’s updated visual language.
- Builder calc calls were aligned to current API contracts by sending full equipment context and tolerating updated derive response field variants.
- Builder now normalizes gameplay-effect tags into a top-level `gameplayEffects` array for derive endpoints and omits per-entity effect fields in derive payload objects for deployed calc compatibility.
- Builder temporarily exposed an in-app calc debug panel during gameplay-effects rollout; this panel has now been removed from the user-facing UI after deployment validation.
- Builder now displays gameplay-adjusted effective skill ranks (capped at rank 5) and adds cancel actions to gameplay-effect editors for gear.
- Builder cloud-save pipeline now strips non-schema `gameplayEffects` fields from persistence payloads (while preserving gameplay tags in active editor state post-save) to avoid character API `validation_failed` responses.
- Builder save-options copy now labels the checkbox `Save as new character`; the old tooltip-style `i` label was removed.
- Builder now preserves `Review` as the active tab on refresh and uses `Save` (instead of `Next`) as the final-step primary nav action.
- Builder gear reorder interactions now start from the weapon/item row area (drag anywhere) rather than requiring a dedicated drag handle.
- Builder skills now render a 0-5 pip indicator beside rank controls for faster visual rank scanning.
- Builder origin Motivation/Background dropdowns now sync default selection to current sheet values (including loaded sheets).
- Builder weapon ammo controls now enforce catalog max ammo caps; melee weapons without explicit ammo now show `-` and disable/hide reload/decrement actions.
- Builder drag/drop now includes drag-state polish and live hover reflow while dragging gear cards.
- Builder drag/drop hover reordering now includes jitter guards (rate-limit + per-target dedupe) to reduce flicker during rapid dragover events.
- Builder right-column account menu now includes `Save`/`Import`/`Reset` actions, uses full-email account labels, and no longer renders a menu container border.
- Builder header now consumes cross-project nav JSON from `whisperspace.com/nav/main-menu.v1.json` so top-level site navigation updates can propagate without duplicating link config.
- Builder derive polling now uses request-signature dedupe + in-flight guards to reduce calc rate-limit churn during debugging.
- Builder derive triggers are now constrained to relevant state changes (skills + gameplay-effect fields + key step entry + save), with explicit 429 cooldown backoff.
- Builder now pulls concept and starting-credits narrative lines directly from Rules API `rules.json` for the Origin step.
- Added starting credits generator + manual override in Origin; equipment summary now shows current credits balance.
- Inventory add now increments quantity when an equivalent gear entry already exists instead of creating duplicate rows.
- Builder + SDK schema now support multiple carried armour entries (`armours`) with a single equipped selector (`equippedArmourId`) while maintaining legacy `armour` compatibility.
- Builder now includes a modular dice-roller service with swappable providers (default CSS 3D roller), so roll UX can be replaced without changing character-sheet logic.
- Builder equipment UX now supports carried-armour card management (equip-highlight workflow) and a `Buy` vs `Acquire` mode that can enforce credits and auto-deduct catalog costs on add actions.
- Builder armour UX now matches weapon/item row patterns: each armour row expands for edits, and equip state only changes via explicit `Equip` action.
- Builder armour purchases now always create separate carried-armour instances (no merge) so durability can be tracked independently per piece.
- Builder equipment add controls now switch to `Buy ... (<cost> credits)` labels in buy mode and auto-disable when credits are insufficient (while `Acquire` mode retains standard add behavior).
- Builder buy-mode economy now supports sell semantics on gear controls (remove and item quantity decrement), while item quantity increment in buy mode performs affordability-checked purchases with credit deductions.
- Builder now persists the active tab across refresh; Back/Next controls moved near step tabs.
- Supports post-save redirect to shareable character view URL (`/character/:id`).
- Rules/skills/gear catalogs load from Rules API with local cache fallback messaging.
- Gameplay-effect tags are now aggregated into a top-level `gameplayEffects` array for calc endpoints; gear payloads are omitted to avoid double-counting.
- Next steps:
- Expand character view page with fuller derived stats and gear totals.
- Add manual rules-cache refresh control.
- Keep gameplay-effects calc payload/response contract notes synced across repos as rules/calc evolves.
- Ensure gear mapped from rules catalogs preserves `gameplayEffects` (or at least passes effect text) so calc endpoints can apply gameplay deltas consistently.

### whisperspace-developer
- Current status:
- Recent milestones:
- Next steps:

### whisperspace-docs
- Current status: Public rules docs frontend is a chapter-driven React/Vite rulebook at `https://docs.whisperspace.com`, consuming canonical `rules.json` chapter hierarchy with runtime version-aware caching and sanitized rich rendering.
- Recent milestones:
- Added visual parity pass with builder app styling (`builder.whisperspace.com`): docs now uses the shared dark-blue gradient/panel language, matching typography direction (`Space Grotesk` + `Unbounded`), and aligned interaction accents for navigation/inputs/cards.
- Docs hierarchy polish: nested in-content sub-sections now render borderless while top-level section framing remains, and sidebar nested topic links now use slightly deeper indentation for clearer tree legibility.
- Docs content styling simplification: nested sub-sections now also drop distinct background fills, preserving background emphasis only at the main/top-level section layer.
- Docs container simplification: article-level wrappers (`<article>`) now render without border/background, with framing handled exclusively by parent sections.
- Docs polish follow-up: removed hero subtitle copy, aligned background glow/gradient direction more closely to builder visual language, and made no-subtopic chapter clicks navigate with chapter anchors so the view still pulls to the selected chapter content.
- Docs chapter-nav behavior refinement: clicking a chapter that has sub-topics now keeps the current viewport position instead of auto-scrolling to the top.
- Docs responsive layout tweak: chapter menu remains a left sidebar at OBR-like widths (collapse breakpoint reduced to ~760px), so in-VTT usage keeps side navigation.
- Docs default-route hardening: opening the rulebook now resolves `/` to whichever chapter is `Introduction` in live rules data (no hardcoded `/introduction` slug dependency), with legacy `/introduction` links retained as an alias.
- Implemented searchable rulebook navigation with chapter routes and topic-level hash linking.
- Added query-aware chapter/topic navigation counts with search-order sorting (DESC by matches) and scoped in-topic term highlighting when navigating to a matched topic.
- Fixed docs search UX edge cases: chapter-click highlighting now scopes to the opened chapter by default, search mode hides `Rulebook Home`, and route normalization handles trailing-slash chapter URLs.
- Hardened docs Apache SPA fallback by adding `FallbackResource /index.html` + `-MultiViews` in docs `.htaccess` and documenting required vhost overrides for deep-link refresh reliability.
- Added docs URL query search contract (`?search=<term>`) so chapter routes can deep-link directly into active search context (e.g., `/stress?search=stress`).
- Implemented parser-span link rendering in docs so internal rules references navigate to mapped chapter/topic routes instead of inert text.
- Switched docs topic hashes to human-readable slug anchors (with legacy hash compatibility mapping) for clearer shareable links.
- Improved docs table readability by compacting parser-expanded adjacent duplicate cells into merged display columns (`colSpan`), fixing repeated header/body labels on archetype/feat tables.
- Updated docs sidebar navigation to nested chapter/topic tree behavior (indented sub-topic menu under active category), aligning docs UX with rulebook hierarchy.
- Added variable-marker anchor normalization in docs (`(X)`/`(n)` references resolve to base anchors like `#bleeding`, `#emp`, `#agonized`) for consistent intra-rule linking.
- Added parser-link contract fallback logic in docs: while parser contract is `#slug`/`file.yaml#slug`, current payload still includes some legacy `#h...` anchors, so docs resolves these via heading-text + singular/plural matching.
- Added parser span-style rendering support in docs so inline formatting (`bold`, `italic`, `underline`, `strikethrough`, and linked combinations) is visible in chapter content.
- Simplified docs reading surface by removing inner content card borders while retaining outer content container framing.
- Added docs sidebar scrollspy behavior so active nested topic highlighting follows reader scroll position within a chapter.
- Fixed docs scroll-lock regression by stabilizing location callbacks so hash auto-scroll does not re-trigger every render while manually scrolling.
- Added docs search toggle (`Hide empty categories`, default enabled) so zero-match chapter categories can be hidden during query-driven navigation.
- Extended the same toggle to nested chapter sub-topic trees so unchecking it reveals non-matching sub-topics for context while searching.
- Reworked `whisperspace-docs/src/lib/rules.js` to normalize canonical chapter/topic nodes (`title`, `slug`, `content`, `sections`) instead of heuristic flat extraction.
- Added recursive topic rendering in `whisperspace-docs/src/App.jsx` so rule text appears under its true parent topics.
- Added chapter alias routes for high-intent entry points (`/skills`, `/weapons`, `/items`, `/armour`, `/cyberware`, `/hacking-gear`).
- Enabled rich content rendering via markdown parse + sanitization (`marked` + `DOMPurify`) for paragraph/list text.
- Added client-side cache orchestration in `whisperspace-docs/src/lib/rulesClient.js`: fetch `meta.json`, compare version against cached payload, serve cached rules on version match, and refresh cache when version changes.
- Added automatic docs background version checks (interval-based) while runtime continues version-aware cache reuse.
- Added Apache SPA hosting support (`public/.htaccess`) with rewrite fallback + static asset caching policy.
- Expanded `whisperspace-docs/README.md` with concrete integration contracts: endpoint URLs, env var override (`VITE_RULES_URL`), auth/CORS expectations, build/deploy workflow, and known gotchas.
- Next steps:
- Validate production CORS + endpoint behavior for `https://docs.whisperspace.com` against `https://rules-api.whisperspace.com/rules-api/latest/rules.json` and `meta.json`.
- Add a lightweight release smoke test (rules fetch + parse count threshold) to catch upstream payload regressions early.

### whisperspace-rules-parser
- Current status:
- Recent milestones:
- Next steps:

### whisperspace-sdk
- Current status:
- Recent milestones:
- Next steps:

- Builder header menu now nests `Save`/`Import`/`Reset` under `Character Builder`, removes the separate back-to-builder button, and fixes dropdown clipping/hit-area behavior.
- Builder weapons now render Rules API keyword chips with tooltip definitions (`weapon_keywords.json`), and gear rows now include consistent hover/equipped highlight styling.
- Builder header/actions were adjusted so `Save`/`Import`/`Reset` are larger horizontal controls under the page title, while account dropdown now contains `My Characters` above `Settings`; buy/sell action labels now use simplified text.

- Builder save-options modal now restores visibility from per-character preference history, and character list requests were hardened to cookie-session auth to stop cross-account character bleed-through.
- Builder gear card hover treatment now applies on expanded and collapsed cards uniformly; obsolete `.equipped-row` row-highlight styling was removed.

- Builder character-list UX now includes delete controls and copy-link confirmation feedback, and auth modal Enter key submits login while preserving save-flow intent (no unintended save menu on standard login).

- Builder now enforces logout safety on the editor: when auth is lost, cloud-only drafts are removed from active editing unless that character was explicitly saved to local storage by the user.
