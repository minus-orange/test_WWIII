#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"

build_dir="${WW3_BUILD_DIR:-${repo_dir}/build-nvhpc}"
switch_file="${WW3_SWITCH:-model/bin/switch_ST4_UOST}"
build_type="${WW3_BUILD_TYPE:-Release}"
jobs="${WW3_JOBS:-4}"
default_netcdf_root="${repo_dir}/external/nvhpc-libs/install"

cmake_args=(
  -S "${repo_dir}"
  -B "${build_dir}"
  -DCMAKE_TOOLCHAIN_FILE="${repo_dir}/cmake/toolchains/nvhpc-mpi.cmake"
  -DSWITCH="${switch_file}"
  -DCMAKE_BUILD_TYPE="${build_type}"
)

if [[ -n "${WW3_NETCDF_ROOT:-}" ]]; then
  cmake_args+=("-DNetCDF_ROOT=${WW3_NETCDF_ROOT}")
elif [[ -n "${NetCDF_ROOT:-}" ]]; then
  cmake_args+=("-DNetCDF_ROOT=${NetCDF_ROOT}")
elif [[ -x "${default_netcdf_root}/bin/nc-config" &&
        -x "${default_netcdf_root}/bin/nf-config" ]]; then
  cmake_args+=("-DNetCDF_ROOT=${default_netcdf_root}")
elif ! command -v nc-config >/dev/null 2>&1 ||
     ! command -v nf-config >/dev/null 2>&1; then
  echo "ERROR: NetCDF-C/Fortran was not found." >&2
  echo "Build the NVHPC libraries first:" >&2
  echo "  ./tools/build_nvhpc_libraries.sh" >&2
  echo "Then rerun this script." >&2
  exit 1
fi

# This is empty for the CPU compile check. It can later carry NVIDIA options
# such as: -acc -gpu=cc80 -Minfo=accel
if [[ -n "${WW3_NVHPC_FLAGS:-}" ]]; then
  cmake_args+=("-DCMAKE_Fortran_FLAGS=${WW3_NVHPC_FLAGS}")
fi

echo "Configuring WW3 with NVIDIA HPC SDK"
echo "  source : ${repo_dir}"
echo "  build  : ${build_dir}"
echo "  switch : ${switch_file}"
echo "  type   : ${build_type}"
if [[ -n "${WW3_NETCDF_ROOT:-${NetCDF_ROOT:-}}" ]]; then
  echo "  netcdf : ${WW3_NETCDF_ROOT:-${NetCDF_ROOT:-}}"
elif [[ -x "${default_netcdf_root}/bin/nc-config" ]]; then
  echo "  netcdf : ${default_netcdf_root}"
else
  echo "  netcdf : from PATH/CMake search"
fi

cmake "${cmake_args[@]}" "$@"
cmake --build "${build_dir}" --parallel "${jobs}"

echo "Build completed. Load modules are in ${build_dir}/bin"
