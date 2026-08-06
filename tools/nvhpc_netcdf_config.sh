#!/usr/bin/env bash
set -euo pipefail

nc_config="${WW3_LEGACY_NC_CONFIG:-}"
nf_config="${WW3_LEGACY_NF_CONFIG:-}"

if [[ -z "${nc_config}" || ! -x "${nc_config}" ]]; then
  echo "ERROR: WW3_LEGACY_NC_CONFIG must name an executable nc-config." >&2
  exit 1
fi
if [[ -z "${nf_config}" || ! -x "${nf_config}" ]]; then
  echo "ERROR: WW3_LEGACY_NF_CONFIG must name an executable nf-config." >&2
  exit 1
fi
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 OPTION" >&2
  exit 2
fi

case "$1" in
  --fc) "${nf_config}" --fc ;;
  --cflags) "${nf_config}" --fflags ;;
  --flibs) "${nf_config}" --flibs ;;
  --libs) "${nc_config}" --libs ;;
  *) "${nc_config}" "$1" ;;
esac
