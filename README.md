# Builder

Certain Python libraries used in paperless are either not built for
ARMv7 or are out of date on PiWheels.

In this repo, Docker images combined with emulation are used to build and store installer
packages into a Git branch. The main image can then download the branch at a revision
to retrieve the built artifacts at a particular version.

Basically, this repository does the upfront work at infrequent intervals,
so the main image doesn't ever need to build a wheel or deb package itself.
And we can bypass piwheels issues due to its sometimes outdated builds.

## QPDF

The actions no longer build QPDF, as Debian Bookworm now provides qpdf 11.3.0,
prebuilt, which is new enough for pikepdf to build against.

## psycopg2

The pre-built wheels of psycopg2 were linked against a too old version
of libpq-dev, resulting in connection failures. See [#266](paperless-ngx/paperless-ngx/issues/266).

There is also no viable ARMv7 wheel.

In this repository, psycopg2 is built as a wheel and linked against a newer
version of libpq-dev, which resolves the issue.

## jbig2enc

Nothing packages jbig2enc for installation, due to license issues (real or
perceived) and so it cannot be installed directly.

In this repository, the last released version 0.29 is built. It provides
an executable and a library, neither of which are contained in a package file.

## pikepdf

There is no ARMv7 wheel for pikepdf > v7.

## Building Installers

The main workflow is triggered via dispatch. The needed inputs can be given
as needed or the defaults utilized instead.

The versions will be built and stored in Git, if something changes.

Rebuilding the versions may result in no new commit. Caching is used
to prevent unnecessary rebuilds.
