#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"

# The source versions and checksums are compiler independent.  Reuse the
# verified downloader while keeping the oneAPI artifacts in a separate tree.
export WW3_LIB_ROOT="${WW3_LIB_ROOT:-${repo_dir}/external/oneapi-libs}"
exec "${script_dir}/download_nvhpc_libraries.sh" "$@"
