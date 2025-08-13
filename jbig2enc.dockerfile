# This Dockerfile compiles the jbig2enc library for the native architecture.
#
# Inputs:
#    - JBIG2ENC_VERSION - The Git tag to checkout and build

FROM debian:trixie-slim

ARG JBIG2ENC_VERSION=0.30
ARG DEBIAN_FRONTEND=noninteractive

# Install common dependencies required for building a Debian package.
RUN apt-get update --quiet && \
    apt-get install --yes --quiet --no-install-recommends \
    wget \
    debhelper \
    ca-certificates \
    debian-keyring \
    devscripts \
    dpkg-dev \
    debmake \
    equivs \
    build-essential \
    libleptonica-dev \
    zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

RUN wget --quiet https://github.com/agl/jbig2enc/archive/refs/tags/${JBIG2ENC_VERSION}.tar.gz -O jbig2enc_${JBIG2ENC_VERSION}.orig.tar.gz && \
    tar -xzf jbig2enc_${JBIG2ENC_VERSION}.orig.tar.gz

WORKDIR /usr/src/jbig2enc-${JBIG2ENC_VERSION}

# Set build options and run the Debian package build process.
ENV DEB_BUILD_OPTIONS="terse nocheck nodoc"
RUN debmake && \
    dpkg-buildpackage --build=binary --unsigned-source --unsigned-changes --post-clean \
    dpkg-query -f '${Package;-40}${Version}\n' -W > /usr/src/pkg-list.txt

RUN mkdir -p /usr/src/jbig2enc && \
    mv /usr/src/*.deb /usr/src/pkg-list.txt /usr/src/jbig2enc/ && \
    rm -rf /usr/src/jbig2enc/jbig2enc-dbgsym_*.deb
