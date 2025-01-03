# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t server .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name server server

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.3.6
ARG GLEAM_VERSION=v1.6.3

FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY server/Gemfile server/Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY ./server .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile server/app/ server/lib/

FROM node:20-slim AS client-base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

COPY ./client/package.json ./package.json
COPY ./client/pnpm-lock.yaml ./pnpm-lock.yaml
RUN pnpm install --frozen-lockfile

FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine AS client
WORKDIR /client
COPY ./client .

ARG API_URL=http://localhost:80
ENV API_URL=${API_URL}

COPY --from=client-base node_modules node_modules
RUN chmod +x gen_env.sh && sh gen_env.sh 
RUN gleam run -m lustre/dev build --tailwind-entry=base.css --minify

# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails
COPY --from=client /client /client
COPY --from=client /client/index.html /rails/public/index.html
COPY --from=client /client/priv/static/client.min.mjs /rails/public/priv/static/client.mjs
COPY --from=client /client/priv/static/client.min.css /rails/public/priv/static/client.css

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
