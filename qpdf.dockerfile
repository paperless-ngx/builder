#
# Stage: pre-build
# Purpose:
#  - Installs common packages
#  - Sets common environment variables related to dpkg
#  - Acquires the qpdf source from trixie
# Useful Links:
#  - https://qpdf.readthedocs.io/en/stable/installation.html#system-requirements
#  - https://wiki.debian.org/Multiarch/HOWTO
#  - https://wiki.debian.org/CrossCompiling
#

FROM debian:bookworm-slim as pre-build

ARG QPDF_VERSION=11.9.1

ARG COMMON_BUILD_PACKAGES="\
  cmake \
  ca-certificates \
  debhelper\
  debian-keyring \
  devscripts \
  dpkg-dev \
  equivs \
  packaging-dev \
  libtool \
  python3-sphinx \
  python3-sphinx-rtd-theme \
  texlive \
  texlive-latex-extra \
  latexmk \
  tex-gyre"

ENV DEB_BUILD_OPTIONS="terse nocheck nodoc parallel=8"

WORKDIR /usr/src

RUN set -eux \
  && echo "Installing common packages" \
    && apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends ${COMMON_BUILD_PACKAGES} \
  && echo "Getting qpdf source" \
    && echo "deb-src http://deb.debian.org/debian/ trixie main" > /etc/apt/sources.list.d/trixie-src.list \
    && apt-get update --quiet \
    && apt-get source --yes --quiet qpdf=${QPDF_VERSION}-1/trixie

WORKDIR /usr/src/qpdf-${QPDF_VERSION}

#
# Stage: amd64-builder
# Purpose: Builds qpdf for x86_64 (native build)
#
FROM pre-build as amd64-builder

ARG AMD64_BUILD_PACKAGES="\
  build-essential \
  libjpeg62-turbo-dev:amd64 \
  libgnutls28-dev:amd64 \
  zlib1g-dev:amd64"

RUN set -eux \
  && echo "Beginning amd64" \
    && echo "Install amd64 packages" \
      && apt-get update --quiet \
      && apt-get install --yes --quiet --no-install-recommends ${AMD64_BUILD_PACKAGES} \
    && echo "Building amd64" \
      && dpkg-buildpackage --build=binary --unsigned-source --unsigned-changes --post-clean --no-check-builddeps \
    && echo "Removing debug files" \
      && rm -f ../*dbgsym* \
    && echo "Get build package versions" \
      && dpkg-query -f '${Package;-40}${Version}\n' -W > ../pkg-list.txt

#
# Stage: aarch64-builder
# Purpose:
#  - Sets aarch64 specific environment
#  - Builds qpdf for aarch64 (cross compile)
#
FROM pre-build as aarch64-builder

ARG ARM64_PACKAGES="\
  crossbuild-essential-arm64 \
  libjpeg62-turbo-dev:arm64 \
  libgnutls28-dev:arm64 \
  zlib1g-dev:arm64"

ENV CXX="/usr/bin/aarch64-linux-gnu-g++" \
    CC="/usr/bin/aarch64-linux-gnu-gcc"

RUN set -eux \
  && echo "Beginning arm64" \
    && echo "Install arm64 packages" \
      && dpkg --add-architecture arm64 \
      && apt-get update --quiet \
      && apt-get install --yes --quiet --no-install-recommends ${ARM64_PACKAGES} \
    && echo "Building arm64" \
      && dpkg-buildpackage --build=binary --unsigned-source --unsigned-changes --post-clean --no-check-builddeps --host-arch arm64 \
    && echo "Removing debug files" \
      && rm -f ../*dbgsym* \
    && echo "Get build package versions" \
      && dpkg-query -f '${Package;-40}${Version}\n' -W > ../pkg-list.txt

FROM scratch as package

WORKDIR /usr/src/qpdf

COPY --from=amd64-builder /usr/src/*.deb .
COPY --from=amd64-builder /usr/src/pkg-list.txt amd64-pkg-list.txt
COPY --from=aarch64-builder /usr/src/*.deb .
COPY --from=aarch64-builder /usr/src/pkg-list.txt aarch64-pkg-list.txt

ENTRYPOINT [ "/usr/bin/bash" ]
