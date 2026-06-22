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

## sqlite-vec

Builds patched `sqlite-vec` wheels for paperless-ngx's AI vector store. Upstream
`asg017/sqlite-vec` only publishes `0.1.9` to PyPI and ships no source
distribution, so the fixes paperless needs (the open PRs #303-#310) are not
installable from PyPI. The patched source lives in the fork
`stumpylog/sqlite-vec`, tagged (currently `v0.1.10-paperless.1`); the build
clones that tag, compiles `vec0` via the upstream `make loadable`, and wraps it
in a `py3-none-<platform>` wheel with a small stdlib-only assembler (no
`sqlite-dist`, no Rust). Wheels are versioned `0.1.10+paperless.N` and consumed
in paperless-ngx via `[tool.uv.sources]` URL pins.

Build locally with `./build.sh sqlite-vec [version] [platform_tag]`; CI builds
the full Linux + macOS matrix via `build-sqlite-vec.yml`.

## Building Installers

1. Run `./build <thing> <version>

- `./build.sh jbig2enc 0.30` for example
- Output files are copied to `output/`
