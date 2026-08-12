#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
case_dir="${repo_dir}/regtests/ww3_ts4"
input_dir="${case_dir}/input_rg_shel"
bin_dir="${WW3_BIN_DIR:-${repo_dir}/build-nvhpc/bin}"
mpi_exec="${WW3_MPIEXEC:-mpirun}"
nproc="${WW3_TEST_NPROC:-1}"
run_id="${WW3_TEST_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)_$$}"

case "${run_id}" in
  ""|*/*|*..*)
    echo "ERROR: WW3_TEST_RUN_ID must be a simple directory-name component." >&2
    exit 2
    ;;
esac
case "${nproc}" in
  ""|*[!0-9]*|0)
    echo "ERROR: WW3_TEST_NPROC must be a positive integer." >&2
    exit 2
    ;;
esac

work_dir="${case_dir}/work_nvhpc_uost_${run_id}"
if [[ -e "${work_dir}" ]]; then
  echo "ERROR: test directory already exists: ${work_dir}" >&2
  echo "Set a different WW3_TEST_RUN_ID and retry." >&2
  exit 1
fi

for program in ww3_grid ww3_strt ww3_shel ww3_ounf; do
  if [[ ! -x "${bin_dir}/${program}" ]]; then
    echo "ERROR: executable was not found: ${bin_dir}/${program}" >&2
    echo "Set WW3_BIN_DIR to the directory containing the WW3 load modules." >&2
    exit 1
  fi
done
if [[ "${mpi_exec}" != "none" ]]; then
  mpi_exec_path="$(command -v "${mpi_exec}")" || {
    echo "ERROR: MPI launcher was not found: ${mpi_exec}" >&2
    echo "Set WW3_MPIEXEC to the MPI launcher command." >&2
    exit 1
  }
else
  mpi_exec_path="none"
fi

run_program() {
  local ranks="$1"
  local log_file="$2"
  local program="$3"
  local status
  if [[ "${mpi_exec_path}" == "none" ]]; then
    if "${bin_dir}/${program}" > "${log_file}" 2>&1; then
      return 0
    else
      status=$?
    fi
  else
    if "${mpi_exec_path}" -np "${ranks}" "${bin_dir}/${program}" > "${log_file}" 2>&1; then
      return 0
    else
      status=$?
    fi
  fi

  {
    echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "status=failed"
    echo "failed_program=${program}"
    echo "failed_exit_code=${status}"
  } >> run-metadata.txt
  echo "ERROR: ${program} failed with exit code ${status}" >&2
  echo "  log: ${work_dir}/${log_file}" >&2
  echo "--- ${program} log tail -------------------------------------------" >&2
  tail -n 40 "${log_file}" >&2 || true
  echo "-----------------------------------------------------------------" >&2
  exit "${status}"
}

mkdir "${work_dir}"
ln -s "${input_dir}/ww3_grid.nml" "${work_dir}/ww3_grid.nml"
ln -s "${input_dir}/ww3_strt.inp" "${work_dir}/ww3_strt.inp"
ln -s "${input_dir}/ww3_shel.nml" "${work_dir}/ww3_shel.nml"
ln -s "${input_dir}/ww3_ounf.nml" "${work_dir}/ww3_ounf.nml"

export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"

started_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
started_epoch="$(date +%s)"
{
  echo "case=ww3_ts4/input_rg_shel"
  echo "started_utc=${started_utc}"
  echo "bin_dir=${bin_dir}"
  echo "mpi_exec=${mpi_exec_path}"
  echo "prepost_nproc=1"
  echo "nproc=${nproc}"
  echo "omp_num_threads=${OMP_NUM_THREADS}"
} > "${work_dir}/run-metadata.txt"

echo "Running NVHPC UOST smoke test"
echo "  binaries : ${bin_dir}"
echo "  work     : ${work_dir}"
if [[ "${mpi_exec}" == "none" ]]; then
  echo "  MPI      : direct execution"
else
  echo "  launcher : ${mpi_exec_path}"
  echo "  MPI      : pre/post -np 1, ww3_shel -np ${nproc}"
fi

cd "${work_dir}"

echo "[1/4] ww3_grid"
run_program 1 ww3_grid.out ww3_grid

echo "[2/4] ww3_strt"
run_program 1 ww3_strt.out ww3_strt

echo "[3/4] ww3_shel"
run_program "${nproc}" ww3_shel.out ww3_shel

echo "[4/4] ww3_ounf"
run_program 1 ww3_ounf.out ww3_ounf

finished_epoch="$(date +%s)"
{
  echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "elapsed_seconds=$((finished_epoch - started_epoch))"
  echo "status=completed"
} >> run-metadata.txt

echo "Test execution completed. Check the result with:"
printf "  '%s' '%s'\n" "${script_dir}/check_nvhpc_uost_test.sh" "${work_dir}"
