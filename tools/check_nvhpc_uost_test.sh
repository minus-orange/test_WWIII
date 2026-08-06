#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
case_dir="${repo_dir}/regtests/ww3_ts4"
expected_switches="${WW3_EXPECT_SWITCHES:-ST4 UOST}"

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [work-directory]" >&2
  exit 2
fi

if [[ $# -eq 1 ]]; then
  work_dir="$1"
else
  work_dir=""
  for candidate in "${case_dir}"/work_nvhpc_uost_*; do
    [[ -d "${candidate}" ]] || continue
    if [[ -z "${work_dir}" || "${candidate}" -nt "${work_dir}" ]]; then
      work_dir="${candidate}"
    fi
  done
  if [[ -z "${work_dir}" ]]; then
    echo "ERROR: no NVHPC UOST test directory was found." >&2
    echo "Run tools/run_nvhpc_uost_test.sh first." >&2
    exit 1
  fi
fi
requested_work_dir="${work_dir}"
work_dir="$(cd "${work_dir}" 2>/dev/null && pwd)" || {
  echo "ERROR: work directory was not found: ${requested_work_dir}" >&2
  exit 1
}

failures=0
summary="${work_dir}/result-summary.txt"
: > "${summary}"

pass() {
  echo "PASS: $*" >> "${summary}"
}

fail() {
  echo "FAIL: $*" | tee -a "${summary}" >&2
  failures=$((failures + 1))
}

require_file() {
  local file="$1"
  if [[ -s "${work_dir}/${file}" ]]; then
    pass "${file} exists and is not empty"
  else
    fail "${file} is missing or empty"
  fi
}

echo "Checking NVHPC UOST smoke test: ${work_dir}" | tee -a "${summary}"

for file in run-metadata.txt ww3_grid.out ww3_strt.out ww3_shel.out ww3_ounf.out \
  mod_def.ww3 restart.ww3 out_grd.ww3 out_pnt.ww3 log.ww3 ww3.200001.nc; do
  require_file "${file}"
done

if grep -q '^status=completed$' "${work_dir}/run-metadata.txt" 2>/dev/null; then
  pass "run script reached completion"
else
  fail "run script did not record completion"
fi

for program in ww3_grid ww3_strt ww3_shel ww3_ounf; do
  if grep -q 'End of program' "${work_dir}/${program}.out" 2>/dev/null; then
    pass "${program} reported normal termination"
  else
    fail "${program} did not report normal termination"
  fi
done

if grep -Eiq '(^|[^[:alpha:]])(fatal|error|nan|infinity|mpi_abort|segmentation fault)([^[:alpha:]]|$)' \
  "${work_dir}"/*.out "${work_dir}/log.ww3" 2>/dev/null; then
  fail "an abnormal keyword was found in a program log"
else
  pass "no fatal/error/NaN/Infinity keyword was found"
fi

if ! command -v ncdump >/dev/null 2>&1; then
  fail "ncdump is required for NetCDF validation"
elif [[ ! -s "${work_dir}/ww3.200001.nc" ]]; then
  fail "NetCDF validation could not start"
else
  header="$(ncdump -h "${work_dir}/ww3.200001.nc")"
  if grep -Eq 'time = UNLIMITED ; // \(49 currently\)' <<< "${header}" &&
     grep -Eq 'longitude = 13 ;' <<< "${header}" &&
     grep -Eq 'latitude = 12 ;' <<< "${header}" &&
     grep -Eq 'float hs\(time, latitude, longitude\)' <<< "${header}"; then
    pass "NetCDF dimensions are time=49, latitude=12, longitude=13 with hs"
  else
    fail "NetCDF dimensions or hs variable differ from the expected case"
  fi

  for switch_name in ${expected_switches}; do
    if grep -Eq "WAVEWATCH_III_switches.*(^|[[:space:]])${switch_name}([[:space:]]|\")" <<< "${header}"; then
      pass "NetCDF metadata contains switch ${switch_name}"
    else
      fail "NetCDF metadata does not contain switch ${switch_name}"
    fi
  done

  if hs_summary="$(ncdump -v hs "${work_dir}/ww3.200001.nc" | awk '
    /^[[:space:]]*hs =/ { in_data=1 }
    in_data {
      line=$0
      sub(/^[[:space:]]*hs[[:space:]]*=[[:space:]]*/, "", line)
      gsub(/[,;]/, " ", line)
      count=split(line, value, /[[:space:]]+/)
      for (i=1; i<=count; i++) {
        if (value[i] == "" || value[i] == "_") continue
        if (value[i] !~ /^[-+]?[0-9.]+([eE][-+]?[0-9]+)?$/) continue
        number=value[i] + 0
        if (valid == 0 || number < minimum) minimum=number
        if (valid == 0 || number > maximum) maximum=number
        valid++
      }
      if ($0 ~ /;/) in_data=0
    }
    END {
      if (valid == 0 || minimum < 0 || maximum > 64) exit 1
      printf "valid_hs_values=%d hs_min_m=%.7g hs_max_m=%.7g", valid, minimum, maximum
    }
  ')"; then
    pass "Hs values are finite and within [0, 64] m (${hs_summary})"
  else
    fail "Hs contains no valid values or is outside [0, 64] m"
  fi
fi

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1"
  else
    shasum -a 256 "$1"
  fi
}

hash_file="${work_dir}/result-sha256sums.txt"
: > "${hash_file}"
for file in mod_def.ww3 restart.ww3 out_grd.ww3 out_pnt.ww3 ww3.200001.nc; do
  if [[ -s "${work_dir}/${file}" ]]; then
    sha256_file "${work_dir}/${file}" >> "${hash_file}"
  fi
done
pass "result SHA-256 values were written to result-sha256sums.txt"

if [[ "${failures}" -ne 0 ]]; then
  passed="$(grep -c '^PASS:' "${summary}" || true)"
  echo "checks_passed=${passed} checks_failed=${failures}"
  echo "summary=${summary}"
  echo "RESULT: FAIL (${failures} checks failed)" | tee -a "${summary}" >&2
  exit 1
fi

grep '^PASS: Hs values' "${summary}" || true
passed="$(grep -c '^PASS:' "${summary}" || true)"
echo "checks_passed=${passed} checks_failed=0"
echo "summary=${summary}"
echo "RESULT: PASS" | tee -a "${summary}"
