# This Dockerfile builds the pikepdf wheel
# Inputs:
#    - QPDF_VERSION - The image qpdf version to copy .deb files from
#    - PIKEPDF_VERSION - Version of pikepdf to build wheel for
#    - LXML_VERSION - pikepdf depends on lxml, set the version used
#    - PILLOW_VERSION - pikepdf depends on pillow, set the version used

# This does nothing, except provide a name for a copy below
ARG QPDF_VERSION
# hadolint ignore=DL3029
FROM --platform=linux/amd64 ghcr.io/paperless-ngx/builder/qpdf:${QPDF_VERSION} as qpdf-builder

#
# Stage: builder
# Purpose:
#  - Build the pikepdf wheel
#  - Build any dependent wheels which can't be found
#
FROM python:3.9-slim-bullseye as builder

# Buildx provided
ARG TARGETARCH
ARG TARGETVARIANT

ARG DEBIAN_FRONTEND=noninteractive
# Workflow provided
ARG QPDF_VERSION
ARG PIKEPDF_VERSION
ARG PILLOW_VERSION
ARG LXML_VERSION

ARG BUILD_PACKAGES="\
  build-essential \
  python3-dev \
  python3-pip \
  # qpdf requirement - https://github.com/qpdf/qpdf#crypto-providers
  libgnutls28-dev \
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

COPY --from=qpdf-builder /usr/src/qpdf/${QPDF_VERSION}/${TARGETARCH}${TARGETVARIANT}/*.deb ./

# As this is an base image for a multi-stage final image
# the added size of the install is basically irrelevant

RUN set -eux \
  && echo "Installing build tools" \
    && apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends ${BUILD_PACKAGES} \
  && echo "Installing qpdf" \
    && dpkg --install libqpdf29_*.deb \
    && dpkg --install libqpdf-dev_*.deb \
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
      # Look to piwheels for additional pre-built wheels
      --extra-index-url https://www.piwheels.org/simple \
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