# This Dockerfile builds the psycopg wheel
# Inputs:
#    - PSYCOPG_VERSION - Version to build

#
# Stage: builder
# Purpose:
#  - Build the psycopg wheel
#
ARG DEBIAN_RELEASE="bookworm"
FROM python:3.12-slim-${DEBIAN_RELEASE} AS builder

ARG PSYCOPG_VERSION
ARG DEBIAN_FRONTEND=noninteractive

ARG BUILD_PACKAGES="\
  build-essential \
  curl \
  ca-certificates"

WORKDIR /usr/src

# As this is an base image for a multi-stage final image
# the added size of the install is basically irrelevant

RUN set -eux \
  && echo "Installing build tools" \
    && apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends ${BUILD_PACKAGES} \
    && mkdir -p /usr/share/postgresql-common/pgdg/ \
    && curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${DEBIAN_RELEASE}-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install --yes --quiet --no-install-recommends libpq-dev \
  && echo "Installing Python tools" \
    && python3 -m pip install --no-cache-dir --upgrade pip wheel \
  && echo "Building psycopg wheel ${PSYCOPG_VERSION}" \
    && cd /usr/src \
    && mkdir wheels \
    && python3 -m pip wheel \
      # Build the package at the required version
      psycopg[c,pool]==${PSYCOPG_VERSION} \
      # Output the *.whl into this directory
      --wheel-dir wheels \
      # Do not use a binary packge for the package being built
      --no-binary=psycopg \
      --no-binary="psycopg-c" \
      # Do use binary packages for dependencies
      --prefer-binary \
      # Don't cache build files
      --no-cache-dir \
    && ls -ahl wheels/ \
  && echo "Gathering package data" \
    && dpkg-query -f '${Package;-40}${Version}\n' -W > ./wheels/pkg-list.txt \
  && echo "Cleaning up image" \
    && apt-get -y purge ${BUILD_PACKAGES} \
    && apt-get -y autoremove --purge \
    && rm -rf /var/lib/apt/lists/*

#
# Stage: package
# Purpose: Holds the compiled .whl files in a tiny image to pull
#
FROM scratch AS package

LABEL org.opencontainers.image.description="A image with psycopg wheel built in /usr/src/psycopg/"

WORKDIR /usr/src/psycopg/

COPY --from=builder /usr/src/wheels/*.whl ./
COPY --from=builder /usr/src/wheels/pkg-list.txt ./

ENTRYPOINT [ "/usr/bin/bash" ]
