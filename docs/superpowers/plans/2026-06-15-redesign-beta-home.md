# serveme.tf Redesign Beta — Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Direction A ("Command") redesign of the serveme.tf **Home page** behind an opt-in `/beta` cookie, using a layout-scoped Tailwind bundle, without altering the live site for non-opted-in users.

**Architecture:** A cookie (`ui_v2`) plus a `REDESIGNED_ACTIONS` allow-list drive Rails template **variants** (`request.variant = :v2`) and a dedicated `application_v2` layout. Tailwind is built by the no-Node `tailwindcss-ruby` CLI into `app/assets/builds/v2.css`, linked **only** in the v2 layout so its Preflight reset never touches Bootstrap pages. The redesigned `pages#welcome` reuses all existing data (`@users_reservations`, `@users_games`, `Order.monthly_*`, `ServerForUserFinder`).

**Tech Stack:** Ruby on Rails 8.1, Haml, Sprockets, RSpec, Tailwind CSS v4 (via `tailwindcss-ruby`), Turbo/Stimulus, self-hosted Archivo + JetBrains Mono.

**Spec:** `docs/superpowers/specs/2026-06-15-redesign-beta-design.md`

---

## File Structure

**Created:**
- `app/controllers/concerns/beta_ui.rb` — cookie/variant/layout gating concern + `beta_ui?` helper + `REDESIGNED_ACTIONS`.
- `app/controllers/beta_controller.rb` — `/beta` explainer + enable/disable cookie actions.
- `app/views/beta/show.html.haml` — explainer page with the opt-in / opt-out buttons (renders in the normal Bootstrap layout).
- `app/views/layouts/application_v2.html.haml` — v2 layout: links `v2.css`, renders the v2 nav + a "beta" banner.
- `app/views/shared/_navigation.html+v2.haml` — restyled top nav (same links/structure as `_navigation.html.haml`).
- `app/views/pages/welcome.html+v2.haml` — redesigned Home.
- `app/views/pages/_v2_hero.html.haml` — hero band + three primary actions.
- `app/views/pages/_v2_availability.html.haml` — availability gauge card.
- `app/views/pages/_v2_donation.html.haml` — donation row + striped progress bar.
- `app/views/reservations/_users_games.html+v2.haml` — "Reservations you played in" table, v2-styled.
- `app/views/reservations/_users_reservations.html+v2.haml` — "Your most recent reservations" table, v2-styled.
- `app/assets/stylesheets/v2.tailwind.css` — Tailwind input: `@import`, `@theme` tokens, `@font-face`, `@source`.
- `public/fonts/v2/*.woff2` — self-hosted Archivo + JetBrains Mono.
- `lib/tasks/tailwind_v2.rake` — build task hooked into `assets:precompile`.
- `spec/controllers/beta_controller_spec.rb` — enable/disable/show specs.
- New describe blocks in `spec/controllers/pages_controller_spec.rb` — variant gating + caching.

**Modified:**
- `Gemfile` — add `tailwindcss-ruby`.
- `app/controllers/application_controller.rb` — `include BetaUi`, `before_action :set_beta_variant`, `layout :resolve_layout`.
- `app/controllers/pages_controller.rb` — variant-aware `caches_action` cache key for `welcome`.
- `app/assets/config/manifest.js` — link `builds/v2.css`.
- `config/routes.rb` — `/beta` routes.
- `app/assets/builds/tailwind.css` — delete the orphaned stale file.

---

## Task 1: Branch + delete the orphaned Tailwind file

**Files:**
- Delete: `app/assets/builds/tailwind.css`

- [ ] **Step 1: Create the feature branch**

Run:
```bash
cd ~/Projects/fakkelbrigade/serveme
git checkout -b redesign-beta-home
```
Expected: `Switched to a new branch 'redesign-beta-home'`

- [ ] **Step 2: Confirm the stale file is unreferenced, then delete it**

Run:
```bash
grep -rn "builds/tailwind" app config || echo "NO REFERENCES"
git rm app/assets/builds/tailwind.css
```
Expected: `NO REFERENCES`, then the file is staged for deletion. (It is Tailwind v3.0.5, not in the Gemfile, not in `manifest.js`.)

- [ ] **Step 3: Commit**

```bash
git commit -m "Remove orphaned stale tailwind.css build artifact"
```

---

## Task 2: Add the Tailwind build pipeline (no Node)

**Files:**
- Modify: `Gemfile`
- Create: `app/assets/stylesheets/v2.tailwind.css`
- Create: `lib/tasks/tailwind_v2.rake`
- Modify: `app/assets/config/manifest.js`

- [ ] **Step 1: Add the gem**

Add to `Gemfile`, directly after the existing `gem "sass-rails"` line (around line 65):
```ruby
# Scoped Tailwind v4 build for the opt-in redesign (vendors the standalone CLI, no Node).
gem "tailwindcss-ruby", "~> 4.0"
```

- [ ] **Step 2: Install**

Run:
```bash
bundle install
```
Expected: `Bundle complete`. Note the resolved `tailwindcss-ruby` version.

- [ ] **Step 3: Create the Tailwind input file**

Create `app/assets/stylesheets/v2.tailwind.css`:
```css
@import "tailwindcss";

/* Only scan the redesigned templates + JS so utility generation stays scoped. */
@source "../../views";
@source "../../javascript";

/* ---- Direction A "Command" design tokens ---- */
@theme {
  --color-accent: #f2742c;
  --color-accent-light: #f2a36c;
  --color-cta-from: #f98c43;
  --color-cta-to: #ee5f29;
  --color-page: #0b0c0e;
  --color-hero: #0e1014;
  --color-panel: #101216;
  --color-panel-2: #121419;
  --color-elevated: #16191f;
  --color-inset: #0c0e12;
  --color-inset-2: #08090b;
  --color-ink: #e7e9ee;
  --color-muted: #9aa0ab;
  --color-faint: #6b7280;
  --color-success: #3ecf8e;
  --color-success-text: #5fdca0;
  --color-info: #4aa3df;
  --color-gold: #f2c14e;
  --color-danger: #e54834;

  --radius-card: 16px;
  --radius-btn: 10px;
  --radius-pill: 24px;

  --font-display: "Archivo", ui-sans-serif, system-ui, sans-serif;
  --font-sans: "Archivo", ui-sans-serif, system-ui, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, monospace;
}

/* Fonts are added in Task 3 (this file is appended to there). */
```

- [ ] **Step 4: Create the build rake task**

Create `lib/tasks/tailwind_v2.rake`:
```ruby
# frozen_string_literal: true

require "tailwindcss/ruby"

namespace :tailwind_v2 do
  input  = Rails.root.join("app/assets/stylesheets/v2.tailwind.css").to_s
  output = Rails.root.join("app/assets/builds/v2.css").to_s

  desc "Build the scoped v2 Tailwind bundle"
  task :build do
    command = [Tailwindcss::Ruby.executable, "-i", input, "-o", output, "--minify"]
    puts "Building v2.css: #{command.join(' ')}"
    system(*command, exception: true)
  end

  desc "Watch and rebuild the v2 Tailwind bundle"
  task :watch do
    command = [Tailwindcss::Ruby.executable, "-i", input, "-o", output, "--watch"]
    system(*command, exception: true)
  end
end

# Ensure the bundle is built before assets are precompiled (Kamal deploy).
if Rake::Task.task_defined?("assets:precompile")
  Rake::Task["assets:precompile"].enhance(["tailwind_v2:build"])
end
```

- [ ] **Step 5: Link the build output through Sprockets**

Add this line to `app/assets/config/manifest.js` (after the existing `link themes/slate.css` line):
```js
//= link builds/v2.css
```

- [ ] **Step 6: Build and verify output exists and is non-empty**

Run:
```bash
bundle exec rake tailwind_v2:build
test -s app/assets/builds/v2.css && echo "BUILD OK ($(wc -c < app/assets/builds/v2.css) bytes)"
```
Expected: `BUILD OK` with a non-zero byte count (Preflight + base utilities present).

- [ ] **Step 7: Ignore the generated bundle**

Append to `.gitignore`:
```
/app/assets/builds/v2.css
```
(The bundle is rebuilt on every precompile; do not commit it.)

- [ ] **Step 8: Commit**

```bash
git add Gemfile Gemfile.lock app/assets/stylesheets/v2.tailwind.css lib/tasks/tailwind_v2.rake app/assets/config/manifest.js .gitignore
git commit -m "Add scoped v2 Tailwind build pipeline (tailwindcss-ruby)"
```

---

## Task 3: Self-host the fonts

**Files:**
- Create: `public/fonts/v2/archivo.woff2`, `public/fonts/v2/jetbrains-mono.woff2`
- Modify: `app/assets/stylesheets/v2.tailwind.css`

- [ ] **Step 1: Fetch the variable woff2 files**

Run (downloads the variable fonts directly from the Google Fonts CDN):
```bash
mkdir -p public/fonts/v2
curl -fsSL "https://fonts.gstatic.com/s/archivo/v19/k3k6o8UDI-1M0wlSV9XAw6lQkqWY8Q82sJaRE-NWIDdgffTTNDNZ9xdp.woff2" -o public/fonts/v2/archivo.woff2
curl -fsSL "https://fonts.gstatic.com/s/jetbrainsmono/v18/tDba2o-flEEny0FZhsfKu5WU4zr3E_BX0PnT8RD8yKxjPVmUsaaDhw.woff2" -o public/fonts/v2/jetbrains-mono.woff2
ls -l public/fonts/v2/
```
Expected: two non-empty `.woff2` files.
> If the CDN URLs have rotated and return 404, fetch the current URLs from `https://fonts.googleapis.com/css2?family=Archivo:wght@400..900&family=JetBrains+Mono:wght@400..700&display=swap` (the `src: url(...)` entries) and re-run.

- [ ] **Step 2: Add @font-face to the Tailwind input**

Append to `app/assets/stylesheets/v2.tailwind.css`:
```css
@font-face {
  font-family: "Archivo";
  font-style: normal;
  font-weight: 100 900;
  font-display: swap;
  src: url("/fonts/v2/archivo.woff2") format("woff2");
}
@font-face {
  font-family: "JetBrains Mono";
  font-style: normal;
  font-weight: 100 800;
  font-display: swap;
  src: url("/fonts/v2/jetbrains-mono.woff2") format("woff2");
}
```
(Served from `public/`, the URLs are stable and bypass Sprockets digesting.)

- [ ] **Step 3: Rebuild and verify the font face is in the bundle**

Run:
```bash
bundle exec rake tailwind_v2:build
grep -c "Archivo" app/assets/builds/v2.css
```
Expected: a count `>= 1`.

- [ ] **Step 4: Commit**

```bash
git add public/fonts/v2 app/assets/stylesheets/v2.tailwind.css
git commit -m "Self-host Archivo + JetBrains Mono for the redesign"
```

---

## Task 4: Beta gating concern (TDD)

This is the architectural core. We build it test-first against an anonymous controller so it has no view dependencies.

**Files:**
- Create: `app/controllers/concerns/beta_ui.rb`
- Modify: `app/controllers/application_controller.rb:4-13`
- Test: `spec/controllers/beta_ui_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/controllers/beta_ui_spec.rb`:
```ruby
# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe BetaUi, type: :controller do
  controller(ApplicationController) do
    # Skip filters that would redirect/short-circuit the bare test action.
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :redirect_if_country_banned, raise: false
    skip_before_action :store_current_location, raise: false
    skip_before_action :authorize_mini_profiler, raise: false

    def index
      render plain: "ok"
    end
  end

  before do
    routes.draw { get "index" => "anonymous#index" }
  end

  context "without the ui_v2 cookie" do
    it "does not enable the v2 variant or layout" do
      get :index
      expect(controller.send(:beta_ui?)).to be false
      expect(controller.send(:resolve_layout)).to be_nil
      expect(request.variant).not_to include(:v2)
    end
  end

  context "with the ui_v2 cookie on a non-redesigned action" do
    it "reports beta but does not switch variant/layout (action not allow-listed)" do
      request.cookies["ui_v2"] = "true"
      get :index
      expect(controller.send(:beta_ui?)).to be true
      expect(controller.send(:resolve_layout)).to be_nil
      expect(request.variant).not_to include(:v2)
    end
  end

  context "with the ui_v2 cookie on a redesigned action" do
    before do
      stub_const("BetaUi::REDESIGNED_ACTIONS", { "anonymous" => %w[index] })
    end

    it "enables the v2 variant and the v2 layout" do
      request.cookies["ui_v2"] = "true"
      get :index
      expect(request.variant).to include(:v2)
      expect(controller.send(:resolve_layout)).to eq("application_v2")
    end
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```bash
bundle exec rspec spec/controllers/beta_ui_spec.rb
```
Expected: FAIL — `uninitialized constant BetaUi`.

- [ ] **Step 3: Create the concern**

Create `app/controllers/concerns/beta_ui.rb`:
```ruby
# typed: false
# frozen_string_literal: true

# Opt-in redesign gating. A user sets the `ui_v2` cookie via /beta; when set AND
# the current controller#action is on the allow-list below, we render the `:v2`
# template variant inside the `application_v2` layout. Everything else is untouched,
# so non-opted-in users (and not-yet-redesigned pages) see the current site.
module BetaUi
  extend ActiveSupport::Concern

  REDESIGNED_ACTIONS = {
    "pages" => %w[welcome],
  }.freeze

  included do
    before_action :set_beta_variant
    helper_method :beta_ui?
  end

  private

  def beta_ui?
    cookies[:ui_v2] == "true"
  end

  def beta_redesigned_action?
    REDESIGNED_ACTIONS[controller_name]&.include?(action_name) || false
  end

  def beta_active?
    beta_ui? && beta_redesigned_action?
  end

  def set_beta_variant
    request.variant = :v2 if beta_active?
  end

  def resolve_layout
    beta_active? ? "application_v2" : nil
  end
end
```

- [ ] **Step 4: Wire it into ApplicationController**

In `app/controllers/application_controller.rb`, add the include and the layout resolver. After the existing `include ApplicationHelper` (line 6) add:
```ruby
  include BetaUi
```
And immediately after `protect_from_forgery` (line 8) add:
```ruby
  layout :resolve_layout
```

- [ ] **Step 5: Run the test to verify it passes**

Run:
```bash
bundle exec rspec spec/controllers/beta_ui_spec.rb
```
Expected: PASS (3 examples).

- [ ] **Step 6: Verify the existing suite still renders the default layout**

Run:
```bash
bundle exec rspec spec/controllers/pages_controller_spec.rb
```
Expected: PASS (no cookie → `resolve_layout` returns nil → normal layout; zero regression).

- [ ] **Step 7: Commit**

```bash
git add app/controllers/concerns/beta_ui.rb app/controllers/application_controller.rb spec/controllers/beta_ui_spec.rb
git commit -m "Add opt-in redesign gating concern (cookie + variant + layout)"
```

---

## Task 5: /beta opt-in routes + controller (TDD)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/beta_controller.rb`
- Test: `spec/controllers/beta_controller_spec.rb`

- [ ] **Step 1: Add routes**

In `config/routes.rb`, just above the `root to: "pages#welcome"` line (line 281), add:
```ruby
  get    "/beta",         to: "beta#show",    as: "beta"
  post   "/beta/enable",  to: "beta#enable",  as: "beta_enable"
  delete "/beta/disable", to: "beta#disable", as: "beta_disable"
```

- [ ] **Step 2: Write the failing test**

Create `spec/controllers/beta_controller_spec.rb`:
```ruby
# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe BetaController do
  describe "#show" do
    it "renders for logged-out users" do
      get :show
      expect(response).to be_successful
    end
  end

  describe "#enable" do
    it "sets the ui_v2 cookie and redirects to root" do
      post :enable
      expect(response.cookies["ui_v2"]).to eq("true")
      expect(response).to redirect_to(root_path)
    end
  end

  describe "#disable" do
    it "clears the ui_v2 cookie and redirects to root" do
      request.cookies["ui_v2"] = "true"
      delete :disable
      expect(response.cookies["ui_v2"]).to be_nil
      expect(response).to redirect_to(root_path)
    end
  end
end
```

- [ ] **Step 3: Run it to verify it fails**

Run:
```bash
bundle exec rspec spec/controllers/beta_controller_spec.rb
```
Expected: FAIL — `uninitialized constant BetaController`.

- [ ] **Step 4: Create the controller**

Create `app/controllers/beta_controller.rb`:
```ruby
# typed: false
# frozen_string_literal: true

class BetaController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :redirect_if_country_banned

  def show; end

  def enable
    cookies[:ui_v2] = { value: "true", expires: 1.year, same_site: :lax }
    redirect_to root_path
  end

  def disable
    cookies.delete(:ui_v2)
    redirect_to root_path
  end
end
```

- [ ] **Step 5: Create a minimal explainer view (normal layout)**

Create `app/views/beta/show.html.haml`:
```haml
- content_for :title, "Try the redesign"
.row
  .col-md-8.offset-md-2
    %h1 Try the new serveme.tf
    %p.lead
      We're testing a refreshed look. It's opt-in and only changes your view —
      everyone else keeps the current site. You can switch back any time.
    - if beta_ui?
      = button_to "Switch back to the classic look", beta_disable_path, method: :delete, class: "btn btn-lg btn-secondary"
    - else
      = button_to "Try the new look", beta_enable_path, method: :post, class: "btn btn-lg btn-primary"
```

- [ ] **Step 6: Run the test to verify it passes**

Run:
```bash
bundle exec rspec spec/controllers/beta_controller_spec.rb
```
Expected: PASS (3 examples).

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/beta_controller.rb app/views/beta/show.html.haml spec/controllers/beta_controller_spec.rb
git commit -m "Add /beta opt-in page and enable/disable toggle"
```

---

## Haml + Tailwind convention (applies to Tasks 6, 8–11)

**Tailwind utility classes MUST go in a `{class: "..."}` attribute hash, never in Haml dot-shorthand.** Haml's `.foo` shorthand only accepts `[A-Za-z0-9_-]`, but Tailwind classes routinely contain `/` (`border-white/10`), `:` (`hover:bg-white/5`, `md:grid-cols-2`), `[ ]` (`max-w-[1280px]`), and `.` (`leading-[0.98]`) — all of which break Haml parsing or are misread as object references. So write:

```haml
%div{class: "mx-auto max-w-[1280px] px-[26px]"}
```

not `.mx-auto.max-w-[1280px].px-[26px]`. Simple semantic element tags (`%h1`, `%p`, `%table`, `%tr`, `%td`) are fine as bare tags with their utilities in the `{class:}` hash. All snippets below already follow this.

## Task 6: v2 layout + navigation

**Files:**
- Create: `app/views/layouts/application_v2.html.haml`
- Create: `app/views/shared/_navigation.html+v2.haml`

- [ ] **Step 1: Create the v2 layout**

Create `app/views/layouts/application_v2.html.haml` (mirrors `application.html.haml` but links only `v2.css`, no Bootstrap themes):
```haml
!!!
%html
  %head
    - subtitle = content_for(:title) || "free TF2 server reservations"
    %title #{SITE_HOST} - #{subtitle}
    = stylesheet_link_tag "v2", media: "all"
    = content_for(:stripe)
    = javascript_importmap_tags("application")
    = javascript_include_tag "serveme"
    = csrf_meta_tags
    %meta{name: "time-zone", content: Time.zone.tzinfo.identifier}
    = render 'shared/analytics'
    %meta{name: "viewport", content: "width=device-width, initial-scale=1.0, shrink-to-fit=no"}
    %meta{name: "description", content: content_for(:meta_description) || "Free TF2 servers, ready for action in 60 seconds!"}
    = content_for(:head)
  %body{class: "bg-page text-ink font-sans antialiased"}
    = link_to "Skip to content", "#main", class: "sr-only"
    = render 'shared/navigation'
    %div{class: "mx-auto max-w-[1280px] px-[26px]"}
      %main#main{role: "main"}
        - if notice || alert
          %div{class: "my-4"}
            = render 'shared/flash'
        = yield
      = render 'shared/timezone'
    %div{class: "fixed bottom-4 right-4 z-50"}
      = link_to "Beta · switch back", beta_disable_path, data: { turbo_method: :delete }, class: "rounded-pill bg-elevated text-muted text-sm px-4 py-2 border border-white/10 hover:text-ink"
```

- [ ] **Step 2: Create the v2 navigation partial**

Create `app/views/shared/_navigation.html+v2.haml`. Keep the same links as `_navigation.html.haml` (Reservations / Community / Maps / Premium / Settings / Admin, Discord/GitHub, user pill) but styled with Tailwind. Minimal first version:
```haml
%nav{class: "h-[60px] bg-[#111317] border-b border-white/10 flex items-center px-[26px] gap-6"}
  = link_to SITE_HOST, root_url, class: "font-display font-extrabold text-ink tracking-tight"
  %div{class: "flex items-center gap-5 text-sm text-muted"}
    = link_to "Reservations", reservations_path, class: "hover:text-ink"
    - if defined?(maps_path)
      = link_to "Maps", maps_path, class: "hover:text-ink"
    = link_to "★ Premium", donate_path, class: "text-gold hover:brightness-110"
    - if current_user
      = link_to "Settings", edit_user_path(current_user), class: "hover:text-ink"
  %div{class: "ml-auto flex items-center gap-3"}
    = link_to "Discord", discord_invite_path, class: "text-info hover:brightness-110"
    - if current_user
      %span{class: "rounded-pill bg-elevated px-3 py-1 text-sm"}
        = current_user.nickname
        - if current_user.donator?
          %span{class: "text-gold"} ★
    - else
      = link_to "Sign in", "/login", class: "text-accent-light hover:text-accent"
```
> Verify the exact path helpers against `_navigation.html.haml` while implementing; reuse whatever it uses (some links are conditional on `current_user`/admin). Replace any helper that doesn't exist (e.g. confirm `maps_path`, the login path) with the one the original nav uses.

- [ ] **Step 3: Commit**

```bash
git add app/views/layouts/application_v2.html.haml app/views/shared/_navigation.html+v2.haml
git commit -m "Add v2 layout and navigation for the redesign"
```

---

## Task 7: Render welcome through v2 + fix the action cache (TDD)

**Files:**
- Create: `app/views/pages/welcome.html+v2.haml` (placeholder first; filled in Tasks 8-10)
- Modify: `app/controllers/pages_controller.rb:8`
- Test: add to `spec/controllers/pages_controller_spec.rb`

- [ ] **Step 1: Create a minimal v2 welcome template**

Create `app/views/pages/welcome.html+v2.haml`:
```haml
%h1{class: "font-display text-4xl font-extrabold"}
  Your TF2 server, ready in
  %span{class: "text-accent"} 60 seconds.
%p{class: "text-muted"} The redesigned home is under construction.
```

- [ ] **Step 2: Write the failing variant + cache tests**

Add to `spec/controllers/pages_controller_spec.rb` (new describe block at the end, before the final `end`):
```ruby
  describe "#welcome redesign gating" do
    it "renders the v2 layout + template when opted in" do
      request.cookies["ui_v2"] = "true"
      get :welcome
      expect(response).to render_template("layouts/application_v2")
      expect(response).to render_template("pages/welcome")
    end

    it "renders the default layout when not opted in" do
      cookies.delete(:ui_v2) if respond_to?(:cookies)
      get :welcome
      expect(response).not_to render_template("layouts/application_v2")
    end
  end

  describe "#welcome caching" do
    around do |example|
      caching = ActionController::Base.perform_caching
      previous_store = Rails.cache
      ActionController::Base.perform_caching = true
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      ActionController::Base.perform_caching = caching
      Rails.cache = previous_store
    end

    it "does not serve the cached classic home to opted-in logged-out users" do
      sign_out @user
      get :welcome          # primes the classic cache entry
      request.cookies["ui_v2"] = "true"
      get :welcome          # different cache key -> miss -> renders v2
      expect(response).to render_template("layouts/application_v2")
    end
  end
```
> `caches_action` is a no-op unless `perform_caching` is on, so the `around` hook turns it on with a throwaway `MemoryStore`. Without the cache-key fix, the second request serves the cached classic body and never renders `application_v2` — so this assertion is what fails first. `render_template` requires `rails-controller-testing` (already in the Gemfile). If `sign_out` is unavailable here, set up a logged-out context the way other specs in the file do.

- [ ] **Step 3: Run it to verify it fails**

Run:
```bash
bundle exec rspec spec/controllers/pages_controller_spec.rb -e "redesign gating" -e "caching"
```
Expected: FAIL — caching test serves identical cached HTML (the bug), and/or layout assertion fails.

- [ ] **Step 4: Fix the action cache key**

In `app/controllers/pages_controller.rb`, change the `caches_action :welcome` line (line 8) from:
```ruby
  caches_action :welcome, cache_path: -> { "welcome_#{Time.zone}" }, unless: -> { current_user }, expires_in: 30.seconds
```
to:
```ruby
  caches_action :welcome, cache_path: -> { "welcome_#{Time.zone}_#{cookies[:ui_v2]}" }, unless: -> { current_user }, expires_in: 30.seconds
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```bash
bundle exec rspec spec/controllers/pages_controller_spec.rb -e "redesign gating" -e "caching"
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/views/pages/welcome.html+v2.haml app/controllers/pages_controller.rb spec/controllers/pages_controller_spec.rb
git commit -m "Render welcome via v2 variant and vary action cache by ui_v2"
```

---

## Task 8: Home hero + three primary actions

**Files:**
- Create: `app/views/pages/_v2_hero.html.haml`
- Modify: `app/views/pages/welcome.html+v2.haml`

- [ ] **Step 1: Build the hero partial**

Create `app/views/pages/_v2_hero.html.haml` (mirrors the three actions from the existing `welcome.html.haml` exactly, restyled):
```haml
%div{class: "relative overflow-hidden bg-hero rounded-card my-6 px-8 py-10"}
  %div{class: "grid gap-8 md:grid-cols-[1.4fr_1fr]"}
    %div{class: "flex flex-col gap-5"}
      %span{class: "inline-flex items-center gap-2 self-start rounded-pill bg-elevated px-3 py-1 text-sm text-success-text"}
        %span{class: "inline-block w-2 h-2 rounded-full bg-success animate-pulse"}
        Servers live right now
      %h1{class: "font-display text-5xl font-black leading-[0.98] tracking-tight text-ink"}
        Your TF2 server, ready in
        %span{class: "text-accent"} 60 seconds.
      %p{class: "text-muted max-w-prose"} The easiest way to get a TF2 server.
      %div{class: "flex flex-wrap gap-3"}
        = link_to new_reservation_path, class: "rounded-btn px-5 py-3 font-semibold text-white", style: "background: linear-gradient(135deg,#f98c43,#ee5f29); box-shadow:0 8px 26px rgba(238,95,41,.34)" do
          Get server
        = link_to i_am_feeling_lucky_reservations_path, data: { turbo_method: :post }, class: "rounded-btn px-5 py-3 font-semibold text-accent-light border border-accent/60 hover:border-accent" do
          1-click server
        - if current_user&.can_use_cloud_servers?
          = link_to(current_user.cloud_server_access? ? new_cloud_reservation_path : cloud_info_path, class: "rounded-btn px-5 py-3 font-semibold text-info border border-info/50 hover:border-info") do
            Cloud server
      %p{class: "text-sm text-muted"}
        %strong{class: "text-accent-light"} New:
        = link_to "Add our bot to your Discord server", discord_invite_path, class: "text-accent-light hover:text-accent"
    = render 'pages/v2_availability'
```

- [ ] **Step 2: Use the hero in welcome**

Replace the entire contents of `app/views/pages/welcome.html+v2.haml` with:
```haml
= render 'pages/v2_hero'
```

- [ ] **Step 3: Verify it renders without error**

Run:
```bash
bundle exec rspec spec/controllers/pages_controller_spec.rb -e "redesign gating"
```
Expected: PASS (template still renders; `v2_availability` partial is created in the next task — create it as an empty file first if running this step in isolation: `touch app/views/pages/_v2_availability.html.haml`).

- [ ] **Step 4: Commit**

```bash
git add app/views/pages/_v2_hero.html.haml app/views/pages/welcome.html+v2.haml
git commit -m "Add redesign hero with three primary actions"
```

---

## Task 9: Availability gauge card

**Files:**
- Create: `app/views/pages/_v2_availability.html.haml`

- [ ] **Step 1: Build the availability partial**

Create `app/views/pages/_v2_availability.html.haml` (reuses the same finders as `reservations/_available_servers.html.haml`):
```haml
- window_start = Time.current
- window_end = 1.hour.from_now
- total = Server.active.not_cloud.count + docker_hosts_total_slots
- if current_user&.donator?
  - available = ServerForUserFinder.new(current_user, window_start, window_end).servers.size + docker_hosts_available_during(window_start, window_end)
- elsif current_user
  - free_limit = SiteSetting.free_server_limit
  - available = free_limit ? [free_limit - SiteSetting.free_user_reservation_count(window_start, window_end), 0].max : ServerForUserFinder.new(current_user, window_start, window_end).servers.size + docker_hosts_available_during(window_start, window_end)
  - total = free_limit || total
- else
  - available = 0
- pct = total.positive? ? ((available.to_f / total) * 100).round : 0
%div{class: "bg-panel rounded-card p-6 flex flex-col gap-4 border border-white/10"}
  %div{class: "text-muted text-sm"} Servers available
  %div{class: "font-mono text-faint text-sm"}
    = "#{I18n.l(window_start, format: :time_without_seconds)} – #{I18n.l(window_end, format: :time_without_seconds)}"
  %div{class: "font-mono text-4xl font-bold text-ink"}
    = "#{available} / #{total}"
  %div{class: "text-success-text text-sm"} For you, right now
  %div{class: "h-2 rounded-full bg-inset overflow-hidden"}
    %div{class: "h-full bg-success", style: "width: #{pct}%"}
```

- [ ] **Step 2: Verify the home renders end-to-end as v2**

Run:
```bash
bundle exec rspec spec/controllers/pages_controller_spec.rb -e "redesign gating"
```
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add app/views/pages/_v2_availability.html.haml
git commit -m "Add availability gauge card to redesign home"
```

---

## Task 10: Donation row with striped progress bar

**Files:**
- Create: `app/views/pages/_v2_donation.html.haml`
- Modify: `app/views/pages/welcome.html+v2.haml`

- [ ] **Step 1: Build the donation partial**

Create `app/views/pages/_v2_donation.html.haml` (reuses `Order.monthly_*`, same data as `shared/_donation_target.html.haml`):
```haml
- pct = Order.monthly_goal_percentage.round
- width = [pct, 100].min
- unit = I18n.t('number.currency.format.unit')
%div{class: "bg-panel rounded-card p-6 my-6 flex flex-col gap-3 border border-white/10"}
  %div{class: "flex items-center justify-between flex-wrap gap-3"}
    %div
      %strong{class: "text-ink"} Monthly server bills (#{unit}#{Order.monthly_goal.round})
      %p{class: "text-sm text-faint"} Split between providers by playtime · 2 keys/month
    = link_to "Donate now", donate_path, class: "rounded-btn px-4 py-2 font-semibold text-white", style: "background: linear-gradient(135deg,#f98c43,#ee5f29)"
  %div{class: "relative h-5 rounded-full bg-inset overflow-hidden"}
    %div{class: "h-full rounded-full transition-all v2-stripes", style: "width: #{width}%"}
    %span{class: "absolute inset-0 flex items-center justify-center text-xs font-mono text-white"}
      = "#{unit}#{Order.monthly_total.round} / #{unit}#{Order.monthly_goal.round}"
```

- [ ] **Step 2: Add the animated stripe utility to the Tailwind input**

Append to `app/assets/stylesheets/v2.tailwind.css`:
```css
@utility v2-stripes {
  background-color: var(--color-accent);
  background-image: repeating-linear-gradient(
    135deg,
    rgba(255, 255, 255, 0.18) 0 12px,
    rgba(255, 255, 255, 0) 12px 24px
  );
  background-size: 48px 48px;
  animation: v2-stripe-move 1.1s linear infinite;
}
@keyframes v2-stripe-move {
  from { background-position: 0 0; }
  to   { background-position: 48px 0; }
}
```

- [ ] **Step 3: Add the donation row to welcome**

Update `app/views/pages/welcome.html+v2.haml`:
```haml
= render 'pages/v2_hero'
= render 'pages/v2_donation'
```

- [ ] **Step 4: Rebuild Tailwind and verify the stripe utility is present**

Run:
```bash
bundle exec rake tailwind_v2:build
grep -c "v2-stripe-move" app/assets/builds/v2.css
```
Expected: count `>= 1`.

- [ ] **Step 5: Commit**

```bash
git add app/views/pages/_v2_donation.html.haml app/views/pages/welcome.html+v2.haml app/assets/stylesheets/v2.tailwind.css
git commit -m "Add donation row with animated striped progress bar"
```

---

## Task 11: The two reservation tables (v2 variants)

**Files:**
- Create: `app/views/reservations/_users_games.html+v2.haml`
- Create: `app/views/reservations/_users_reservations.html+v2.haml`
- Modify: `app/views/pages/welcome.html+v2.haml`

- [ ] **Step 1: Build the "played in" table variant**

Create `app/views/reservations/_users_games.html+v2.haml` (same data/logic as `_users_games.html.haml`, restyled; reuses the existing flag sprite + zip/log link partials):
```haml
%div{class: "overflow-x-auto bg-panel rounded-card border border-white/10"}
  %table{class: "w-full text-sm"}
    %thead{class: "text-faint text-left"}
      %tr
        %th{class: "px-4 py-3"} Server
        %th{class: "px-4 py-3"} From
        %th{class: "px-4 py-3"} Until
        %th{class: "px-4 py-3"} Reserved by
        %th{class: "px-4 py-3"} Logs/demos
    %tbody
      - @users_games.each do |reservation|
        - server = reservation.server.decorate
        %tr{class: "border-t border-white/5 hover:bg-white/5"}
          %td{class: "px-4 py-3 text-ink"}= "#{server.flag} #{server.name}"
          %td{class: "px-4 py-3 font-mono text-muted"}= I18n.l(reservation.starts_at, format: :short)
          %td{class: "px-4 py-3 font-mono text-muted"}= I18n.l(reservation.ends_at, format: :short)
          %td{class: "px-4 py-3 text-muted"}= reservation.user.nickname
          %td{class: "px-4 py-3"}
            - if reservation.younger_than_cleanup_age? || reservation.zipfile.attached?
              = render 'reservations/zip_file_link', reservation: reservation
              - if reservation.user == current_user || current_admin
                = link_to "logs.tf", reservation_log_uploads_path(reservation), class: "text-info hover:brightness-110"
            - else
              = link_to "logs.tf", reservation.logs_tf_url, class: "text-info hover:brightness-110"
```
> Use whatever flag helper the existing flag system exposes on the decorated server. If `server.flag` doesn't exist, check `app/decorators/server_decorator.rb` and the `_flags.css.scss` sprite usage in the current tables, and render the flag `%span.flags` the same way the classic site does.

- [ ] **Step 2: Build the "recent" table variant**

Create `app/views/reservations/_users_reservations.html+v2.haml`:
```haml
%div{class: "overflow-x-auto bg-panel rounded-card border border-white/10"}
  %table{class: "w-full text-sm"}
    %thead{class: "text-faint text-left"}
      %tr
        %th{class: "px-4 py-3"} Server
        %th{class: "px-4 py-3"} From
        %th{class: "px-4 py-3"} Until
        %th{class: "px-4 py-3"} Actions
    %tbody
      - @users_reservations.each do |reservation|
        - reservation = reservation.decorate
        %tr{class: "border-t border-white/5 hover:bg-white/5"}
          %td{class: "px-4 py-3 text-ink"}= reservation.server_name
          %td{class: "px-4 py-3 font-mono text-muted"}= I18n.l(reservation.starts_at, format: :short)
          %td{class: "px-4 py-3 font-mono text-muted"}= I18n.l(reservation.ends_at, format: :short)
          %td{class: "px-4 py-3"}= render 'reservations/actions', reservation: reservation
```

- [ ] **Step 3: Add the tables to welcome**

Update `app/views/pages/welcome.html+v2.haml`:
```haml
= render 'pages/v2_hero'
= render 'pages/v2_donation'
- if @users_games&.any?
  %h3{class: "font-display text-xl font-bold text-ink mt-8 mb-3"} Reservations you played in
  = render 'reservations/users_games'
- if @users_reservations&.any?
  %h3{class: "font-display text-xl font-bold text-ink mt-8 mb-3"} Your most recent reservations
  = render 'reservations/users_reservations'
```
(`render 'reservations/users_games'` resolves to the `+v2` partial automatically under the `:v2` variant.)

- [ ] **Step 4: Verify it renders for a logged-in user with reservations**

Run:
```bash
bundle exec rspec spec/controllers/pages_controller_spec.rb -e "redesign gating"
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/reservations/_users_games.html+v2.haml app/views/reservations/_users_reservations.html+v2.haml app/views/pages/welcome.html+v2.haml
git commit -m "Add v2 reservation tables to redesign home"
```

---

## Task 12: Visual verification with the running app

**Files:** none (manual verification)

- [ ] **Step 1: Build assets and boot the app**

Run:
```bash
bundle exec rake tailwind_v2:build
bin/rails server -p 3000
```
(Keep running; use a second shell or background the process.)

- [ ] **Step 2: Opt in and screenshot the redesigned home**

Use Playwright MCP: navigate to `http://localhost:3000/beta`, click "Try the new look", then navigate to `http://localhost:3000/` and take a screenshot. Compare against the prototype's Direction A Home in `~/Projects/fakkelbrigade/design_handoff_serveme_redesign/Serveme Redesign.dc.html`.

- [ ] **Step 3: Confirm zero regression for non-opted-in users**

Use Playwright MCP: in a fresh context (no cookie), navigate to `http://localhost:3000/` and confirm the classic Bootstrap home renders unchanged. Also visit another page (e.g. `/faq`) **with** the `ui_v2` cookie set and confirm it still renders the classic Bootstrap layout (action not on the allow-list).

- [ ] **Step 4: Note any visual gaps**

Record any spacing/typography deltas vs the prototype as follow-up polish items (use the `polish`/`arrange`/`typeset` design skills in a later pass). Do not block the plan on pixel-perfection.

---

## Task 13: Full test suite + finish

**Files:** none

- [ ] **Step 1: Run the full suite and all checks**

Run:
```bash
script/test -a
```
Expected: RuboCop, Brakeman, RSpec, importmap, Tapioca/Sorbet all green. Fix anything that fails (add Sorbet sigs to new files per repo convention — note `BetaController` and `BetaUi` use `# typed: false` like other controllers; adjust if `script/test` expects stricter).

- [ ] **Step 2: Push the branch and open a PR**

Run:
```bash
git push -u origin redesign-beta-home
gh pr create --title "Redesign beta: opt-in home page (Direction A)" --body "$(cat <<'EOF'
Implements the Direction A redesign of the Home page behind an opt-in `/beta` cookie.

- Cookie + Rails template-variant gating (`BetaUi` concern, `REDESIGNED_ACTIONS` allow-list); default render path unchanged for non-opted-in users.
- Layout-scoped Tailwind v4 bundle (`tailwindcss-ruby`, no Node) linked only in `application_v2`; Preflight cannot reach Bootstrap pages.
- Self-hosted Archivo + JetBrains Mono.
- Redesigned `pages#welcome`: hero + 3 actions, availability gauge, striped donation bar, two reservation tables — all on existing data.
- Action-cache key now varies by `ui_v2` so logged-out beta/non-beta visitors don't share cached HTML.

Spec: `docs/superpowers/specs/2026-06-15-redesign-beta-design.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Deploy is a no-op for users until opt-in**

After merge, deploy via the existing Kamal flow (`deploy` skill) to all four regions. The cookie defaults off, so there is no user-visible change until someone visits `/beta`. `assets:precompile` builds `v2.css` automatically (Task 2 rake hook).

---

## Notes for future iterations (separate plans)

- **Book a server** (`reservations#new`): add `"reservations" => %w[new]` to `REDESIGNED_ACTIONS`, create `new.html+v2.haml` with the four step cards + sticky summary, reuse the reservation form fields.
- **Reservation detail** (`reservations#show`): add `show` to the allow-list, create `show.html+v2.haml` with the connect panel, server controls, live status polling, and countdown.
- Each follows this same gating + CSS mechanism with no new infrastructure.
