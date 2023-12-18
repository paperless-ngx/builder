# Builder

This repository contains the Dockerfiles to build a few programs paperless
installs in its Docker image, at newer versions, but built for the underlying
Debian version (Bookworm currently)

Basically, this repository does the upfront work (compiling) at infrequent intervals,
so the main image doesn't ever need to do that and we can provide some newer
tool versions which (hopefully) include fixes, features and so on.

## Tools

### QPDF

This updates QPDF from 11.3.0 to 11.4.6.  Nothing directly uses QPDF, but
pre/post consume might and more up to date seems good.

## jbig2enc

Nothing packages jbig2enc for installation, due to license issues (real or
perceived) and so it cannot be installed directly.

In this repository, the last released version 0.29 is built as a .deb installer.

## Ghostscript

This updates Ghostscript from 10.0.0 to 10.02.1.  This includes some fixes and
some security fixes as well.  As OCRMyPdf uses Ghostscript pretty extensively,
providing a very recent version helps resolve problems with its outputs

## Building Installers

1. Build an image from the Dockerfile for what you're trying to update.
    - `docker build --tag ghostscript:10.02.1 --file ghostscript.dockerfile .`
1. Run the image with a mount and copy out the build files
    - Built files means either the .deb or .whl files
    - `docker run --rm -it -v "$(pwd)":/data ghostscript:10.02.1`
    - `cp *.deb /data/`
    - `exit`
1. Commit any changes to the Dockerfile for the tool
1. Create a tag for the release
    - `git tag ghostscript-10.02.1`
1. Upload the built files to a [release](https://github.com/paperless-ngx/builder/releases)
1. Update links in the main [Dockerfile](https://github.com/paperless-ngx/paperless-ngx/blob/dev/Dockerfile)
