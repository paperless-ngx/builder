# Builder

This repository contains the Dockerfiles to build a few programs paperless
installs in its Docker image, at newer versions, but built for the underlying
Debian version (Bookworm currently)

Basically, this repository does the upfront work (compiling) at infrequent intervals,
so the main image doesn't ever need to do that and we can provide some newer
tool versions which (hopefully) include fixes, features and so on.

## Tools

### QPDF

Keeping a more updated version of QPDF

## jbig2enc

Nothing packages jbig2enc for installation, due to license issues (real or
perceived) and so it cannot be installed directly.

In this repository, the last released version 0.30 is built as a .deb installer.

## Ghostscript

This includes some fixes and some security fixes as well. As OCRMyPdf uses Ghostscript pretty extensively,
providing a very recent version helps resolve problems with its outputs

## Building Installers

1. Run `./build <thing> <version>

- `./build.sh jbig2enc 0.30` for example
- Output files are copied to `output/`
