# syntax=docker/dockerfile:1

# Multi-stage build. The runtime image carries no compiler, no Node and no
# JavaScript toolchain: webpack, the Tailwind CLI and the native gem extensions
# all run in the builder and only their output is copied forward.

ARG RUBY_VERSION=3.1.3

# ---------------------------------------------------------------------------
# Builder: gems, packs, stylesheets
# ---------------------------------------------------------------------------
FROM ruby:${RUBY_VERSION}-slim-bullseye AS builder

ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_PATH=/usr/local/bundle

# Debian 11 left its normal mirrors when it went to LTS, and the live
# bullseye-security index now points at packages the pool no longer carries.
# The base image ships a commented snapshot source for exactly this case:
# switching to it pins apt to the archive this image was built from, which is
# both installable and reproducible.
RUN sed -i \
      -e 's|^deb http://deb.debian.org|# deb http://deb.debian.org|' \
      -e 's|^# deb http://snapshot.debian.org|deb http://snapshot.debian.org|' \
      /etc/apt/sources.list

RUN apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Retries=5 update -qq \
    && apt-get install --no-install-recommends -y \
      build-essential \
      ca-certificates \
      curl \
      git \
      gnupg \
      libpq-dev \
      pkg-config \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install --no-install-recommends -y nodejs \
    && npm install --global yarn@1.22.19 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gems first: this layer is invalidated only by a dependency change.
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3 \
    && rm -rf "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY package.json ./
RUN yarn install --frozen-lockfile --check-files || yarn install

COPY . .

# webpack 4 uses an MD4 hash that OpenSSL 3 removed; Node's legacy provider is
# the documented workaround and is confined to this build step.
# SECRET_KEY_BASE is a throwaway: asset compilation boots the app, but the real
# key is supplied at runtime from the environment.
RUN NODE_OPTIONS=--openssl-legacy-provider \
    SECRET_KEY_BASE=precompile_placeholder \
    bundle exec rails assets:precompile \
    && rm -rf node_modules tmp/cache

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
FROM ruby:${RUBY_VERSION}-slim-bullseye AS runtime

ARG TARGETARCH
ARG WKHTMLTOPDF_VERSION=0.12.6.1-3

ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1 \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_PATH=/usr/local/bundle \
    WKHTMLTOPDF_PATH=/usr/local/bin/wkhtmltopdf

# The upstream wkhtmltox package rather than Debian's: it is built against a
# patched Qt and renders without an X server, which is what a background worker
# in a container needs. Debian's build needs xvfb wrapped around every call.
# Debian 11 left its normal mirrors when it went to LTS, and the live
# bullseye-security index now points at packages the pool no longer carries.
# The base image ships a commented snapshot source for exactly this case:
# switching to it pins apt to the archive this image was built from, which is
# both installable and reproducible.
RUN sed -i \
      -e 's|^deb http://deb.debian.org|# deb http://deb.debian.org|' \
      -e 's|^# deb http://snapshot.debian.org|deb http://snapshot.debian.org|' \
      /etc/apt/sources.list

RUN apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Retries=5 update -qq \
    && apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      libpq5 \
      postgresql-client \
      procps \
      tzdata \
      xfonts-75dpi \
      xfonts-base \
      fontconfig \
      libjpeg62-turbo \
      libxext6 \
      libxrender1 \
    && curl -fsSL -o /tmp/wkhtmltox.deb \
       "https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}.bullseye_${TARGETARCH}.deb" \
    && apt-get install --no-install-recommends -y /tmp/wkhtmltox.deb \
    && rm -f /tmp/wkhtmltox.deb \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && wkhtmltopdf --version

RUN groupadd --system --gid 1000 longleaf \
    && useradd --system --uid 1000 --gid longleaf --create-home longleaf

WORKDIR /app

COPY --from=builder --chown=longleaf:longleaf /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=longleaf:longleaf /app /app

# Active Storage's disk service and Rails' own scratch space are the only
# paths the runtime user writes to.
RUN mkdir -p tmp/pids storage log && chown -R longleaf:longleaf tmp storage log

USER longleaf

EXPOSE 3000

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
