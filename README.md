# Builder

This repository contains the Dockerfiles to build a few programs paperless
installs in its Docker image.

Basically, this repository does the upfront work (compiling) at infrequent intervals,
so the main image doesn't ever need to do that.

## QPDF

The actions no longer build QPDF, as Debian Bookworm now provides qpdf 11.3.0,
prebuilt, which is new enough.

## psycopg2

This repository no longer builds wheels for psycopg2.

## jbig2enc

Nothing packages jbig2enc for installation, due to license issues (real or
perceived) and so it cannot be installed directly.

In this repository, the last released version 0.29 is built as a .deb installer.

## pikepdf

This repository no longer builds wheels for pikepdf.

## Building Installers

1. Build an image from the Dockerfile for what you're trying to update.
1. Run the image with a mount and copy out the build files
    - Built files means either the .deb or .whl files
    - `docker run --rm -it -v "$(pdw):/data qpdf:11.6.1 /bin/bash`
1. Upload the built files to a [release](https://github.com/paperless-ngx/builder/releases)
1. Update links in the main [Dockerfile](https://github.com/paperless-ngx/paperless-ngx/blob/dev/Dockerfile)
