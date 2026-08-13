#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 MODEL-DIRECTORY oneapi|oneapi_debug" >&2
  exit 2
fi

model_dir="$(cd "$1" && pwd)"
compiler_name="$2"
bin_dir="${model_dir}/bin"

case "${compiler_name}" in
  oneapi|oneapi_debug) ;;
  *)
    echo "ERROR: unsupported Intel oneAPI compiler setting: ${compiler_name}" >&2
    exit 2
    ;;
esac

for template in comp.tmpl link.tmpl ad3.tmpl; do
  if [[ ! -r "${bin_dir}/${template}" ]]; then
    echo "ERROR: WW3 template was not found: ${bin_dir}/${template}" >&2
    exit 1
  fi
done

comp_seq="ifx"
comp_mpi="${WW3_ONEAPI_MPIFC:-mpiifx}"
optc='-c -module $path_m -g -i4 -real-size 32 -fp-model precise -assume byterecl -fno-alias -traceback'
optl='-o $prog -g -traceback'
optomp='-qopenmp'
err_pattern='error #[0-9]'
warn_pattern='warning #[0-9]'
endian='big_endian'

if [[ "${compiler_name}" == "oneapi_debug" ]]; then
  optc="${optc} -O0 -check all -warn all -fpe0"
  optl="${optl} -O0"
else
  optc="${optc} -O3 -xHost"
  optl="${optl} -O3 -xHost"
fi

sed -e "s/<optc>/${optc}/" \
  -e "s/<comp_seq>/${comp_seq}/" \
  -e "s/<comp_mpi>/${comp_mpi}/" \
  -e "s/<optomp>/${optomp}/" \
  -e "s/<err_pattern>/${err_pattern}/" \
  -e "s/<warn_pattern>/${warn_pattern}/" \
  "${bin_dir}/comp.tmpl" > "${bin_dir}/comp.${compiler_name}"

sed -e "s/<optl>/${optl}/" \
  -e "s/<comp_seq>/${comp_seq}/" \
  -e "s/<comp_mpi>/${comp_mpi}/" \
  -e "s/<optomp>/${optomp}/" \
  "${bin_dir}/link.tmpl" > "${bin_dir}/link.${compiler_name}"

sed -e "s/<comp_seq>/${comp_seq}/" \
  -e 's/<cppad3procflag>/-E/' \
  -e 's/<cppad3flag2>/ /' \
  -e 's/<cppad3flag3>/>/' \
  -e 's/<cppad3flag4>/#/' \
  -e "s/<endian>/${endian}/" \
  "${bin_dir}/ad3.tmpl" > "${bin_dir}/ad3.${compiler_name}"

chmod 775 \
  "${bin_dir}/comp.${compiler_name}" \
  "${bin_dir}/link.${compiler_name}" \
  "${bin_dir}/ad3.${compiler_name}"

echo "Prepared Intel oneAPI WW3 compiler drivers"
echo "  ${bin_dir}/comp.${compiler_name}"
echo "  ${bin_dir}/link.${compiler_name}"
echo "  ${bin_dir}/ad3.${compiler_name}"
