
FROM python:3.9-slim-bullseye as builder

ARG BUILD_PACKAGES="\
  build-essential \
  python3-dev \
  python3-pip\
  gfortran \
  libopenblas-dev \
  libatlas-base-dev \
  liblapack-dev \
  pkg-config"


WORKDIR /usr/src

RUN set -eux \
  && echo "Installing build tools" \
    && apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends ${BUILD_PACKAGES} \
  && echo "Installing Python tools" \
    && python3 -m pip install --no-cache-dir --upgrade pip wheel

ARG SCIPY_VERSION

RUN set -eux \
  && echo "Building scipy wheel" \
    && cd /usr/src \
    && mkdir wheels \
    && python3 -m pip --verbose wheel \
      # Build the package at the required version
      scipy==${SCIPY_VERSION} \
      # Look to piwheels for additional pre-built wheels
      --extra-index-url https://www.piwheels.org/simple \
      # Output the *.whl into this directory
      --wheel-dir wheels \
      # Do not use a binary packge for the package being built
      --no-binary=scipy \
      # Do use binary packages for dependencies
      --prefer-binary \
      # Don't cache build files
      --no-cache-dir \
    && ls -ahl wheels \
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
FROM alpine:3.18 as package

LABEL org.opencontainers.image.description="A image with scipy wheel built in /usr/src/scipy/"

WORKDIR /usr/src/scipy/

COPY --from=builder /usr/src/wheels/*.whl ./
COPY --from=builder /usr/src/wheels/pkg-list.txt ./
