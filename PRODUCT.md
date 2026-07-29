# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Design defaults to **all audiences, booking flow first**.

- **Repeat competitive TF2 player or team leader** (primary situation for the booking flow). Time-pressured, often mid-Discord-call with 11 other people waiting. Knows the product. Job: get a working server and a connect string with minimum friction, usually reusing last time's settings.
- **First-timer sent by a teammate or a Discord link** (carried by home page and FAQ). Job: understand what serveme.tf is and reach a server that works.
- **Power users — site admins, league admins, streamers, trusted API partners (e.g. TF2Center)** (kept dense and separate). Jobs: whitelists, server configs, league map lists, STAC anti-cheat review, alt-account investigation, bulk/API reservations, cloud and Docker host management.

Group-based permissions gate these audiences: Admin, Donator, League Admin, Streamer, Trusted API, and per-user private-server groups.

## Product Purpose

serveme.tf lets people reserve a Team Fortress 2 game server for a time slot, configures and provisions it automatically, and hands back credentials plus a `steam://` connect link. During the reservation the user controls the server through web RCON; afterwards logs, demos, and STAC anti-cheat output are available. Success is a booked server that players actually connect to, fast, without a support conversation.

## Positioning

**Speed: a TF2 server in 60 seconds or less.** The durable claim is reserve-to-connect time, not feature count — including 1-click reservation, which re-books the user's previous configuration (same settings, same server, 2 hours, starting now) and falls back through same-machine → same-country → any available server.

Supporting truths that are real but not the lead: the service is free and donation-funded, deployed across four regions, and built natively for competitive TF2 (whitelists, league configs, logs.tf and demos.tf integration, STAC).

## Operating Context

- Users arrive from Discord, mid-organization of a scrim/PCW/mix/lobby/official. The competing clock is social, not technical.
- The output of a successful session is something pasteable into Discord: connect string with password, or a `steam://` link.
- Reservations are scheduled ahead as well as started immediately; collision detection across servers and time slots is a core mechanic.
- Web RCON is used live, during a match, sometimes on a second monitor or a phone.
- Regions run as separate deployments the user switches between by hostname: EU (serveme.tf), NA (na.serveme.tf), AU (au.serveme.tf), SEA (sea.serveme.tf). Player IP data does not sync between them.
- Allowed use is anything vaguely related to competitive TF2 — 1v1s, clan practice, PCWs, scrims, mixes, lobbies, officials. Not pubs, not MvM, not bot-heavy loads.

## Capabilities and Constraints

Confirmed capabilities: Steam-only authentication (Devise + OmniAuth); reservation create/extend/end; server selection with collision detection; server configs and competitive whitelists; map uploads (donators); web RCON and MOTD editing; log and demo access, logs.tf and demos.tf integration; STAC anti-cheat log processing; alt-account and ASN search for league admins; donations and premium products via PayPal and Stripe; vouchers; a JSON API with Swagger docs at `/api-docs` and region-scoped API keys; a Discord bot; admin tooling for products, users, maps, Docker hosts, cloud image builds, site settings, and server notifications.

Server types: LocalServer, SshServer, RconFtpServer, NfoServer/TragicServer, and CloudServer (Hetzner Cloud, Vultr, RemoteDocker).

Durable constraints confirmed by the user:

- **The v2 Tailwind track is the committed direction.** The `+v2.haml` templates behind the `ui_v2` gate are where the product is going; the v1 Bootstrap templates are legacy to be retired, not co-designed.
- **Every change ships in all four regions.** One codebase serves EU/NA/AU/SEA; region switching stays a first-class affordance and nothing may assume a single region.
- **English only, dark UI only.** Locales are `en`, `en-AU`, `en-SG`, `en-US` — regional variants, not translations. There is no light-mode requirement.
- **Donations and sponsor visibility are load-bearing.** Premium/donate paths, the donation target, and the server-provider/sponsor credits fund the service and must stay prominent.

Technical constraints: Ruby on Rails with Haml views, Hotwire/Turbo, Stimulus, import maps; PostgreSQL and Redis; Sidekiq for background work; deployed with Kamal behind kamal-proxy. Tailwind v4 for v2 is served as a static prebuilt stylesheet from `public/` because sassc-rails cannot parse it. Bootstrap-compat CSS still coexists with the v2 layer.

Open / undecided: the v1 → v2 retirement timeline, and whether the `ui_v2` cookie gate becomes the default.

## Brand Commitments

- Name and wordmark: **serveme.tf**, lowercase, with the regional hostname shown in the navbar as the region switcher.
- Voice: plain, warm, slightly jokey, first-person plural, self-deprecating about being a free community service ("Hey there, we hope you're enjoying serveme.tf", "This is the easiest way to borrow a TF2 server!"). Not corporate, not hype.
- The site is open source (github.com/Arie/serveme) and links to its Discord and GitHub in the navigation; both are part of the identity.
- The existing v1 Bootstrap UI is **evidence, not an anchor**: the user's decision is to keep what it got right functionally — its information density and layout habits — while committing to a genuinely new visual world for v2 that is neither v1 nor the current generic v2.
- Stated design problem to solve: the current v2 layout "looks way too AI-ey" and lost the hand-made character of the original.
- **Standing direction preference: play the category straight.** Offered a distinctive visual world ("Instrument Bay", derived from TF2's server browser and net_graph) alongside two alternates, the user chose the category standard executed at full fidelity. serveme.tf v2 is a conventional, precise operator UI — no thematic world, no irony, no smuggled quirk. Quality comes from execution precision and product specificity, not from a distinctive aesthetic. This is durable and applies to future surfaces unless the user reopens it.
- **Craft bar: Linear and the Stripe Dashboard.** Named by the user as the products v2 should sit alongside. Linear sets the bar for dark operator UI (layered neutral values, tight small type scale, visible 1px structure, small radii, solid fills, sparing accent, keyboard-quality focus states). Stripe sets the bar for data surfaces (tables, semantic status colour, tabular numerals, section hierarchy, real empty states). Design review is against these two, not against a mood.
- Colour lineage: v1 runs Bootswatch **Slate** — `--primary #3A3F44` gunmetal, amber `#f89406` as *warning* only (the 1-click button), `#62c462` success, `#5bc0de` info, gold reserved for donators. Orange as a brand accent was introduced by the v2 generation and has no incumbent basis; amber is legitimate as a single action/warning colour, not as an all-purpose brand hue.

## Evidence on Hand

Real assets and content that exist in the repository — no testimonials, benchmarks, or customer logos may be invented:

- Sponsor/server-provider logos: `app/assets/images/server_providers/`, surfaced at `/pages/server_providers`.
- Payment marks: `paypal-logo.svg`, `powered_by_stripe*.png`, `card-logo.svg`.
- Real usage data rendered live: site totals, reservations-per-day and reserved-hours-per-month graphs, top-10 servers and users, donator leaderboard, player statistics, server statistics, recent reservations, and a player globe.
- TF2-native imagery: `class_icons.png`, `killicons.webp`, country flag sprites.
- Credits page listing real contributors; FAQ and privacy pages with real copy.
- Discord and GitHub marks.

Known copy drift to verify before reuse: the FAQ states donators get "5h instead of 2h", while `User#maximum_reservation_length` grants 10 hours to admins and donators versus 2 hours otherwise, and `#reservation_extension_time` grants 1 hour versus 20 minutes.

## Product Principles

1. **Time-to-connect is the product.** Every surface is judged by whether it shortens the path from arriving to pasting a connect string into Discord.
2. **Repeat use beats first use, without abandoning first use.** Optimize the booking flow for someone who has done this a hundred times; let the home page and FAQ carry the newcomer.
3. **Density is a feature, not a debt.** This audience reads server lists, log lines, and RCON output. Do not trade information for whitespace.
4. **Free stays free; donation is invited, never extracted.** Perks are additive. Premium and sponsor visibility stay prominent because they fund the service, not because they gate it.
5. **Four regions, one product.** Nothing may assume a single region, and switching regions must stay one obvious move.

## Accessibility & Inclusion

No product-specific accessibility standard has been established. General web accessibility applies; the dark-only constraint means contrast must be verified against dark surfaces rather than assumed.
