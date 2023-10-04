# This Dockerfile compiles the jbig2enc library
# Inputs:
#    - JBIG2ENC_VERSION - the Git tag to checkout and build

FROM debian:bookworm-slim as pre-build

ARG JBIG2ENC_VERSION=0.29
ARG DEBIAN_FRONTEND=noninteractive

ARG COMMON_BUILD_PACKAGES="\
  wget \
  ca-certificates \
  dpkg-dev \
  debmake \
  debhelper \
  libtool"

ENV DEB_BUILD_OPTIONS="terse nocheck nodoc parallel=2"

WORKDIR /usr/src

RUN set -eux \
  && echo "Installing common packages" \
    && apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends ${COMMON_BUILD_PACKAGES} \
  && echo "Getting qpdf source" \
    && wget --quiet https://github.com/agl/jbig2enc/archive/refs/tags/${JBIG2ENC_VERSION}.tar.gz \
    && mv 0.29.tar.gz jbig2enc-${JBIG2ENC_VERSION}.tar.gz\
    && tar -xzmf jbig2enc-${JBIG2ENC_VERSION}.tar.gz

WORKDIR /usr/src/jbig2enc-${JBIG2ENC_VERSION}

#
# Stage: amd64-builder
# Purpose: Builds qpdf for x86_64 (native build)
#
FROM pre-build as amd64-builder

ARG AMD64_BUILD_PACKAGES="\
  build-essential \
  libleptonica-dev:amd64 \
  zlib1g-dev:amd64"

RUN set -eux \
  && echo "Beginning amd64" \
    && echo "Install amd64 packages" \
      && apt-get update --quiet \
      && apt-get install --yes --quiet --no-install-recommends ${AMD64_BUILD_PACKAGES} \
    && echo "Building amd64" \
      && debmake \
      && dpkg-buildpackage --build=binary --unsigned-source --unsigned-changes --post-clean \
    && echo "Removing debug files" \
      && rm -f ../*dbgsym*

#
# Stage: aarch64-builder
# Purpose:
#  - Sets aarch64 specific environment
#  - Builds qpdf for aarch64 (cross compile)
#
FROM amd64-builder as aarch64-builder

ARG ARM64_PACKAGES="\
  crossbuild-essential-arm64 \
  libleptonica-dev:arm64 \
  zlib1g-dev:arm64"

ENV CXX="/usr/bin/aarch64-linux-gnu-g++" \
    CC="/usr/bin/aarch64-linux-gnu-gcc"

RUN set -eux \
  && echo "Beginning arm64" \
    && echo "Install arm64 packages" \
      && dpkg --add-architecture arm64 \
      && apt-get update --quiet \
      && apt-get install --yes --quiet --no-install-recommends ${ARM64_PACKAGES} \
    && echo "Building aarch64" \
      && debmake \
      && dpkg-buildpackage --build=binary --unsigned-source --unsigned-changes --post-clean \
    && echo "Removing debug files" \
      && rm -f ../*dbgsym*
