# serveme.tf Redesign — Opt-in Beta (Direction A "Command")

**Date:** 2026-06-15
**Status:** Approved design, ready for implementation planning
**Source design:** `~/Projects/fakkelbrigade/design_handoff_serveme_redesign/` (`README.md`, `Serveme Redesign.dc.html`, `support.js`)

## Goal

Implement the serveme.tf visual redesign (Direction A — "Command") in Tailwind, deployed in
the existing codebase behind an **opt-in cookie** so real users can test it without any change
to the current site for everyone else. Ship **Home first**, then iterate to the other screens
through the same mechanism.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Delivery | In-codebase, opt-in via cookie set from a `/beta` page (no subdomain) |
| Visual direction | **A — "Command"** only (Archivo + JetBrains Mono, rounded, soft shadows). Direction B dropped. |
| First scope | **Home / landing** (`pages#welcome`), then iterate |
| CSS coexistence | Scoped Tailwind via `tailwindcss-rails`, loaded **only** in the v2 layout |

## Non-goals

- No second deployment, subdomain, or separate database.
- No changes to the default (non-beta) render path — the live site must be byte-for-byte unchanged
  for users who don't opt in.
- No port of `support.js` (prototype runtime only).
- No Direction B (Arena), no `clip-path` / hazard-stripe panel motif beyond the existing donation bar.
- Book-a-server and Reservation-detail screens are **future iterations**, not this plan.

---

## Architecture

### 1. Opt-in gating — cookie + Rails template variants

The redesign uses the **same app, routes, controllers, and data** as today. The toggle is a cookie
combined with Rails [template variants](https://guides.rubyonrails.org/layouts_and_rendering.html#the-variants).

- **`/beta` page** — new explainer page describing the refresh, with:
  - **"Try the new look"** → `POST /beta/enable` sets a persistent cookie `ui_v2=true`.
  - **"Switch back"** → `DELETE /beta/disable` clears the cookie.
  - Optional `?ui=v2` / `?ui=off` query param flips the cookie inline (for sharing a link).
- **`ApplicationController`** gains:
  - A `before_action :set_beta_variant` that, **only when the cookie is set AND the current
    `controller#action` is on a small `REDESIGNED` allow-list**, sets `request.variant = :v2`.
  - `layout :resolve_layout`, returning `"application_v2"` when the v2 variant is active for this
    request, otherwise `nil` (the normal `application` layout).
- **`beta_ui?` helper** exposes the active state to views (for the "you're on the beta" banner / switch-back link).

```ruby
# Conceptual — exact shape decided in the plan.
REDESIGNED_ACTIONS = {
  "pages" => %w[welcome],
  # "reservations" => %w[new show],   # added in future iterations
}.freeze
```

**Why this design**

- **Per-screen rollout is free.** A screen becomes "redesigned" only when both (a) a
  `*.html+v2.haml` template exists and (b) its action is in `REDESIGNED_ACTIONS`. Beta users see the
  new Home and the **existing** Bootstrap pages everywhere else — an intentional, harmless mixed state.
- **Zero regression risk.** The default render path (no cookie, or action not on the list) is never
  altered. Non-beta users get the current site unchanged.
- **No template duplication** for un-ported pages — Rails variant fallback resolves to the normal
  template when no `+v2` variant exists.

**Why not a subdomain:** chosen against. A cookie/`/beta` route needs no extra Kamal service, no
second host across the 4 regions (EU/NA/AU/SEA), no duplicated session/auth cookies, and beta users
sit on the exact same data. Promotion to `beta.serveme.tf` remains possible later but is not required.

### 2. CSS strategy — layout-scoped Tailwind, Preflight contained

- Add the **`tailwindcss-rails`** gem. It builds via the standalone Tailwind CLI (no Node required)
  and hooks into `assets:precompile`, so Kamal deploys need no extra steps.
- Output to **`app/assets/builds/tailwind_v2.css`** (replacing the orphaned, unreferenced stale
  `app/assets/builds/tailwind.css`, Tailwind v3.0.5, which is not in the Gemfile or manifest today).
- The v2 stylesheet is **`stylesheet_link_tag`'d only inside `application_v2.html.haml`**. Because
  Bootstrap pages never load it, Tailwind **Preflight** is contained to v2 pages by construction —
  we keep Preflight (desired for the new design) with no leakage onto the live Bootstrap UI.
  Isolation comes from *which layout links the file*, not from class-prefixing.
- **Design tokens (Direction A)** go into the Tailwind theme config:
  - Accent orange `#f2742c`; CTA gradient `#f98c43 → #ee5f29` (135deg); orange-light text `#f2a36c`.
  - Page bg `#0b0c0e`, hero `#0e1014`, panel `#101216`/`#121419`, elevated `#16191f`, inset `#0c0e12`/`#08090b`.
  - Text primary `#e7e9ee`, muted `#9aa0ab`, faint `#6b7280`. Success `#3ecf8e`, info blue `#4aa3df`, gold `#f2c14e`.
  - Radii: cards 14–18px, buttons 9–11px, pills 20–30px. Elevated/CTA shadows per handoff tokens.
- **Fonts**: **Archivo** (400–900) and **JetBrains Mono** (400/500/700) **self-hosted** (woff2 in the
  asset pipeline + `@font-face`) — avoids Google-Fonts CSP and privacy concerns. JetBrains Mono is used
  for all data/IP/time/ping/password/count values; Archivo for display + body.

### 3. First screen — Home (`pages#welcome`)

New `app/views/pages/welcome.html+v2.haml` plus a v2 nav partial
`app/views/shared/_navigation.html+v2.haml` (same links/structure, restyled). Built entirely from
**existing data and partials** — the action already loads `@users_reservations` and `@users_games`:

| Redesign block | Existing source to reuse |
|---|---|
| Three primary actions | `new_reservation_path` (Get server), `i_am_feeling_lucky_reservations_path` (1-click), cloud via `current_user.can_use_cloud_servers?` / `cloud_server_access?` |
| Availability gauge card | `reservations/available_servers` partial logic / server counts |
| Donation row + striped bar | `Order.monthly_goal`, `Order.monthly_total`, `Order.monthly_goal_percentage`; `shared/donation_target` partial |
| "Reservations you played in" table | `@users_games` → `reservations/users_games` |
| "Your most recent reservations" table | `@users_reservations` → `reservations/users_reservations` |
| Flags | **Existing flag sprite system** (`_flags.css.scss` + helper) — not emoji |
| Copy buttons | Existing copy-button Stimulus controller / `_copy_button` partial |
| Pulsing "live" dot, hazard stripes | Pure CSS (no JS) |

Eyebrow "N servers live right now" and the EU/NA/AU region breakdown use real server counts where
cheap; the region split is best-effort/illustrative if no single-query source exists.

**Caching catch (must fix):** `pages#welcome` uses
`caches_action :welcome, cache_path: -> { "welcome_#{Time.zone}" }, unless: -> { current_user }`.
The key includes only `Time.zone`, so a logged-out beta visitor and a logged-out non-beta visitor
would be served each other's cached HTML. The variant must be added to the cache key (e.g. include
`cookies[:ui_v2]` / the resolved variant), or caching skipped when the beta variant is active.

---

## Routes (added)

- `GET  /beta`         → `beta#show`   (explainer + screenshots + toggle buttons)
- `POST /beta/enable`  → `beta#enable` (set `ui_v2` cookie, redirect to root)
- `DELETE /beta/disable` → `beta#disable` (clear cookie, redirect to root)

A small "You're viewing the beta · switch back" banner/link appears in the v2 layout.

## Testing

- **Request specs**
  - Cookie set + allow-listed action (`pages#welcome`) → renders `application_v2` layout + `+v2` template.
  - Cookie set + non-listed action → renders the original layout/template (mixed-state proof).
  - No cookie → renders original layout/template (zero-regression proof).
  - `/beta/enable` sets the cookie and redirects; `/beta/disable` clears it.
  - Logged-out caching: beta and non-beta logged-out visitors get distinct cached HTML.
- **Existing** `pages#welcome` specs stay green on the default path.
- **Playwright** screenshot of the beta Home for visual sign-off against the prototype.

## Deployment

Standard Kamal deploy to all four regions. Cookie defaults off → no user-visible change until a user
visits `/beta` and opts in. No new infra, services, or env vars.

## Future iterations (separate specs/plans, same mechanism)

1. **Book a server** — `reservations#new` (form, server picker, config/whitelist/map, toggles, sticky summary).
2. **Reservation detail / logs** — `reservations#show` (connect panel, controls, live status polling, countdown).

Each is added by creating its `*.html+v2.haml` template, registering the action in
`REDESIGNED_ACTIONS`, and wiring any extra controller data — no change to the gating or CSS approach.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Tailwind Preflight restyles live Bootstrap pages | v2 stylesheet linked only in the v2 layout; never loaded on Bootstrap pages. |
| Action-cache serves wrong variant to logged-out users | Add variant to `caches_action` cache key (or skip cache when beta active). |
| Asset precompile / build breakage on deploy | `tailwindcss-rails` integrates with `assets:precompile`; verify in CI (`script/test`) and a region smoke test. |
| Sorbet/`script/test -a` gates | New controller (`BetaController`) and concern get sigs per repo conventions; run full `script/test -a` before merge. |
