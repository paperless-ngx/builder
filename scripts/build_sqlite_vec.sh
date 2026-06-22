#!/usr/bin/env bash
# Build a patched sqlite-vec wheel for the current platform.
#
# The patched source lives in the fork stumpylog/sqlite-vec, tagged. We clone
# that ref directly (it already bundles the open-PR fixes as commits), vendor
# the SQLite amalgamation, build the loadable extension, and wrap it in a wheel.
#
# Usage: scripts/build_sqlite_vec.sh <version> <platform_tag> <out_dir>
set -euxo pipefail

VERSION="${1:?version required, e.g. 0.1.10+paperless.1}"
PLATFORM_TAG="${2:?platform tag required, e.g. linux_x86_64}"
OUT_DIR="${3:?output dir required}"

# Fork + tag holding the patched source.
SQLITE_VEC_REF="${SQLITE_VEC_REF:-v0.1.10-paperless.1}"
SQLITE_VEC_REPO="${SQLITE_VEC_REPO:-https://github.com/stumpylog/sqlite-vec.git}"

# Repo root = parent of this script's dir.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Resolve OUT_DIR to an absolute path now: the build runs from inside a temp
# clone, so a relative path would land there (and be deleted with it).
mkdir -p "${OUT_DIR}"
OUT_DIR="$(cd "${OUT_DIR}" && pwd)"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Shallow-clone just the tagged ref.
git clone --depth 1 --branch "${SQLITE_VEC_REF}" "${SQLITE_VEC_REPO}" "${WORK}/src"
cd "${WORK}/src"

# macOS: build a portable binary.
case "${PLATFORM_TAG}" in
	macosx_11_0_arm64)   export MACOSX_DEPLOYMENT_TARGET=11.0 ;;
	macosx_10_13_x86_64) export MACOSX_DEPLOYMENT_TARGET=10.13 ;;
esac

./scripts/vendor.sh
make loadable

BINARY=""
for cand in dist/vec0.so dist/vec0.dylib; do
	if [ -f "${cand}" ]; then
		BINARY="${cand}"
		break
	fi
done
test -n "${BINARY}"

python3 "${BUILDER_ROOT}/scripts/assemble_wheel.py" \
	--binary "${BINARY}" \
	--version "${VERSION}" \
	--platform-tag "${PLATFORM_TAG}" \
	--out "${OUT_DIR}"

ls -l "${OUT_DIR}"/*.whl
