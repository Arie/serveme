# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t frontend .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name frontend frontend

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.3
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages. Pre-create dirs that the final-stage COPYs would otherwise materialize with build-time mtimes (BuildKit --link parent-dir reproducibility quirk).
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips  && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    mkdir -p /var/cache/bootsnap /rails/public/assets

# Set production environment. LD_PRELOAD activates jemalloc for the Ruby process.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="libjemalloc.so.2" \
    MALLOC_CONF="dirty_decay_ms:1000,narenas:2,background_thread:true" \
    BOOTSNAP_CACHE_DIR="/var/cache/bootsnap"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config libmaxminddb0 libmaxminddb-dev libpq-dev libyaml-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems. Cache mount on the gem download cache
# preserves *.gem archives across layer invalidations, so a Gemfile
# bump only re-downloads the gems whose versions actually changed.
# NB: target uses Ruby's API version (4.0.x → 4.0.0). Bump to 4.1.x
# means updating the cache path or you'll lose the cache for one build.
COPY Gemfile Gemfile.lock ./
# `bundle config set bin 'bin'` is run inside this cached layer so the resulting /usr/local/bundle/config is stable across code-only rebuilds. Doing it later would mutate /usr/local/bundle every build and break the gems-layer cache.
RUN --mount=type=cache,target=/usr/local/bundle/ruby/4.0.0/cache,sharing=locked \
    bundle config set bin 'bin' && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile && \
    mkdir -p bin && \
    bundle binstubs thruster --force

# Copy application code
COPY . .

# Skip `bootsnap precompile app/ lib/` — churns the code layer for ~200ms boot.

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY.
# Cache mount on tmp/cache covers sprockets manifests + bootsnap caches
# so an app-only edit doesn't redo the full asset pipeline.
#
# Kamal's asset_path: /rails/public/assets in config/deploy.yml owns
# retention across deploys — on the host it extracts public/assets from
# this image, cross-syncs with the previous release, and mounts the
# per-version volume back over public/assets at run time.
RUN --mount=type=cache,target=/rails/tmp/cache,sharing=locked \
    --mount=type=cache,target=/var/cache/bootsnap,sharing=locked \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && \
    sed -i 's/"mtime":"[^"]*"/"mtime":"1970-01-01T00:00:00+00:00"/g' public/assets/.sprockets-manifest-*.json && \
    cd public/assets && \
    OLD=$(ls .sprockets-manifest-*.json) && \
    NEW=".sprockets-manifest-$(sha256sum "$OLD" | cut -c1-32).json" && \
    [ "$OLD" = "$NEW" ] || mv "$OLD" "$NEW" && \
    cd /rails && \
    find public/assets -name '*.gz' | while read gz; do src="${gz%.gz}"; [ -f "$src" ] && gzip -9 -n < "$src" > "$gz"; done && \
    find public/assets -exec touch -d '@0' {} +




# Final stage for app image
FROM base

LABEL service=serveme

# Runtime libraries + tools the app shells out to:
#   libpq5, libmaxminddb0    — Rails DB / GeoIP
#   openssh-client           — `scp` (cloud_server.rb#scp_command), `ssh`, `sftp`
#   zip                      — local_zip_file_creator (Open3.capture3 "zip")
#   ripgrep                  — log_streaming_service.rb shells out to `rg` for search
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libpq5 libmaxminddb0 libyaml-0-2 openssh-client zip ripgrep && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# docker CLI — CloudImageBuildWorker (EU only) shells out to `docker build`
# and `docker push` to rebuild the tf2-cloud-server image, talking to the
# host daemon over a bind-mounted /var/run/docker.sock. CLI binary only,
# no daemon; pinned to the EU host's docker version.
ARG DOCKER_CLI_VERSION=29.4.2
RUN curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz" \
    | tar -xzC /usr/local/bin --strip-components=1 docker/docker

# Final-stage COPYs ordered by churn frequency. --link makes each layer's digest content-addressable so identical sources cache-hit on the registry.
COPY --from=build --link /rails/public/assets /rails/public/assets
COPY --from=build --link "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build --link /var/cache/bootsnap /var/cache/bootsnap
COPY --from=build --link --exclude=public/assets /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
