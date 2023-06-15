# This Dockerfile builds the pikepdf wheel
# Inputs:
#    - PIKEPDF_VERSION - Version of pikepdf to build wheel for
#    - LXML_VERSION - pikepdf depends on lxml, set the version used
#    - PILLOW_VERSION - pikepdf depends on pillow, set the version used

#
# Stage: builder
# Purpose:
#  - Build the pikepdf wheel
#  - Build any dependent wheels which can't be found
#
FROM python:3.9-slim-bookworm as builder

# Buildx provided
ARG TARGETARCH
ARG TARGETVARIANT

ARG DEBIAN_FRONTEND=noninteractive
# Workflow provided
ARG PIKEPDF_VERSION
ARG PILLOW_VERSION
ARG LXML_VERSION

ARG BUILD_PACKAGES="\
  build-essential \
  libqpdf-dev \
  # lxml requrements - https://lxml.de/installation.html
  libxml2-dev \
  libxslt1-dev \
  # Pillow requirements - https://pillow.readthedocs.io/en/stable/installation.html#external-libraries
  # JPEG functionality
  libjpeg62-turbo-dev \
  # conpressed PNG
  zlib1g-dev \
  # compressed TIFF
  libtiff-dev \
  # type related services
  libfreetype-dev \
  # color management
  liblcms2-dev \
  # WebP format
  libwebp-dev \
  # JPEG 2000
  libopenjp2-7-dev \
  # improved color quantization
  libimagequant-dev \
  # complex text layout support
  libraqm-dev"

WORKDIR /usr/src

# As this is an base image for a multi-stage final image
# the added size of the install is basically irrelevant

RUN set -eux \
  && echo "Installing build tools" \
    && apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends ${BUILD_PACKAGES} \
  && echo "Installing Python tools" \
    && python3 -m pip install --no-cache-dir --upgrade \
      pip \
      wheel \
      # https://pikepdf.readthedocs.io/en/latest/installation.html#requirements
      pybind11 \
  && echo "Building pikepdf wheel ${PIKEPDF_VERSION}" \
    && mkdir wheels \
    && python3 -m pip wheel \
      # Build or get the package(s) at the required version
      pikepdf==${PIKEPDF_VERSION} \
      lxml==${LXML_VERSION} \
      pillow==${PILLOW_VERSION} \
      # Output the *.whl into this directory
      --wheel-dir wheels \
      # Do not use a binary packge for the package being built
      --no-binary=pikepdf \
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

LABEL org.opencontainers.image.description="A image with pikepdf wheel built in /usr/src/pikepdf/"

WORKDIR /usr/src/pikepdf/

COPY --from=builder /usr/src/wheels/*.whl ./
COPY --from=builder /usr/src/wheels/pkg-list.txt ./
