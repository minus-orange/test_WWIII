#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 MODEL-DIRECTORY COMPILER-ID" >&2
  exit 2
fi

model_dir="$(cd "$1" && pwd)"
compiler_id="$2"
case "${compiler_id}" in
  ""|*/*|*..*|*[!A-Za-z0-9_.-]*)
    echo "ERROR: compiler ID must be a simple path component: ${compiler_id}" >&2
    exit 2
    ;;
esac

state_root="${WW3_LEGACY_STATE_ROOT:-${model_dir}/.legacy-builds}"
compiler_root="${state_root}/${compiler_id}"
mkdir -p "${compiler_root}"

# A checkout produced before compiler-specific trees were introduced can have
# real directories at the standard WW3 paths.  Preserve them as an unclassified
# build instead of guessing which compiler created their objects and modules.
quarantine_root=""
select_path() {
  local name="$1"
  local public_path="${model_dir}/${name}"
  local private_path="${compiler_root}/${name}"
  local link_target="${private_path}"

  mkdir -p "${private_path}"

  if [[ -L "${public_path}" ]]; then
    if [[ "$(readlink "${public_path}")" == "${link_target}" ]]; then
      return
    fi
    rm "${public_path}"
  elif [[ -e "${public_path}" ]]; then
    if [[ ! -d "${public_path}" ]]; then
      echo "ERROR: expected a directory at ${public_path}" >&2
      exit 1
    fi
    if [[ -z "${quarantine_root}" ]]; then
      quarantine_root="${state_root}/unclassified-$(date -u +%Y%m%dT%H%M%SZ)-$$"
      mkdir -p "${quarantine_root}"
      echo "Preserving pre-existing legacy artifacts in ${quarantine_root}"
    fi
    mv "${public_path}" "${quarantine_root}/${name}"
  fi

  ln -s "${link_target}" "${public_path}"
}

select_path exe
for execution_type in SEQ OMP MPI HYB; do
  select_path "obj_${execution_type}"
  select_path "mod_${execution_type}"
done

printf '%s\n' "${compiler_id}" > "${state_root}/active-compiler"
echo "Selected compiler-specific WW3 build tree"
echo "  compiler : ${compiler_id}"
echo "  state    : ${compiler_root}"
echo "  LM       : ${compiler_root}/exe"
