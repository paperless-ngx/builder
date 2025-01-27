# This Dockerfile builds the zxing wheel
# Inputs:
#    - ZXING_VERSION - Version to build

#
# Stage: builder
# Purpose:
#  - Build the zxing wheel
#
FROM python:3.12-slim-bookworm AS builder

ARG ZXING_VERSION=2.3.0
ARG DEBIAN_FRONTEND=noninteractive

ARG BUILD_PACKAGES="\
  build-essential \
  # https://github.com/zxing-cpp/zxing-cpp#build-instructions
  cmake"

WORKDIR /usr/src

# As this is an base image for a multi-stage final image
# the added size of the install is basically irrelevant

RUN set -eux \
  && echo "Installing build tools" \
    && apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends ${BUILD_PACKAGES} \
  && echo "Installing Python tools" \
    && python3 -m pip install --no-cache-dir --upgrade pip wheel \
  && echo "Building zxing wheel ${ZXING_VERSION}" \
    && cd /usr/src \
    && mkdir wheels \
    && python3 -m pip wheel \
      # Build the package at the required version
      zxing-cpp==${ZXING_VERSION} \
      # Output the *.whl into this directory
      --wheel-dir wheels \
      --no-binary="zxing-cpp" \
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

LABEL org.opencontainers.image.description="A image with zxing wheel built in /usr/src/zxing/"

WORKDIR /usr/src/zxing/

COPY --from=builder /usr/src/wheels/*.whl ./
COPY --from=builder /usr/src/wheels/pkg-list.txt ./

ENTRYPOINT [ "/usr/bin/bash" ]
