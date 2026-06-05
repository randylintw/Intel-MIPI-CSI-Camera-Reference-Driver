#!/bin/bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: ${0##*/} [--help|-h] <path> [<path> ...]

Download the kernel source tarball matching the DKMS kernel version and
extract one or more paths from it into the local source tree.

Arguments:
  <path>        One or more paths to extract from the downloaded kernel tarball.

Options:
  -h, --help    Show this help message and exit.

Environment:
  kernelver     Kernel version to use for download/version parsing.
                Defaults to the current kernel from 'uname -r'.
  CLEANUP=1     Remove the downloaded tarball after successful extraction.
EOF
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
  esac
fi

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 1
fi

for tool in wget tar; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: Required tool '$tool' is not installed or not in PATH." >&2
    exit 127
  fi
done

if [[ -z "${kernelver:-}" ]]; then
  kernelver="$(uname -r)"
fi

major=$(echo "$kernelver" | cut -d- -f1 | cut -d. -f1)
minor=$(echo "$kernelver" | cut -d- -f1 | cut -d. -f2)
patch=$(echo "$kernelver" | cut -d- -f1 | cut -d. -f3)

if ! [[ "$major" =~ ^[0-9]+$ ]]; then major=0; fi
if ! [[ "$minor" =~ ^[0-9]+$ ]]; then minor=0; fi
if ! [[ "$patch" =~ ^[0-9]+$ ]]; then patch=0; fi

echo "Downloading major $major minor $minor patch $patch"
if (( patch != 0 )); then
  kernelprefix="linux-$major.$minor.$patch"
else
  kernelprefix="linux-$major.$minor"
fi

archive="${kernelprefix}.tar.xz"
url="https://mirrors.edge.kernel.org/pub/linux/kernel/v${major}.x/${kernelprefix}.tar.xz"

if ! wget --no-check-certificate "$url" -O "$archive"; then
  echo "ERROR: Failed to download kernel source archive from '$url'." >&2
  exit 1
fi

declare -a extracted=()
for arg in "$@"; do
    echo "Extracting: $kernelprefix/$arg"
    tar -xvf "$archive" "$kernelprefix/$arg" \
      --xform="s,^${kernelprefix//./\\.}/,$major.$minor.0/,"
    extracted+=("$major.$minor.0/$arg")
done

if [[ "${CLEANUP:-0}" == "1" ]]; then
  rm -f "$archive"
fi

echo "Extraction summary:"
for path in "${extracted[@]}"; do
  echo "  - $path"
done
