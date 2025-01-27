# syntax=docker/dockerfile:1
#
# Stage: pre-build
# Purpose:
#  - Installs common packages
#  - Sets common environment variables related to dpkg
#  - Acquires the ghostscript source from bookwork
# Useful Links:
#  - https://wiki.debian.org/Multiarch/HOWTO
#  - https://wiki.debian.org/CrossCompiling
#

FROM debian:bookworm-slim as pre-build

ARG GS_VERSION=10.04.0

ARG COMMON_BUILD_PACKAGES="\
  debhelper \
  ca-certificates \
  debian-keyring \
  devscripts \
  dpkg-dev \
  equivs \
  packaging-dev"

ENV DEB_BUILD_OPTIONS="terse nocheck parallel=4"

WORKDIR /usr/src

RUN set -eux \
  && echo "Installing common packages" \
    && apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends ${COMMON_BUILD_PACKAGES} \
  && echo "Getting ghostscript source" \
    && echo "deb-src http://deb.debian.org/debian/ trixie main" > /etc/apt/sources.list.d/trixie-src.list \
    && apt-get update --quiet \
    && apt-get source --yes --quiet ghostscript=${GS_VERSION}~dfsg-2/trixie

WORKDIR /usr/src/ghostscript-${GS_VERSION}~dfsg

#
# Stage: amd64-builder
# Purpose: Builds qpdf for x86_64 (native build)
#
FROM pre-build as amd64-builder

ARG AMD64_BUILD_PACKAGES="\
  freeglut3-dev:amd64 \
  libcups2-dev:amd64 \
  libcupsimage2-dev:amd64 \
  libfreetype-dev:amd64 \
  libice-dev:amd64 \
  libidn11-dev:amd64 \
  libijs-dev:amd64 \
  libjbig2dec0-dev:amd64 \
  liblcms2-dev:amd64 \
  libopenjp2-7-dev:amd64 \
  libpaper-dev:amd64 \
  libpng-dev:amd64 \
  libsm-dev:amd64 \
  libtiff-dev:amd64 \
  libx11-dev:amd64 \
  libxext-dev:amd64 \
  libxt-dev:amd64 \
  dh-linktree:amd64 \
  dh-sequence-pkgkde-symbolshelper:amd64 \
  fonts-urw-base35:amd64 \
  libexpat-dev:amd64 \
  libfontconfig1-dev:amd64 \
  rename:amd64 \
  python3-sphinx:amd64 \
  python3-sphinx-rtd-theme:amd64 \
  rst2pdf:amd64"

RUN set -eux \
  && echo "Beginning amd64" \
    && echo "Install amd64 packages" \
      && apt-get update --quiet \
      && apt-get build-dep --yes ghostscript=${GS_VERSION}~dfsg-2/trixie:amd64 \
      && apt-get install --yes --quiet --no-install-recommends ${AMD64_BUILD_PACKAGES} \
    && echo "Building amd64" \
      && dpkg-buildpackage --build=binary --unsigned-source --unsigned-changes --post-clean \
    && echo "Removing debug files" \
      && rm -f ../*dbgsym* \
    && echo "Get build package versions" \
      && dpkg-query -f '${Package;-40}${Version}\n' -W > ../pkg-list.txt

#
# Stage: aarch64-builder
# Purpose:
#  - Sets aarch64 specific environment
#  - Builds ghostscript for aarch64 (cross compile)
#
FROM pre-build as aarch64-builder

ARG ARM64_PACKAGES="\
  crossbuild-essential-arm64 \
  freeglut3-dev:arm64 \
  libcups2-dev:arm64 \
  libcupsimage2-dev:arm64 \
  libfreetype-dev:arm64 \
  libice-dev:arm64 \
  libidn11-dev:arm64 \
  libijs-dev:arm64 \
  libjbig2dec0-dev:arm64 \
  liblcms2-dev:arm64 \
  libopenjp2-7-dev:arm64 \
  libpaper-dev:arm64 \
  libpng-dev:arm64 \
  libsm-dev:arm64 \
  libtiff-dev:arm64 \
  libx11-dev:arm64 \
  libxext-dev:arm64 \
  libxt-dev:arm64 \
  dh-linktree \
  dh-sequence-pkgkde-symbolshelper \
  fonts-urw-base35:arm64 \
  libexpat-dev:arm64 \
  libfontconfig1-dev:arm64 \
  rename:arm64 \
  python3-sphinx \
  python3-sphinx-rtd-theme \
  python3-sphinx-copybutton \
  zlib1g-dev \
  rst2pdf"

ENV CXX="/usr/bin/aarch64-linux-gnu-g++" \
    CC="/usr/bin/aarch64-linux-gnu-gcc"

RUN set -eux \
  && echo "Beginning arm64" \
    && echo "Install arm64 packages" \
      && dpkg --add-architecture arm64 \
      && apt-get update --quiet \
      && apt-get install --yes --quiet --no-install-recommends ${ARM64_PACKAGES} \
    && echo "Building arm64" \
      && dpkg-buildpackage --build=binary --unsigned-source --unsigned-changes --post-clean --host-arch arm64 \
    && echo "Removing debug files" \
      && rm -f ../*dbgsym* \
    && echo "Get build package versions" \
      && dpkg-query -f '${Package;-40}${Version}\n' -W > ../pkg-list.txt

FROM scratch as package

WORKDIR /usr/src/ghostscript

COPY --from=amd64-builder /usr/src/*.deb .
COPY --from=amd64-builder /usr/src/pkg-list.txt amd64-pkg-list.txt
COPY --from=aarch64-builder /usr/src/*.deb .
COPY --from=aarch64-builder /usr/src/pkg-list.txt aarch64-pkg-list.txt

ENTRYPOINT [ "/usr/bin/bash" ]
