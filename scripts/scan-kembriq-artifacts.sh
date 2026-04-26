#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: scan-kembriq-artifacts.sh <artifact-path>..." >&2
  exit 64
fi

blocked_regex='(/data/data/com\.termux|/data/user/[0-9]+/com\.termux|com\.termux)'
scan_root="$(mktemp -d)"
trap 'rm -rf "$scan_root"' EXIT

scan_dir() {
  local dir="$1"
  if grep -R -a -n -E "$blocked_regex" "$dir" >/tmp/kembriq-runtime-scan.txt 2>/dev/null; then
    echo "Blocked Termux package/path references found:" >&2
    head -n 80 /tmp/kembriq-runtime-scan.txt >&2
    return 1
  fi
}

for artifact in "$@"; do
  [ -e "$artifact" ] || continue
  case "$artifact" in
    *.deb)
      work="$scan_root/$(basename "$artifact").d"
      mkdir -p "$work"
      data_archive="$(ar t "$artifact" | grep -E '^data\.tar\.(xz|gz|zst)$' | head -n 1 || true)"
      if [ -z "$data_archive" ]; then
        echo "No data archive found in $artifact" >&2
        exit 1
      fi
      ar p "$artifact" "$data_archive" > "$work/data.tar"
      case "$data_archive" in
        *.xz) tar -xJf "$work/data.tar" -C "$work" ;;
        *.gz) tar -xzf "$work/data.tar" -C "$work" ;;
        *.zst) tar --use-compress-program=unzstd -xf "$work/data.tar" -C "$work" ;;
      esac
      scan_dir "$work"
      ;;
    *.zip)
      work="$scan_root/$(basename "$artifact").z"
      mkdir -p "$work"
      unzip -q "$artifact" -d "$work"
      scan_dir "$work"
      ;;
    *)
      if [ -d "$artifact" ]; then
        scan_dir "$artifact"
      else
        if grep -a -E "$blocked_regex" "$artifact" >/tmp/kembriq-runtime-scan.txt 2>/dev/null; then
          echo "Blocked Termux package/path references found in $artifact:" >&2
          head -n 80 /tmp/kembriq-runtime-scan.txt >&2
          exit 1
        fi
      fi
      ;;
  esac
done

echo "Artifact scan passed."
