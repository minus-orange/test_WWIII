#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
upstream_import="fa77b2e926bca8e1b4dd72ddd5f8ff0b2cfefad6"
previous_kit_commits=(
  e959cfbd436a1a00652b0d4aafd350ba79d6802b
  52c6b8178a1c4262bcc3e39f0bd0c807371e8431
  cfdb8daf2aa21aa32bac1bbd9395c67287492385
  fcca6fb4595e8c6d7bfe03965fff5ecc83631f63
  3e535853ea8879a8ae60fcc0ef1a883e636400cc
  0565dd31a6f8826eb2003eae85ef49ab9be7f45d
)

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 OUTPUT_DIRECTORY" >&2
  exit 2
fi
output="$1"
if [[ -e "${output}" ]]; then
  echo "ERROR: output already exists: ${output}" >&2
  exit 1
fi
mkdir -p "${output}/patches" "${output}/files/common/tools" \
  "${output}/files/common/model/bin" "${output}/files/common/docs/ja" \
  "${output}/files/common/model/src" \
  "${output}/files/legacy/tools"
output="$(cd "${output}" && pwd)"

git -C "${repo_dir}" cat-file -e "${upstream_import}^{commit}"
[[ "$(tr -d '[:space:]' < "${repo_dir}/VERSION")" == "7.14" ]] || {
  echo "ERROR: source repository is not WW3 7.14." >&2
  exit 1
}

cp "${script_dir}/nvhpc_kit_install.sh" "${output}/install.sh"
cp "${repo_dir}/docs/ja/nvhpc_build_kit.md" "${output}/README.md"

common_files=(
  tools/download_nvhpc_libraries.sh
  tools/build_nvhpc_libraries.sh
  tools/nvhpc_library_versions.sh
  tools/check_netcdf.f90
  tools/run_nvhpc_uost_test.sh
  tools/check_nvhpc_uost_test.sh
  tools/select_legacy_build_tree.sh
  tools/prepare_legacy_program_set.sh
)
legacy_files=(
  tools/build_nvhpc_legacy.sh
  tools/nvhpc_netcdf_config.sh
)
required_patch_files=(
  model/bin/ad3.tmpl
  model/bin/build_utils.sh
  model/bin/cmplr.env
  model/bin/link.tmpl
  model/bin/make_makefile.sh
  model/bin/w3_make
  model/bin/w3_setup
  model/src/ww3_shel.F90
  model/src/w3wavemd.F90
)
for file in "${common_files[@]}"; do
  cp "${repo_dir}/${file}" "${output}/files/common/${file}"
done
cp "${repo_dir}/model/bin/switch_ST4_UOST" \
  "${output}/files/common/model/bin/switch_ST4_UOST"
cp "${repo_dir}/model/bin/switch_ST4_UOST_SHRD" \
  "${output}/files/common/model/bin/switch_ST4_UOST_SHRD"
cp "${repo_dir}/model/src/mod_timer.F90" \
  "${output}/files/common/model/src/mod_timer.F90"
cp "${repo_dir}/docs/ja/nvhpc_build_kit.md" \
  "${output}/files/common/docs/ja/nvhpc_build_kit.md"
cp "${repo_dir}/docs/ja/nvhpc_timer.md" \
  "${output}/files/common/docs/ja/nvhpc_timer.md"

cp "${repo_dir}/tools/build_nvhpc_legacy.sh" \
  "${output}/files/legacy/tools/build_nvhpc_legacy.sh"
cp "${repo_dir}/tools/nvhpc_netcdf_config.sh" \
  "${output}/files/legacy/tools/nvhpc_netcdf_config.sh"

git -C "${repo_dir}" diff --binary "${upstream_import}" HEAD -- \
  model/src/w3gridmd.F90 \
  > "${output}/patches/optional-w3grid-uost-ww3-7.14.patch"
git -C "${repo_dir}" diff --binary "${upstream_import}" HEAD -- \
  model/src/ww3_sbs1.F90 \
  > "${output}/patches/optional-ww3-sbs1-ww3-7.14.patch"
git -C "${repo_dir}" diff --binary "${upstream_import}" HEAD -- \
  "${required_patch_files[@]}" \
  > "${output}/patches/legacy-ww3-7.14.patch"

chmod +x "${output}/install.sh"
find "${output}/files" -path '*/tools/*.sh' -exec chmod +x {} +

current_commit="$(git -C "${repo_dir}" rev-parse HEAD)"
{
  echo "kit_format=1"
  echo "ww3_version=7.14"
  echo "upstream_commit=c3b0d04d0d632641dab2dde7f053f4ab3ee35043"
  echo "source_import_commit=${upstream_import}"
  echo "source_repository_commit=${current_commit}"
} > "${output}/SOURCE.txt"

if command -v sha256sum >/dev/null 2>&1; then
  checksum_command=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  checksum_command=(shasum -a 256)
else
  echo "ERROR: sha256sum or shasum is required." >&2
  exit 1
fi

# A current kit can safely upgrade source/support files installed by these
# published earlier kits.  Custom user edits still require an explicit review
# and --force for overlays; source patches are never forced.
for previous_commit in "${previous_kit_commits[@]}"; do
  git -C "${repo_dir}" cat-file -e "${previous_commit}^{commit}"
  previous_short="$(git -C "${repo_dir}" rev-parse --short=8 "${previous_commit}")"
  upgrade_patch="${output}/patches/upgrade-${previous_short}-to-current.patch"
  git -C "${repo_dir}" diff --binary "${previous_commit}" HEAD -- \
    "${required_patch_files[@]}" > "${upgrade_patch}"
  [[ -s "${upgrade_patch}" ]] || rm -f "${upgrade_patch}"
done

known_overlay_manifest="${output}/KNOWN_OVERLAY_SHA256SUMS"
: > "${known_overlay_manifest}"
overlay_files=(
  "${common_files[@]}"
  "${legacy_files[@]}"
  model/bin/switch_ST4_UOST
  model/bin/switch_ST4_UOST_SHRD
  model/src/mod_timer.F90
  docs/ja/nvhpc_build_kit.md
  docs/ja/nvhpc_timer.md
)
for previous_commit in "${previous_kit_commits[@]}"; do
  for file in "${overlay_files[@]}"; do
    if git -C "${repo_dir}" cat-file -e "${previous_commit}:${file}" 2>/dev/null; then
      file_hash="$(git -C "${repo_dir}" show "${previous_commit}:${file}" | \
        "${checksum_command[@]}" | awk '{print $1}')"
      printf '%s  %s\n' "${file_hash}" "${file}" >> "${known_overlay_manifest}"
    fi
  done
done
sort -u "${known_overlay_manifest}" -o "${known_overlay_manifest}"

(cd "${output}" && find . -type f ! -name SHA256SUMS -print0 | sort -z | \
  xargs -0 "${checksum_command[@]}" > SHA256SUMS)

archive="${output}.tar.gz"
# Use ustar and disable macOS copyfile metadata so Linux tar does not create
# AppleDouble (._*) files or warn about LIBARCHIVE.xattr headers.
COPYFILE_DISABLE=1 tar --format ustar -czf "${archive}" \
  -C "$(dirname "${output}")" "$(basename "${output}")"
echo "NVHPC build kit created"
echo "  directory : ${output}"
echo "  archive   : ${archive}"
echo "  install   : ${output}/install.sh /path/to/WW3"
