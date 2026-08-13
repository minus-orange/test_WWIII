#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
# shellcheck source=nvhpc_library_versions.sh
source "${script_dir}/nvhpc_library_versions.sh"

library_root="${WW3_LIB_ROOT:-${repo_dir}/external/oneapi-libs}"
download_dir="${WW3_LIB_DOWNLOAD_DIR:-${library_root}/downloads}"
source_dir="${WW3_LIB_SOURCE_DIR:-${library_root}/sources}"
build_root="${WW3_LIB_BUILD_DIR:-${library_root}/build}"
install_prefix="${WW3_LIB_PREFIX:-${library_root}/install}"
build_type="${WW3_LIB_BUILD_TYPE:-Release}"
jobs="${WW3_LIB_JOBS:-4}"
run_tests="${WW3_LIB_RUN_TESTS:-OFF}"

case "${run_tests}" in
  ON|OFF) ;;
  *) echo "ERROR: WW3_LIB_RUN_TESTS must be ON or OFF (found '${run_tests}')." >&2; exit 1 ;;
esac

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command '$1' was not found in PATH." >&2
    exit 1
  }
}

extract_once() {
  local archive="$1"
  local directory="$2"
  if [[ ! -d "${source_dir}/${directory}" ]]; then
    echo "Extracting ${archive}"
    tar -xzf "${download_dir}/${archive}" -C "${source_dir}"
  fi
}

configure_build_install() {
  local name="$1"
  local source_path="$2"
  local build_path="$3"
  shift 3
  echo "Configuring ${name}"
  cmake -S "${source_path}" -B "${build_path}" "$@"
  echo "Building ${name}"
  cmake --build "${build_path}" --parallel "${jobs}"
  if [[ "${run_tests}" == "ON" ]]; then
    ctest --test-dir "${build_path}" --output-on-failure --parallel "${jobs}"
  fi
  echo "Installing ${name}"
  cmake --install "${build_path}"
}

for command_name in cmake tar icx ifx; do
  require_command "${command_name}"
done
mkdir -p "${download_dir}" "${source_dir}" "${build_root}" "${install_prefix}"

echo "Verifying source archives (no network access)"
if ! WW3_LIB_DOWNLOAD_DIR="${download_dir}" WW3_LIB_ROOT="${library_root}" \
  "${script_dir}/download_oneapi_libraries.sh" --verify-only; then
  echo "ERROR: library sources are not ready." >&2
  echo "Run tools/download_oneapi_libraries.sh before this build script." >&2
  exit 1
fi

extract_once "${ZLIB_ARCHIVE}" "zlib-${ZLIB_VERSION}"
extract_once "${HDF5_ARCHIVE}" "hdf5-${HDF5_VERSION}"
extract_once "${NETCDF_C_ARCHIVE}" "netcdf-c-${NETCDF_C_VERSION}"
extract_once "${NETCDF_FORTRAN_ARCHIVE}" "netcdf-fortran-${NETCDF_FORTRAN_VERSION}"

prefix_path="${install_prefix}"
install_rpath="${install_prefix}/lib;${install_prefix}/lib64"
export PATH="${install_prefix}/bin:${PATH}"
export CMAKE_PREFIX_PATH="${prefix_path}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
export PKG_CONFIG_PATH="${install_prefix}/lib/pkgconfig:${install_prefix}/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
export LD_LIBRARY_PATH="${install_prefix}/lib:${install_prefix}/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

configure_build_install "zlib ${ZLIB_VERSION}" \
  "${source_dir}/zlib-${ZLIB_VERSION}" "${build_root}/zlib-${ZLIB_VERSION}" \
  -DCMAKE_C_COMPILER=icx -DCMAKE_BUILD_TYPE="${build_type}" \
  -DCMAKE_INSTALL_PREFIX="${install_prefix}" -DZLIB_BUILD_TESTING="${run_tests}" \
  -DZLIB_BUILD_SHARED=ON -DZLIB_BUILD_STATIC=OFF

configure_build_install "HDF5 ${HDF5_VERSION}" \
  "${source_dir}/hdf5-${HDF5_VERSION}" "${build_root}/hdf5-${HDF5_VERSION}" \
  -DCMAKE_C_COMPILER=icx -DCMAKE_BUILD_TYPE="${build_type}" \
  -DCMAKE_INSTALL_PREFIX="${install_prefix}" -DCMAKE_PREFIX_PATH="${prefix_path}" \
  -DCMAKE_INSTALL_RPATH="${install_rpath}" -DBUILD_SHARED_LIBS=ON \
  -DBUILD_STATIC_LIBS=OFF -DBUILD_TESTING="${run_tests}" -DHDF5_BUILD_CPP_LIB=OFF \
  -DHDF5_BUILD_FORTRAN=OFF -DHDF5_BUILD_HL_LIB=ON -DHDF5_BUILD_EXAMPLES=OFF \
  -DHDF5_BUILD_TOOLS=OFF -DHDF5_ENABLE_PARALLEL=OFF -DHDF5_ENABLE_SZIP_SUPPORT=OFF \
  -DHDF5_ENABLE_Z_LIB_SUPPORT=ON -DZLIB_ROOT="${install_prefix}"

configure_build_install "NetCDF-C ${NETCDF_C_VERSION}" \
  "${source_dir}/netcdf-c-${NETCDF_C_VERSION}" "${build_root}/netcdf-c-${NETCDF_C_VERSION}" \
  -DCMAKE_C_COMPILER=icx -DCMAKE_BUILD_TYPE="${build_type}" \
  -DCMAKE_INSTALL_PREFIX="${install_prefix}" -DCMAKE_PREFIX_PATH="${prefix_path}" \
  -DCMAKE_INSTALL_RPATH="${install_rpath}" -DBUILD_SHARED_LIBS=ON \
  -DNETCDF_ENABLE_TESTS="${run_tests}" -DNETCDF_ENABLE_DAP=OFF -DNETCDF_ENABLE_NCZARR=OFF \
  -DNETCDF_ENABLE_REMOTE_FUNCTIONALITY=OFF -DNETCDF_ENABLE_BYTERANGE=OFF \
  -DNETCDF_ENABLE_LIBXML2=OFF -DNETCDF_ENABLE_PLUGINS=OFF \
  -DNETCDF_ENABLE_FILTER_SZIP=OFF -DNETCDF_ENABLE_FILTER_BZ2=OFF \
  -DNETCDF_ENABLE_FILTER_BLOSC=OFF -DNETCDF_ENABLE_FILTER_ZSTD=OFF \
  -DSzip_FOUND=FALSE -DBz2_FOUND=FALSE -DBlosc_FOUND=FALSE -DZstd_FOUND=FALSE \
  -DNETCDF_ENABLE_HDF5=ON -DNETCDF_ENABLE_PARALLEL4=OFF \
  -DNETCDF_ENABLE_PARALLEL_TESTS=OFF

configure_build_install "NetCDF-Fortran ${NETCDF_FORTRAN_VERSION}" \
  "${source_dir}/netcdf-fortran-${NETCDF_FORTRAN_VERSION}" \
  "${build_root}/netcdf-fortran-${NETCDF_FORTRAN_VERSION}" \
  -DCMAKE_C_COMPILER=icx -DCMAKE_Fortran_COMPILER=ifx \
  -DCMAKE_BUILD_TYPE="${build_type}" -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
  -DCMAKE_PREFIX_PATH="${prefix_path}" -DCMAKE_INSTALL_RPATH="${install_rpath}" \
  -DBUILD_SHARED_LIBS=ON -DBUILD_EXAMPLES=OFF -DENABLE_TESTS="${run_tests}" \
  -DENABLE_PARALLEL_TESTS=OFF -DDISABLE_ZSTANDARD_PLUGIN=TRUE

echo "Library build completed"
echo "  install prefix: ${install_prefix}"
"${install_prefix}/bin/nc-config" --version
"${install_prefix}/bin/nf-config" --version

netcdf_link_dirs=()
for library_dir in "${install_prefix}/lib" "${install_prefix}/lib64"; do
  [[ ! -d "${library_dir}" ]] || netcdf_link_dirs+=("-L${library_dir}")
done
ifx -I"${install_prefix}/include" "${script_dir}/check_netcdf.f90" \
  "${netcdf_link_dirs[@]}" -lnetcdff -lnetcdf -o "${build_root}/check_netcdf"
"${build_root}/check_netcdf"

echo "Build WW3 with:"
echo "  WW3_NETCDF_ROOT=${install_prefix} ./tools/build_oneapi_legacy.sh"
