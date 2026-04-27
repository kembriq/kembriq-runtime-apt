#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: sanitize-kembriq-artifacts.sh <artifact-path>..." >&2
  exit 64
fi

blocked_regex='(/data/data/com\.termux|/data/user/[0-9]+/com\.termux|com\.termux)'
work_root="$(mktemp -d)"
trap 'rm -rf "$work_root"' EXIT

sanitize_tree() {
  local dir="$1"
  local matches
  matches="$(mktemp)"
  grep -R -I -l -E "$blocked_regex" "$dir" > "$matches" 2>/dev/null || true
  if [ -s "$matches" ]; then
    xargs -r sed -i -E \
      -e 's|/data/data/com\.termux|/data/data/com.kembriq.code|g' \
      -e 's|/data/user/[0-9]+/com\.termux|/data/user/0/com.kembriq.code|g' \
      -e 's|com\.termux|com.kembriq.code|g' < "$matches"
    rm -f "$matches"
    return 0
  fi
  rm -f "$matches"
  return 1
}

fix_deb_control_permissions() {
  local pkg_dir="$1"
  local control_dir="$pkg_dir/DEBIAN"
  local script
  [ -d "$control_dir" ] || return 0

  for script in preinst postinst prerm postrm config; do
    if [ -f "$control_dir/$script" ]; then
      chmod 0755 "$control_dir/$script"
    fi
  done
}

for artifact in "$@"; do
  [ -e "$artifact" ] || continue
  case "$artifact" in
    *.deb)
      work="$work_root/$(basename "$artifact").d"
      mkdir -p "$work/pkg"
      dpkg-deb -R "$artifact" "$work/pkg"
      if sanitize_tree "$work/pkg"; then
        rebuilt="$work/$(basename "$artifact")"
        fix_deb_control_permissions "$work/pkg"
        dpkg-deb -Zxz -b "$work/pkg" "$rebuilt" >/dev/null
        mv -f "$rebuilt" "$artifact"
        echo "Sanitized text references in $(basename "$artifact")."
      fi
      ;;
    *.zip)
      work="$work_root/$(basename "$artifact").z"
      mkdir -p "$work/zip"
      unzip -q "$artifact" -d "$work/zip"
      if sanitize_tree "$work/zip"; then
        rebuilt="$work/$(basename "$artifact")"
        (
          cd "$work/zip"
          zip -qry "$rebuilt" .
        )
        mv -f "$rebuilt" "$artifact"
        echo "Sanitized text references in $(basename "$artifact")."
      fi
      ;;
  esac
done
