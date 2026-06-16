# serveme.tf v2 (redesign beta) conversion style guide

You are converting existing Bootstrap/Haml views to the v2 dark redesign ("Direction A — Command").
For each assigned full-page template `X.html.haml`, create a sibling `X.html+v2.haml`. Under the
beta cookie, Rails auto-renders the `+v2` variant inside `layouts/application_v2` (a dark, Tailwind
layout that loads `public/builds/v2.css`). Adding the `+v2` file is all that's needed to activate it.

## Hard rules
1. **Preserve ALL behavior**: every Ruby expression, path helper, conditional, instance variable,
   loop, form field name, and JS hook MUST carry over unchanged. You are restyling markup only —
   never change controllers, routes, models, JS, or the classic templates.
2. **Preserve JS hooks verbatim**: `data-controller`/`data-action`/`data-*-target` (Stimulus),
   `data-bs-toggle`/`data-bs-target` (Bootstrap dropdowns/modals/collapse), `data: { turbo_method: }`,
   `data: { confirm: }`, `data: { turbo: false }`, element `id`s, and the CSS classes/ids that
   select2 / datepicker / serveme.js attach to (e.g. `.datepicker`, select hooks). All JS
   (Bootstrap, jQuery, select2, datepicker, Stimulus, Turbo) IS loaded in the v2 layout.
3. **Haml + Tailwind**: Tailwind classes containing `/ : [ ] .` (e.g. `border-white/10`,
   `md:grid-cols-2`, `max-w-[1280px]`) MUST go in a `{class: "..."}` hash, NEVER in dot-shorthand.
   Also: do NOT use the class name `collapse` (Tailwind makes it `visibility: collapse`).
4. **Do NOT edit** `config/tailwind/v2.tailwind.css` or any shared file. Use the classes below +
   standard Tailwind utilities only. If you genuinely need a missing component, note it in your
   report instead of editing shared CSS.
5. Also create `+v2` variants of any **partials** your pages render that contain Bootstrap markup
   (e.g. `_form`, `_table`, `_row`). Partials live in the same dir; name them `_foo.html+v2.haml`.
   They auto-resolve under the v2 variant. Shared partials already done: `shared/_navigation`,
   `shared/_flash`, `reservations/_actions`, `reservations/_zip_file_link`,
   `reservations/_users_games`, `reservations/_users_reservations`. Do NOT recreate those.

## Layout conventions
- Page heading block (top of most pages):
  ```haml
  %div{class: "flex items-center justify-between gap-4 my-6 flex-wrap"}
    %div
      %h1{class: "v2-page-title"} Page title
      -# optional: %div{class: "v2-breadcrumb"} Section / Sub
    -# optional primary action on the right:
    = link_to "New thing", new_thing_path, class: "v2-btn v2-btn-primary"
  ```
- Wrap forms and standalone content in `%div{class: "v2-card"}` (or `v2-elevated` for hero-ish).
- Constrain form width with e.g. `max-w-2xl` / `max-w-3xl`.

## Component classes (defined in v2.css — use these)
- Surfaces: `v2-card`, `v2-elevated`, `v2-inset`, `v2-table-wrap`
- Buttons: `v2-btn` + one of `v2-btn-primary | v2-btn-outline | v2-btn-ghost | v2-btn-info | v2-btn-danger`; add `v2-btn-sm` for small. Inline table chips: `v2-action` + color utilities.
- Forms (when writing raw inputs): `v2-label`, `v2-input`, `v2-select`, `v2-textarea`, `v2-help`, `v2-error`, `v2-mono`
- Tables: `%div.v2-table-wrap > %table.v2-table` (thead th / tbody td auto-styled)
- Badges: `v2-badge` + `v2-badge-success | v2-badge-info | v2-badge-gold | v2-badge-danger`
- Status dot: `%span{class: "v2-dot bg-success"}` (pulsing)
- Page: `v2-page-title`, `v2-breadcrumb`

## simple_form
Keep `simple_form_for(...)` exactly as-is — its generated `.form-control`/`.form-group`/`.form-check`
markup is already themed for v2 by a compatibility layer. Just wrap the form in a `v2-card` and
restyle the submit button as `class: "v2-btn v2-btn-primary"`. You may add
`input_html: { class: "v2-input" }` for polish but it is not required.

## Bootstrap compatibility
A compat layer themes Bootstrap class names (`.btn`, `.table`, `.row`/`.col-*`, `.form-control`,
`.alert`, `.badge`, `.card`, `.pagination`, `.dropdown-menu`, `.modal`) for v2. So if a chunk of
markup keeps Bootstrap classes it will still look acceptable — but PREFER the `v2-*` components and
Tailwind utilities for anything you actively rewrite. Replace Bootstrap layout helpers
(`.row`/`.col-md-*`, `.d-flex`, `.mt-3`) with Tailwind (`grid`/`flex`, `gap-*`, `mt-3`) where you can.

## Design tokens (Tailwind theme — use as utilities)
- bg: `bg-page bg-hero bg-panel bg-elevated bg-inset`
- text: `text-ink text-muted text-faint text-accent text-accent-light text-success-text text-info text-gold text-danger`
- borders: `border border-white/10` (hairlines); radii `rounded-card rounded-btn rounded-pill`
- fonts: `font-display` (Archivo, headings), `font-mono` (JetBrains Mono — ALL data: ids, ips, times, counts, passwords, hostnames)
- flags: reuse the existing sprite — `%span{class: ["flags", "flags-xx"]}` or a decorator's `.flag`. Never emoji.

## Verification (required before reporting done)
- The page must render without error. Verify via the existing test suite if the controller has a
  `render_views` spec, OR write a TEMPORARY throwaway spec / `bin/rails runner` render and DELETE it.
- Confirm no Haml parse errors and no leftover dot-shorthand Tailwind classes.
- Commit your area with a clear message. The repo BLOCKS `Co-Authored-By` trailers — do NOT add any
  AI attribution to commit messages.
