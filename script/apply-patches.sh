#!/bin/bash
#
# Apply patch files (e.g. patches/*.patch) to a source tree.
#
# Usage: script/apply-patches.sh [-d TARGET_DIR] [-p N] [-n] [-R] [-k KERNELVER] [-s] [PATCH_OR_DIR...]
#   -s      with the dkms.conf selection, skip unpacking the kernel sources first
#   -k VER  select the patches dkms.conf would apply for kernel VER (e.g. 7.0.0-foo),
#           in dkms.conf order (default 7.0.0, used when no PATCH_OR_DIR is given)
#   -d DIR  directory to patch (default: current directory)
#   -p N    strip level passed to patch (default: 1)
#   -n      dry run, do not modify files
#   -R      reverse (un-apply) the patches
# A directory argument applies all *.patch files in it, sorted by name.
# Patches that are already applied are skipped; stops on the first failure.
set -euo pipefail

target="."
strip=1
dry=()
rev=0

# Hard-coded default: patches dkms.conf selects for this kernel
kver="7.0.0"
unpack=1
while getopts "d:p:nRk:s" opt; do
  case "$opt" in
    d) target="$OPTARG" ;;
    p) strip="$OPTARG" ;;
    n) dry=(--dry-run) ;;
    R) rev=1 ;;
    k) kver="$OPTARG" ;;
    s) unpack=0 ;;
    *) sed -n '3,15p' "$0" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

patches=()
files=()
if [[ $# -eq 0 ]]; then
  root="$(cd "$(dirname "$0")/.." && pwd)"
  kernelver="$kver"
  PATCH=(); PATCH_MATCH=()
  set +u; source "$root/dkms.conf"; set -u
  for i in "${!PATCH[@]}"; do
    if [[ -z "${PATCH_MATCH[$i]:-}" || "$kver" =~ ${PATCH_MATCH[$i]} ]]; then
      patches+=("$root/patches/${PATCH[$i]}")
    fi
  done
  read -ra words <<<"$POST_ADD"
  files=("${words[@]:1}")
  echo "dkms.conf selects ${#patches[@]} patches for $kver"
fi
for arg in "$@"; do
  if [[ -d "$arg" ]]; then
    while IFS= read -r f; do patches+=("$(realpath "$f")"); done \
      < <(find "$arg" -maxdepth 1 -name '*.patch' | sort)
  elif [[ -f "$arg" ]]; then
    patches+=("$(realpath "$arg")")
  else
    echo "not found: $arg" >&2
    exit 1
  fi
done

cd "$target"

# Unpack the kernel files dkms.conf POST_ADD needs (same as DKMS does).
if [[ -n "${files[*]:-}" && $unpack -eq 1 && $rev -eq 0 ]]; then
  kernelver="$kver" "$root/script/dkms-kernel-source.sh" "${files[@]}"
fi

for p in "${patches[@]}"; do
  name="$(basename "$p")"
  if [[ $rev -eq 1 ]]; then
    if patch -p"$strip" -R --dry-run --silent -s -f < "$p" >/dev/null 2>&1; then
      echo "reverting $name"
      patch -p"$strip" -R "${dry[@]}" < "$p"
    else
      echo "skip (not applied): $name"
    fi
  elif patch -p"$strip" -R --dry-run -s -f < "$p" >/dev/null 2>&1; then
    echo "skip (already applied): $name"
  else
    echo "applying $name"
    if ! patch -p"$strip" --batch "${dry[@]}" < "$p"; then
      echo "FAILED: $name" >&2
      exit 1
    fi
  fi
done
