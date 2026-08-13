#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 MODEL-DIRECTORY PROGRAM [...]" >&2
  exit 2
fi

model_dir="$(cd "$1" && pwd)"
shift
programs=("$@")

for program in "${programs[@]}"; do
  case "${program}" in
    ""|*/*|*..*|*[!A-Za-z0-9_.-]*)
      echo "ERROR: invalid WW3 program name: ${program}" >&2
      exit 2
      ;;
  esac
done

is_selected() {
  local candidate="$1"
  local selected
  for selected in "${programs[@]}"; do
    [[ "${candidate}" != "${selected}" ]] || return 0
  done
  return 1
}

# The compiler-specific exe directory can contain load modules from an older
# unrestricted build.  Keep only the explicitly requested WW3 programs so an
# old executable cannot be mistaken for a product of this build.
shopt -s nullglob
for executable in \
  "${model_dir}/exe"/ww3_* \
  "${model_dir}/exe"/gx_* \
  "${model_dir}/exe"/libww3*
do
  name="$(basename "${executable}")"
  is_selected "${name}" || rm -f "${executable}"
done
shopt -u nullglob

# w3_make recreates entries for the requested targets.  Removing the old index
# prevents removed programs from remaining recorded as current products.
rm -f "${model_dir}/exe/exec_type"

echo "Selected WW3 load modules: ${programs[*]}"
