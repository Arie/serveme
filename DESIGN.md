---
name: serveme.tf v2
description: A dense, precise dark operator UI for reserving TF2 servers.
colors:
  canvas: "#0b0d0f"
  hero: "#151a20"
  surface: "#1f252c"
  surface-raised: "#2a3138"
  inset: "#0a0c0d"
  line: "#363d45"
  line-strong: "#4a535c"
  line-soft: "#2c333a"
  state-hover: "rgba(255, 255, 255, 0.045)"
  highlight: "rgba(255, 255, 255, 0.055)"
  highlight-strong: "rgba(255, 255, 255, 0.09)"
  shadow-surface: "rgba(0, 0, 0, 0.28)"
  on-accent: "#17120b"
  on-solid: "#ffffff"
  text: "#e6e9ec"
  text-muted: "#a0a8b0"
  text-subtle: "#939ca5"
  accent: "#e97b18"
  accent-hover: "#f28c2e"
  on-accent: "#17120b"
  success: "#42b96a"
  danger: "#e5534b"
  warn: "#d9a441"
  info: "#4c93d6"
  gold: "#e0b64a"
  team-red: "#bd3b3b"
  team-blue: "#5b818f"
  shadow-contact: "rgba(0, 0, 0, 0.4)"
  shadow-ambient: "rgba(0, 0, 0, 0.35)"
  scrim: "rgba(0, 0, 0, 0.6)"
typography:
  display:
    fontFamily: "Archivo, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.75rem"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.02em"
  headline:
    fontFamily: "Archivo, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.25rem"
    fontWeight: 650
    lineHeight: 1.25
    letterSpacing: "-0.01em"
  title:
    fontFamily: "Archivo, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "normal"
  body:
    fontFamily: "Archivo, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 400
    lineHeight: 1.55
    letterSpacing: "normal"
  label:
    fontFamily: "Archivo, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.8125rem"
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: "normal"
  data:
    fontFamily: "JetBrains Mono, ui-monospace, monospace"
    fontSize: "0.9375rem"
    fontWeight: 500
    lineHeight: 1.4
    fontFeature: "tabular-nums"
  micro:
    fontFamily: "Archivo, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.6875rem"
    fontWeight: 600
    lineHeight: 1
rounded:
  sm: "4px"
  md: "6px"
  lg: "8px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  "2xl": "32px"
  "3xl": "48px"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
    typography: "{typography.title}"
  button-primary-hover:
    backgroundColor: "{colors.accent-hover}"
    textColor: "{colors.on-accent}"
  button-secondary:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
    typography: "{typography.title}"
  button-secondary-hover:
    backgroundColor: "{colors.line}"
    textColor: "{colors.text}"
  panel:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
    padding: "16px"
  input:
    backgroundColor: "{colors.inset}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
    padding: "6px 10px"
    typography: "{typography.body}"
---

# Design System: serveme.tf v2

## Overview

**Creative North Star: "The Operator's Console"**

serveme.tf v2 plays its category straight. There is no thematic world, no metaphor, and no irony: this is a conventional dark operator UI, and every point of quality comes from execution precision and product specificity rather than from a distinctive aesthetic. The named craft bar is Linear (for dark product UI: layered neutral values, a tight small type scale, visible 1px structure, small radii, solid fills, sparing accent, keyboard-quality focus) and the Stripe Dashboard (for data surfaces: tables, semantic status colour, tabular numerals, section hierarchy, real empty states).

The audience arrives mid-Discord-call with eleven people waiting. Density is a feature, but not at the cost of legibility — 13px was tried as the base and read as fine print. The interface is read at a glance and operated by muscle memory, so information is never traded for whitespace, and no decoration may cost a booking click. Where v1 was stock Bootswatch Slate — plain but honest and dense — v2 keeps that density and directness and adds the precision v1 never had.

The explicit anti-reference is the first v2 generation, which failed by being a low-fidelity imitation of this same canon: a near-black ground with one orange accent doing seven different jobs, 16px rounded cards floating on a void, a radial accent glow standing in for structural depth, and a marketing headline larger than the live data it was supposed to support.

**Key Characteristics:**
- Layered neutral values carry depth; there is no glow and almost no shadow.
- One accent, one job: the primary action.
- Numbers are monospaced and tabular everywhere, without exception.
- Structure comes from visible 1px rules and full-width bands, not from floating cards.
- 15px is the base size; large type is rare and deliberate.

## Colors

A cool gunmetal neutral ramp inherited in spirit from v1's Bootswatch Slate, carrying a single warm amber action colour and a disciplined set of semantic states.

### Primary
- **Signal Amber** (`{colors.accent}`): The primary action only — "Get server", "Donate now", the one button per region of the page that the user is meant to press. It descends from v1's `btn-warning` amber (`#f89406`), the one warm hue with genuine incumbent lineage.

### Neutral
- **Console Canvas** (`{colors.canvas}`): The page ground. Dark enough for a lit-room evening session, light enough to keep panels legible above it.
- **Panel** (`{colors.surface}`): Cards, bands, table containers. One clear step above the canvas.
- **Raised** (`{colors.surface-raised}`): Row hover, secondary buttons, active nav.
- **Well** (`{colors.inset}`): Inputs, code, log output, anything recessed.
- **Rule** (`{colors.line}`): The default 1px border. Deliberately visible — structure is drawn, not implied.
- **Strong Rule** (`{colors.line-strong}`): Table header underlines and section divisions that must read at a glance.
- **Ink / Muted Ink / Subtle Ink** (`{colors.text}` / `{colors.text-muted}` / `{colors.text-subtle}`): Primary copy, secondary copy, and labels. All three clear 4.5:1 on both canvas and panel.

### Secondary
- **State Green** (`{colors.success}`): Available capacity, running reservations, success flashes.
- **State Red** (`{colors.danger}`): Errors, bans, destructive actions, at-capacity.
- **State Blue** (`{colors.info}`): Informational, links in prose, cloud-server affordances.
- **Caution** (`{colors.warn}`): Expiring reservations, quota warnings.
- **Donator Gold** (`{colors.gold}`): Premium and donator identity only. Inherited from v1, where gold has always meant donator.

### Tertiary
- **Team Red / Team Blue** (`{colors.team-red}` / `{colors.team-blue}`): TF2's own team colours, used only where the product is genuinely reporting a team — the match scoreboard and team bars. These are product data, not palette; they may never be borrowed for emphasis, state, or decoration.
- **Shadow Contact / Shadow Ambient / Scrim** (`{colors.shadow-contact}` / `{colors.shadow-ambient}` / `{colors.scrim}`): the two layers of the Overlay shadow, and the modal backdrop fill.

### Named Rules
**The One Job Rule.** Signal Amber marks the primary action and nothing else. It is never a link colour, never a headline highlight, never a progress fill, never body emphasis. If two amber things are visible in one viewport, one of them is wrong.

**The State-Colour Rule.** Green, red, blue, amber-caution and gold carry meaning, never mood. A colour may not be applied because a surface looked flat.

**The Structural Depth Rule.** Depth is made of neutral value steps and 1px rules. Glows, coloured halos, and accent-tinted background gradients are prohibited — that device is precisely what made the first v2 read as generic.

## Typography

**Display / Body Font:** Archivo (with `ui-sans-serif, system-ui, sans-serif`)
**Data / Mono Font:** JetBrains Mono (with `ui-monospace, monospace`)

**Character:** A workhorse grotesque doing ordinary UI work at small sizes, paired with a mono that exists strictly for measurement. Both are already self-hosted in `public/fonts/v2/`; the system deliberately adds no faces, because in a played-straight canon the type is not where the personality lives.

### Hierarchy
- **Display** (700, 28px, 1.15, -0.02em): The page's one Display-sized object. Rare — one per page at most, and never larger than 32px. It is not automatically the headline: on the homepage it is the availability figure, because the Don't below forbids a marketing headline outweighing the live data it supports. The claim takes Headline; the proof takes Display.
- **Headline** (650, 20px, 1.25): Section headings and band titles.
- **Title** (600, 16px, 1.4): Card headings, table captions, button labels.
- **Body** (400, 15px, 1.55): All prose and UI text. Prose measure caps at 68ch.
- **Label** (500, 13px, 1.3): Field labels, table headers, metadata. Sentence case.
- **Data** (500, 15px, tabular-nums): Every number, ID, IP, port, timestamp, connect string, and score.
- **Micro** (600, 11px, 1.0): The one sub-label step, permitted **only** for text set inside a data-visualisation bar whose height is fixed below 24px — currently just the server-reservations gantt. It is not available for UI labels; reach for Label instead.

### Named Rules
**The Tabular Rule.** Any digit a user might compare against another digit is set in JetBrains Mono with `font-variant-numeric: tabular-nums`. Counts, currency, times, ping, ports, scores. No exceptions — misaligned columns of proportional digits are the single most common tell of an unconsidered data UI.

**The Small-Type Rule.** 15px is the base. Reach for display sizes only when a number or headline is genuinely the most important object on the screen, and then let it be clearly the biggest thing rather than competing with a second large element.

**The No-Eyebrow Rule.** No tracked uppercase kicker above section headings. Sections are introduced by a headline and a rule, not by decorative labels.

## Layout

A single centred container at `max-width: 1280px` with `26px` gutters, inherited from the incumbent v2 layout.

Spacing runs on a strict 4px grid (`4 / 8 / 12 / 16 / 24 / 32 / 48`). Group related elements tightly and separate groups generously; headings always carry more space above than below.

Page structure is made of **full-width bands separated by 1px rules**, not of floating cards on a void. A band may contain panels, but the band itself reaches the container edges and is delimited by its rule. This is the structural fix for the first v2's two-cards-on-emptiness problem, and it is what lets a short anonymous page still feel built rather than abandoned.

Tables are the primary content form. Row height 36px, 8px vertical / 12px horizontal cell padding, numeric columns right-aligned, header row in Label type over a Strong Rule underline.

Breakpoints follow Tailwind defaults; the meaningful one is `md` (768px), where multi-column bands collapse to stacked full-width blocks and tables gain horizontal scroll inside their own container rather than breaking the page.

## Elevation & Depth

This system is **tonally layered with light material cues**. Depth comes from three stacked devices, in this order of importance:

1. **Value steps.** Canvas → hero → panel → raised is a real ramp, wide enough to read without help. This carries most of the depth. The steps measure 1.11 / 1.13 / 1.17:1 — an earlier ramp measured 1.09 / 1.04 / 1.14, where the hero→panel step was invisible and the borders were silently doing all the work. Any change to these five values must be re-measured, and Subtle Ink must keep 4.5:1 on Raised (it is the first thing that fails when the ramp is lifted).
2. **A 1px lit top edge.** Raised surfaces take `inset 0 1px 0 {colors.highlight}`, the way a panel catches light from above; recessed surfaces (inputs, wells, meter tracks) invert it to an inner top shadow. This is the cue that stops a dark UI reading as printed-on.
3. **A shallow contact shadow.** `0 1px 2px {colors.shadow-surface}` on panels and the nav — a real offset and a tight blur, so a surface sits *on* the page rather than in it.

Genuinely floating UI (dropdowns, popovers, dialogs) escalates to the Overlay shadow. Nothing else does.

### Shadow Vocabulary
- **Surface** (`box-shadow: 0 1px 2px {colors.shadow-surface}, inset 0 1px 0 {colors.highlight}`): Panels, cards, table containers, the nav.
- **Recess** (`box-shadow: inset 0 1px 2px {colors.shadow-surface}`): Inputs, wells, connect boxes, meter tracks.
- **Control** (`box-shadow: inset 0 1px 0 {colors.highlight-strong}`): Buttons, so they read as pressable rather than painted.
- **Overlay** (`box-shadow: 0 1px 2px {colors.shadow-contact}, 0 8px 24px {colors.shadow-ambient}`): Dropdowns, popovers, dialogs only.

### Named Rules
**The No-Halo Rule.** A zero-offset coloured glow is never depth. The `radial-gradient` accent wash behind the first v2's body is removed and must not return. A hairline white highlight and an offset black shadow are material; a coloured bloom is decoration.

**The Plane Rule.** A page may establish at most one full-bleed plane above the canvas — currently the masthead, via `.v2-bleed` + `hero`. Bands do not each get their own tint; that is how a page becomes a stack of cards again.

## Shapes

Rectilinear and tight. Corners are `4px` on small controls (table-embedded actions), `6px` on buttons and inputs, and `8px` on panels and bands. No rectangular surface exceeds 8px — the 16px card radius of the first v2 is the single strongest contributor to its generic reading.

The one exception is `pill` (999px), reserved for genuinely capsule-shaped elements: status badges, chips, the state dots in the status readout, and the funding meter's track and fill. A pill is a shape decision for a small capsule, never a way to soften a panel.

Borders are 1px and visible. A coloured border wider than 1px on a card, callout, or list item is prohibited.

### Named Rules
**The Visible Track Rule.** Any meter, bar, or track carries its own value step (`surface-raised`) plus a 1px rule, so an empty or zero-value meter still reads as a control rather than disappearing into the page.

## Components

### Anonymous primary action
Signed out, the single primary action is **Sign in through Steam**, and it says so. Both `Get server` and `1-click server` sit behind `authenticate_user!`, so offering them to a signed-out visitor promises a server and delivers an OAuth redirect — and `1-click` in particular offers to repeat a reservation a first-timer has never made. The button carries a plain reassurance line ("Free, and there's no account to make."), and 1-click is described in prose instead of offered as a control.

### Buttons
- **Shape:** Slightly softened rectangle (6px), 8px/16px padding, Title type.
- **Primary:** Solid Signal Amber with near-black text. Flat fill — no gradient, ever. One per region.
- **Secondary:** Raised surface with a 1px Rule border and Ink text.
- **Ghost:** Transparent with Muted Ink text; background lifts to Raised on hover.
- **Hover / Focus:** Hover shifts background one value step in 120ms. Focus shows a 2px Signal Amber outline at 2px offset — visible, never removed.
- **Disabled:** 45% opacity, `cursor: not-allowed`, no hover response.

### Cards / Containers
- **Corner Style:** 8px.
- **Background:** Panel over Canvas.
- **Border:** 1px Rule.
- **Shadow:** None. Panels sit on the page, they do not float above it.
- **Internal Padding:** 16px, or 24px for a band's primary panel.
- **Nesting:** Prohibited. A panel inside a panel is always a layout failure; use a rule instead.

### Tables
- **Header:** Label type in Subtle Ink over a 1px Strong Rule.
- **Rows:** 36px, separated by 1px Rule, hover to Raised.
- **Numerics:** Data type, right-aligned, tabular.
- **Empty state:** A real sentence naming what would appear here and the action that creates it — never a bare "No records".

### Inputs / Fields
- **Style:** Well background, 1px Rule, 6px radius, Body type.
- **Focus:** Border shifts to Signal Amber plus a 2px amber outline at 2px offset.
- **Error:** Border and message in State Red; the message names the problem and the recovery.

### Navigation
- **Style:** Full-width bar on Panel with a 1px Rule underline, Body type in Muted Ink.
- **States:** Hover lifts to Raised and Ink; the active item is Ink with a 2px Signal Amber underline.
- **Mobile:** Collapses to a disclosure below `md`.

### Footer
Lives in the `application_v2` layout, not in individual pages, so every redesigned page terminates the same way instead of stopping in mid-canvas. The body is a flex column with the footer at `mt-auto`, so a short page still ends at the bottom of the viewport. Carries the provider credit with its logo, and the site links. Only providers actually documented on `/server-providers` may appear — the unreferenced logo files in `app/assets/images/server_providers/` are legacy assets, and showing them would claim sponsorships the product does not have.

### Status Readout (signature component)
The live capacity block that answers "is a server free right now". It reports **every tier the visitor is entitled to see** — for anonymous visitors, both free and premium pools — as label / fraction / state-dot rows. The fraction is Data type; the dot takes State Green when capacity remains and State Red at zero. This component is the page's proof, and it may never be reduced to a single undifferentiated number.

### Goal Meter (signature component)
The monthly donation bar. It must express **over-goal honestly**: the fill saturates at 100% while the numeric label reports the true figure and percentage, so exceeding the target reads as success rather than as a full, meaningless bar.

## Do's and Don'ts

### Do:
- **Do** set every comparable number in JetBrains Mono with tabular figures.
- **Do** build page structure from full-width bands divided by 1px rules.
- **Do** keep one primary action per region, in Signal Amber, as a flat fill.
- **Do** show both capacity tiers in the status readout, as v1 did.
- **Do** state real numbers with their units and their totals (`2 / 5 servers`, `€517 of €340`), never a bare figure.
- **Do** keep the base size at 15px and let density be the point.

### Don't:
- **Don't** reintroduce the radial accent glow, gradient button fills, or 16px card radii.
- **Don't** build a row of equal-width stat tiles. Four same-sized figures say nothing is more important than anything else; lead with the one figure that matters and let the rest support it.
- **Don't** use Signal Amber for links, headline highlights, progress fills, or body emphasis.
- **Don't** nest panels, or place a coloured border wider than 1px on any container.
- **Don't** let a marketing headline outweigh the live data it is meant to support.
- **Don't** collapse a multi-tier fact into one number because it fits the layout better.
- **Don't** add a font, an icon set, or a decorative device to solve a problem that hierarchy would solve.
