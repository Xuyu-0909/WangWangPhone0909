#!/usr/bin/env bash
set -euo pipefail

# Keep Flutter outside the repository and pin the SDK for reproducible deploys.
# Flutter 3.41.5 includes Dart 3.11.3, matching pubspec.yaml.
readonly flutter_version="3.41.5"
readonly flutter_sha256="18901d456a5e458c4c69fa7859852b64fac29da9f89476a959abfacbac7f4fdb"
readonly flutter_sdk="${HOME}/.cache/wangwang-flutter-${flutter_version}"
readonly repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -x "${flutter_sdk}/bin/flutter" ]]; then
  mkdir -p "$(dirname "${flutter_sdk}")"
  # The deployment environment blocks git clone. Use the official prebuilt SDK
  # and verify its published checksum before extracting it.
  sdk_download_dir="$(mktemp -d "$(dirname "${flutter_sdk}")/flutter-download.XXXXXX")"
  trap 'rm -rf "${sdk_download_dir}"' EXIT
  curl --fail --location --retry 3 \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${flutter_version}-stable.tar.xz" \
    --output "${sdk_download_dir}/flutter.tar.xz"
  printf '%s  %s\n' "${flutter_sha256}" "${sdk_download_dir}/flutter.tar.xz" | sha256sum --check -
  tar -xJf "${sdk_download_dir}/flutter.tar.xz" -C "${sdk_download_dir}"
  mv "${sdk_download_dir}/flutter" "${flutter_sdk}"
fi

export PATH="${flutter_sdk}/bin:${PATH}"
export CI=true
flutter config --no-analytics --enable-web
cd "${repo_root}/wangwang_phone"
flutter pub get --enforce-lockfile
flutter build web --release --pwa-strategy=none
