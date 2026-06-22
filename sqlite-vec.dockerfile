# This Dockerfile builds a patched sqlite-vec wheel
# Inputs:
#   - SQLITE_VEC_VERSION : wheel version, e.g. 0.1.10+paperless.1
#   - PLATFORM_TAG       : linux_x86_64 | linux_aarch64
#   - DEBIAN_RELEASE     : trixie (default)

#
# Stage: builder
# Purpose:
#  - Clone the patched sqlite-vec fork tag, build it, assemble the wheel
#
ARG DEBIAN_RELEASE="trixie"
FROM python:3.12-slim-${DEBIAN_RELEASE} AS builder

ARG SQLITE_VEC_VERSION
ARG PLATFORM_TAG
ARG DEBIAN_FRONTEND=noninteractive

ARG BUILD_PACKAGES="\
  build-essential \
  ca-certificates \
  curl \
  gettext-base \
  git \
  unzip"

WORKDIR /usr/src/builder

RUN set -eux \
  && echo "Installing build tools" \
    && apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends ${BUILD_PACKAGES}

# Copy only what the build needs.
COPY scripts/ ./scripts/

RUN set -eux \
  && echo "Building sqlite-vec wheel ${SQLITE_VEC_VERSION} (${PLATFORM_TAG})" \
    && ./scripts/build_sqlite_vec.sh "${SQLITE_VEC_VERSION}" "${PLATFORM_TAG}" /usr/src/wheels \
  && echo "Smoke-testing the wheel" \
    && python3 -m venv /tmp/vt \
    && /tmp/vt/bin/pip install /usr/src/wheels/*.whl \
    && /tmp/vt/bin/python -c "import sqlite3, sqlite_vec; c=sqlite3.connect(':memory:'); c.enable_load_extension(True); sqlite_vec.load(c); print(c.execute('select vec_version()').fetchone())" \
  && echo "Cleaning up image" \
    && apt-get -y purge ${BUILD_PACKAGES} \
    && apt-get -y autoremove --purge \
    && rm -rf /var/lib/apt/lists/*

#
# Stage: package
# Purpose: Holds the built .whl in a tiny image to pull
#
FROM scratch AS package

LABEL org.opencontainers.image.description="A image with the sqlite-vec wheel built in /usr/src/sqlite-vec/"

WORKDIR /usr/src/sqlite-vec/

COPY --from=builder /usr/src/wheels/*.whl ./

ENTRYPOINT [ "/usr/bin/bash" ]
