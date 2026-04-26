#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: publish-apt-pages.sh <repo-root> <debs-dir> <bootstrap-zip-or-empty>" >&2
  exit 64
fi

repo_root="$(realpath "$1")"
debs_dir="$(realpath "$2")"
bootstrap_zip="$3"

pool_dir="$repo_root/pool/main"
binary_dir="$repo_root/dists/stable/main/binary-aarch64"
release_file="$repo_root/dists/stable/Release"
bootstrap_dir="$repo_root/artifacts/bootstrap"

mkdir -p "$pool_dir" "$binary_dir" "$bootstrap_dir"

if compgen -G "$debs_dir/*.deb" >/dev/null; then
  cp -f "$debs_dir"/*.deb "$pool_dir/"
else
  echo "No .deb files found in $debs_dir" >&2
  exit 1
fi

if [ -n "$bootstrap_zip" ] && [ -f "$bootstrap_zip" ]; then
  cp -f "$bootstrap_zip" "$bootstrap_dir/kembriq-runtime-base-aarch64.zip"
  bootstrap_sha256="$(sha256sum "$bootstrap_dir/kembriq-runtime-base-aarch64.zip" | awk '{print $1}')"
  bootstrap_size="$(stat -c%s "$bootstrap_dir/kembriq-runtime-base-aarch64.zip")"
  bootstrap_version="$(date -u +%Y.%m.%d.%H%M%S)"
  echo "$bootstrap_sha256  kembriq-runtime-base-aarch64.zip" > "$bootstrap_dir/kembriq-runtime-base-aarch64.zip.sha256"
  cat > "$bootstrap_dir/kembriq-runtime-base-aarch64.json" <<EOF
{
  "id": "kembriq-runtime-base",
  "version": "$bootstrap_version",
  "abi": "arm64-v8a",
  "packageName": "com.kembriq.code",
  "prefix": "/data/data/com.kembriq.code/files/usr",
  "format": "termux-bootstrap-zip",
  "url": "https://kembriq.github.io/kembriq-runtime-apt/artifacts/bootstrap/kembriq-runtime-base-aarch64.zip",
  "sha256": "$bootstrap_sha256",
  "sizeBytes": $bootstrap_size,
  "expectedFiles": ["bin/apt", "bin/dpkg", "bin/bash"]
}
EOF
fi

(
  cd "$repo_root"
  dpkg-scanpackages --multiversion pool /dev/null > "$binary_dir/Packages"
  gzip -9cn "$binary_dir/Packages" > "$binary_dir/Packages.gz"
)

write_hash_block() {
  local algo="$1"
  local cmd="$2"
  echo "$algo:"
  for file in "main/binary-aarch64/Packages" "main/binary-aarch64/Packages.gz"; do
    local full="$repo_root/dists/stable/$file"
    local hash
    local size
    hash="$($cmd "$full" | awk '{print $1}')"
    size="$(stat -c%s "$full")"
    printf ' %s %16s %s\n' "$hash" "$size" "$file"
  done
}

{
  echo "Origin: Kembriq"
  echo "Label: Kembriq Runtime"
  echo "Suite: stable"
  echo "Codename: stable"
  echo "Version: 1.0"
  echo "Architectures: aarch64"
  echo "Components: main"
  echo "Description: Kembriq Runtime package repository"
  echo "Date: $(date -Ru)"
  write_hash_block "MD5Sum" "md5sum"
  write_hash_block "SHA1" "sha1sum"
  write_hash_block "SHA256" "sha256sum"
} > "$release_file"

echo "Published APT metadata in $repo_root."
