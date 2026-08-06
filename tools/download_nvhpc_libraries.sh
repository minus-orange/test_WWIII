#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
# shellcheck source=nvhpc_library_versions.sh
source "${script_dir}/nvhpc_library_versions.sh"

download_dir="${WW3_LIB_DOWNLOAD_DIR:-${repo_dir}/external/nvhpc-libs/downloads}"
mkdir -p "${download_dir}"

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "ERROR: sha256sum or shasum is required." >&2
    return 1
  fi
}

download_one() {
  local name="$1"
  local archive="$2"
  local url="$3"
  local expected="$4"
  local destination="${download_dir}/${archive}"
  local temporary="${destination}.part"
  local actual

  if [[ -f "${destination}" ]]; then
    actual="$(sha256_file "${destination}")"
    if [[ "${actual}" == "${expected}" ]]; then
      echo "Using verified ${name}: ${destination}"
      return
    fi
    echo "Checksum mismatch in existing ${destination}; downloading again." >&2
    rm -f "${destination}"
  fi

  echo "Downloading ${name} ${url}"
  command -v curl >/dev/null 2>&1 || {
    echo "ERROR: curl is required to download ${archive}." >&2
    return 1
  }
  rm -f "${temporary}"
  curl --fail --location --retry 3 --output "${temporary}" "${url}"
  actual="$(sha256_file "${temporary}")"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "ERROR: SHA-256 mismatch for ${archive}" >&2
    echo "  expected: ${expected}" >&2
    echo "  actual  : ${actual}" >&2
    rm -f "${temporary}"
    return 1
  fi
  mv "${temporary}" "${destination}"
  echo "Verified ${destination}"
}

download_one "zlib" "${ZLIB_ARCHIVE}" "${ZLIB_URL}" "${ZLIB_SHA256}"
download_one "HDF5" "${HDF5_ARCHIVE}" "${HDF5_URL}" "${HDF5_SHA256}"
download_one "NetCDF-C" "${NETCDF_C_ARCHIVE}" "${NETCDF_C_URL}" "${NETCDF_C_SHA256}"
download_one "NetCDF-Fortran" "${NETCDF_FORTRAN_ARCHIVE}" "${NETCDF_FORTRAN_URL}" "${NETCDF_FORTRAN_SHA256}"

echo "All source archives are ready in ${download_dir}"
