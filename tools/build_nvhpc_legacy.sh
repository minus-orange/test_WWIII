#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
model_dir="${repo_dir}/model"
library_root="${WW3_LIB_ROOT:-${repo_dir}/external/nvhpc-libs}"
netcdf_prefix="${WW3_NETCDF_ROOT:-${WW3_LIB_PREFIX:-${library_root}/install}}"
nc_config="${WW3_NC_CONFIG:-${netcdf_prefix}/bin/nc-config}"
nf_config="${WW3_NF_CONFIG:-${netcdf_prefix}/bin/nf-config}"
shared_switch="${WW3_SHARED_SWITCH:-ST4_UOST_SHRD}"
parallel_switch="${WW3_PARALLEL_SWITCH:-ST4_UOST}"
compiler_name="${WW3_LEGACY_COMPILER:-nvhpc}"
scratch_dir="${WW3_LEGACY_TMP:-${model_dir}/tmp-nvhpc-legacy}"
jobs="${WW3_JOBS:-4}"
shared_programs=(ww3_grid ww3_strt ww3_prnc ww3_ounf ww3_ounp)
parallel_programs=(ww3_shel)
programs=("${shared_programs[@]}" "${parallel_programs[@]}")

case "${repo_dir}" in
  *[[:space:]]*)
    echo "ERROR: the WW3 legacy build does not support whitespace in its path:" >&2
    echo "  ${repo_dir}" >&2
    echo "Use a checkout path without spaces on the target Linux system." >&2
    exit 1
    ;;
esac
case "${jobs}" in
  ""|*[!0-9]*|0)
    echo "ERROR: WW3_JOBS must be a positive integer." >&2
    exit 2
    ;;
esac

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command '$1' was not found in PATH." >&2
    exit 1
  }
}

for command_name in make ar cc nvfortran mpifort mpicc; do
  require_command "${command_name}"
done
for config in "${nc_config}" "${nf_config}"; do
  if [[ ! -x "${config}" ]]; then
    echo "ERROR: NetCDF configuration utility was not found: ${config}" >&2
    echo "Run tools/build_nvhpc_libraries.sh first or set WW3_NETCDF_ROOT." >&2
    exit 1
  fi
done
for switch_name in "${shared_switch}" "${parallel_switch}"; do
  if [[ ! -r "${model_dir}/bin/switch_${switch_name}" ]]; then
    echo "ERROR: switch file was not found: model/bin/switch_${switch_name}" >&2
    exit 1
  fi
done
if ! grep -qw SHRD "${model_dir}/bin/switch_${shared_switch}" ||
   grep -Eqw 'DIST|MPI' "${model_dir}/bin/switch_${shared_switch}"; then
  echo "ERROR: switch_${shared_switch} must contain SHRD and omit DIST/MPI." >&2
  exit 1
fi
if ! grep -qw DIST "${model_dir}/bin/switch_${parallel_switch}" ||
   ! grep -qw MPI "${model_dir}/bin/switch_${parallel_switch}" ||
   grep -qw SHRD "${model_dir}/bin/switch_${parallel_switch}"; then
  echo "ERROR: switch_${parallel_switch} must contain DIST MPI and omit SHRD." >&2
  exit 1
fi

mpi_fortran="$({ mpifort --showme:command 2>/dev/null || mpifort -show 2>/dev/null; } | head -n 1)"
if [[ "${mpi_fortran}" != *nvfortran* ]]; then
  echo "ERROR: mpifort does not use nvfortran: ${mpi_fortran:-unknown}" >&2
  echo "Load the NVIDIA HPC SDK MPI module before running this script." >&2
  exit 1
fi
netcdf_fortran="$("${nf_config}" --fc)"
if [[ "${netcdf_fortran}" != *nvfortran* ]]; then
  echo "ERROR: NetCDF-Fortran was not built with nvfortran: ${netcdf_fortran}" >&2
  exit 1
fi

export WW3_LEGACY_NC_CONFIG="${nc_config}"
export WW3_LEGACY_NF_CONFIG="${nf_config}"
export NETCDF_CONFIG="${script_dir}/nvhpc_netcdf_config.sh"
export WW3_PARCOMPN="${jobs}"
export PATH="${netcdf_prefix}/bin:${PATH}"
export LD_LIBRARY_PATH="${netcdf_prefix}/lib:${netcdf_prefix}/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

echo "Configuring WW3 legacy build (no CMake)"
echo "  source   : ${model_dir}"
echo "  compiler : ${compiler_name} ($(command -v nvfortran))"
echo "  MPI      : $(command -v mpifort)"
echo "  NetCDF   : ${netcdf_prefix}"
echo "  switches : switch_${shared_switch} (5 sequential LM)"
echo "             switch_${parallel_switch} (ww3_shel MPI)"
echo "  scratch  : ${scratch_dir}"

"${script_dir}/select_legacy_build_tree.sh" "${model_dir}" "${compiler_name}"
"${script_dir}/prepare_legacy_program_set.sh" "${model_dir}" "${programs[@]}"

build_program_group() {
  local switch_name="$1"
  shift
  local group_programs=("$@")

  echo "Building with switch_${switch_name}: ${group_programs[*]}"
  "${model_dir}/bin/w3_setup" -q -c "${compiler_name}" -s "${switch_name}" \
    -t "${scratch_dir}" "${model_dir}"

  # Generated makefiles are switch-specific but do not track all helper changes.
  for generated_makefile in \
    "${model_dir}/src/makefile" "${model_dir}/src/makefile_SEQ" \
    "${model_dir}/src/makefile_OMP" "${model_dir}/src/makefile_MPI" \
    "${model_dir}/src/makefile_HYB"
  do
    rm -f "${generated_makefile}"
  done
  "${model_dir}/bin/w3_make" "${group_programs[@]}"
}

build_program_group "${shared_switch}" "${shared_programs[@]}"
build_program_group "${parallel_switch}" "${parallel_programs[@]}"

for program in "${programs[@]}"; do
  if [[ ! -x "${model_dir}/exe/${program}" ]]; then
    echo "ERROR: legacy build finished without model/exe/${program}." >&2
    exit 1
  fi
done

echo "Legacy build completed. Load modules are in ${model_dir}/exe"
echo "Persistent NVHPC LM directory: ${model_dir}/.legacy-builds/${compiler_name}/exe"
printf '  %s\n' "${programs[@]}"
