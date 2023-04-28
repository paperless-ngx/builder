# Builder

Certain packages are either not built for ARMv7 or are too out of
date in the Debian package repositories to be of use for building.

In this repo, Docker and emulation are used to build and store installer
packages. These are then grabbed at a specific revision for installation into
main Docker image.

Basically, this repository does the upfront work at infrequent intervals,
so the main image doesn't ever need to build a wheel or deb package itself.

## QPDF

Debian Bullseye only provides 10.1.0. This is now several versions behind
and missing performance enhancements, bug fixes etc.

In this repository, qpdf is cross-compiled from the Debian Bookworm
source package

## psycopg2

The pre-built wheels of psycopg2 were linked against a too old version
of libpq-dev, resulting in connection failures. The version 13.9 in
Debian Bullseye is new enough to resolve these failures.

There is also no viable ARMv7 wheel.

In this repository, psycopg2 is built as a wheel and linked against libpq-dev
13.9.

## jbig2enc

Nothing packages jbig2enc for installation, due to license issues (real or
percived) and so it cannot be installed directly.

In this repository, the last released version 0.29 is built

## pikepdf

The latest pikepdf versions depend on at least qpdf 11.2.0. As nothing
packages that yet, the version built here is used for also building
pikepdf.

## Building Installers

The main workflow is triggered via dispatch. The needed inputs can be given
as needed or the defaults utilized instead.

The versions will be built and stored in Git.

Rebuilding the versions may result in no new commit. Caching is used
to prevent unnecessary rebuilds.
