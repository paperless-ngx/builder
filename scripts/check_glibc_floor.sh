#!/usr/bin/env bash
# Fail if a Linux wheel's shared library needs a newer glibc than its
# manylinux platform tag claims.
#
# The sqlite-vec wheels are tagged manylinux_2_29_<arch> because the library
# references pow@GLIBC_2.29. A toolchain or base image change could silently
# raise that, and pip would then install the wheel on systems that cannot load
# it. Non-manylinux tags (the macOS wheels) are skipped.
#
# Usage: scripts/check_glibc_floor.sh <wheel> <platform_tag>
set -euo pipefail

WHEEL="${1:?wheel required}"
TAG="${2:?platform tag required, e.g. manylinux_2_29_x86_64}"

if [[ ! "${TAG}" =~ ^manylinux_([0-9]+)_([0-9]+)_ ]]; then
	echo "Platform tag ${TAG} is not manylinux, skipping the glibc check"
	exit 0
fi
CLAIMED="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
python3 -m zipfile -e "${WHEEL}" "${WORK}"
SO="$(find "${WORK}" -name '*.so' | head -n 1)"
test -n "${SO}"

NEEDED="$(objdump -T "${SO}" | grep -oE 'GLIBC_[0-9]+(\.[0-9]+)*' | sed 's/^GLIBC_//' | sort -Vu | tail -n 1)"
echo "Wheel tag claims glibc ${CLAIMED}; the library needs glibc ${NEEDED:-none}"

if [[ -n "${NEEDED}" ]] && [[ "$(printf '%s\n%s\n' "${NEEDED}" "${CLAIMED}" | sort -V | tail -n 1)" != "${CLAIMED}" ]]; then
	echo "ERROR: the library needs glibc ${NEEDED}, newer than the ${CLAIMED} in ${TAG}" >&2
	exit 1
fi
