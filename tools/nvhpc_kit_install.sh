#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kit_dir="${script_dir}"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--force] WW3_SOURCE_DIR

Install the portable NVIDIA HPC SDK legacy build support into a WW3 7.14 source
tree. --force only permits replacement of differing support files; it never
forces a source patch that does not apply cleanly.
EOF
}

force="no"
target=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force="yes"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -* )
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      [[ -z "${target}" ]] || { echo "ERROR: specify one WW3 source directory." >&2; exit 2; }
      target="$1"
      shift
      ;;
  esac
done

[[ -n "${target}" ]] || { usage >&2; exit 2; }
[[ -d "${target}" ]] || { echo "ERROR: directory not found: ${target}" >&2; exit 1; }
target="$(cd "${target}" && pwd)"

is_ww3_root() {
  [[ -f "$1/VERSION" && -d "$1/model/bin" && -d "$1/model/src" ]]
}

if ! is_ww3_root "${target}"; then
  candidates=()
  while IFS= read -r -d '' version_file; do
    candidate="$(dirname "${version_file}")"
    if is_ww3_root "${candidate}"; then
      candidates+=("${candidate}")
    fi
  done < <(find "${target}" -mindepth 1 -maxdepth 4 -type f -name VERSION -print0)

  if [[ ${#candidates[@]} -eq 1 ]]; then
    echo "Detected nested WW3 source root: ${candidates[0]}"
    target="${candidates[0]}"
  else
    echo "ERROR: WW3 source root must contain VERSION, model/bin, and model/src." >&2
    echo "  specified: ${target}" >&2
    echo "  VERSION files found:" >&2
    find "${target}" -maxdepth 4 -type f -name VERSION -print 2>/dev/null | sed -n '1,5p' >&2
    echo "  w3_setup files found:" >&2
    find "${target}" -maxdepth 6 -type f -name w3_setup -print 2>/dev/null | sed -n '1,5p' >&2
    echo "Specify the directory immediately above VERSION and model/." >&2
    exit 1
  fi
fi
version="$(tr -d '[:space:]' < "${target}/VERSION")"
if [[ "${version}" != "7.14" ]]; then
  echo "ERROR: this kit targets WW3 7.14 (target reports '${version}')." >&2
  echo "Create a kit for that source version instead of forcing this patch." >&2
  exit 1
fi
command -v git >/dev/null 2>&1 || {
  echo "ERROR: git is required to check and apply the source patches." >&2
  exit 1
}
if command -v sha256sum >/dev/null 2>&1; then
  (cd "${kit_dir}" && sha256sum -c SHA256SUMS >/dev/null)
elif command -v shasum >/dev/null 2>&1; then
  (cd "${kit_dir}" && shasum -a 256 -c SHA256SUMS >/dev/null)
else
  echo "ERROR: sha256sum or shasum is required to verify the build kit." >&2
  exit 1
fi

patches=(
  "patches/common-ww3-7.14.patch"
  "patches/legacy-ww3-7.14.patch"
)
overlays=("files/common" "files/legacy")

declare -a patch_actions=()
for relative_patch in "${patches[@]}"; do
  patch_file="${kit_dir}/${relative_patch}"
  [[ -s "${patch_file}" ]] || { echo "ERROR: missing patch: ${patch_file}" >&2; exit 1; }
  if (cd "${target}" && git apply --check "${patch_file}" >/dev/null 2>&1); then
    patch_actions+=("apply")
  elif (cd "${target}" && git apply --reverse --check "${patch_file}" >/dev/null 2>&1); then
    patch_actions+=("skip")
  else
    echo "ERROR: patch does not apply cleanly: ${relative_patch}" >&2
    echo "The target may be a different WW3 revision or contain overlapping edits." >&2
    (cd "${target}" && git apply --check "${patch_file}") || true
    echo "No source patches or support files were changed." >&2
    exit 1
  fi
done

declare -a overlay_sources=()
declare -a overlay_destinations=()
for overlay in "${overlays[@]}"; do
  while IFS= read -r -d '' source_file; do
    relative_file="${source_file#${kit_dir}/${overlay}/}"
    destination="${target}/${relative_file}"
    if [[ -e "${destination}" ]] && ! cmp -s "${source_file}" "${destination}" && [[ "${force}" != "yes" ]]; then
      echo "ERROR: support file already exists with different content: ${destination}" >&2
      echo "Review it first, or repeat with --force to replace support files." >&2
      echo "No source patches or support files were changed." >&2
      exit 1
    fi
    overlay_sources+=("${source_file}")
    overlay_destinations+=("${destination}")
  done < <(find "${kit_dir}/${overlay}" -type f -print0 | sort -z)
done

for index in "${!patches[@]}"; do
  if [[ "${patch_actions[$index]}" == "apply" ]]; then
    echo "Applying ${patches[$index]}"
    (cd "${target}" && git apply "${kit_dir}/${patches[$index]}")
  else
    echo "Already applied: ${patches[$index]}"
  fi
done

for index in "${!overlay_sources[@]}"; do
  mkdir -p "$(dirname "${overlay_destinations[$index]}")"
  cp "${overlay_sources[$index]}" "${overlay_destinations[$index]}"
done

echo "NVHPC build support installed"
echo "  target : ${target}"
echo "  build  : WW3 legacy (w3_setup + w3_make; no CMake for WW3)"
echo "Next: read ${target}/docs/ja/nvhpc_build_kit.md"
