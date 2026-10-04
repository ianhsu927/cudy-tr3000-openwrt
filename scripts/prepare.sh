#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$ROOT/output"
git clone --depth 1 --branch openwrt-25.12 https://github.com/openwrt/openwrt.git "$ROOT/openwrt"
cd "$ROOT/openwrt"
# TR3000 v1 (128MB, stock partition layout) is supported by this branch.
# Do not apply TR3600 device, fan, LED, MAC or wireless-default patches.
grep -Fxq 'TARGET_DEVICES += cudy_tr3000-v1' target/linux/mediatek/image/filogic.mk
./scripts/feeds update -a
./scripts/feeds install -a
git clone --depth 1 https://github.com/vernesong/OpenClash.git "$ROOT/OpenClash"
cp -a "$ROOT/OpenClash/luci-app-openclash" package/
./scripts/feeds uninstall luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
./scripts/feeds uninstall luci-app-argon-config
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

# These two packages are device-independent. Keep the reference revisions.
custom_sources="$ROOT/output/custom-plugin-sources.txt"
: > "$custom_sources"
add_custom_package() {
  local repo=$1 revision=$2 subdir=$3 name=$4 source
  source="$ROOT/custom-plugins/$name"
  mkdir -p "$source"
  git -C "$source" init -q
  git -C "$source" remote add origin "https://github.com/ianhsu927/$repo.git"
  git -C "$source" fetch --depth 1 origin "$revision"
  git -C "$source" checkout --detach FETCH_HEAD
  test "$(git -C "$source" rev-parse HEAD)" = "$revision"
  test -f "$source/$subdir/Makefile"
  mkdir -p "package/$name"
  tar -C "$source/$subdir" --exclude=.git -cf - . | tar -C "package/$name" -xf -
  printf '%s: %s (%s)\n' "$name" "$revision" "$repo" >> "$custom_sources"
}
add_custom_package luci-app-usb-tethering a752832a17261a6ccf2474defa6b3e5d7848427b luci-app-usb-tethering luci-app-usb-tethering
add_custom_package luci-app-net-doctor be42a485885ae112759702556d9961228559103c . luci-app-net-doctor

# Bundle the same ARM64 Meta core distributed by OpenClash.
mkdir -p files/etc/openclash/core
core_revision=$(git ls-remote https://github.com/vernesong/OpenClash.git refs/heads/core | awk '{print $1}')
[[ "$core_revision" =~ ^[0-9a-f]{40}$ ]] || { echo 'Cannot resolve OpenClash core revision'; exit 1; }
core_url="https://raw.githubusercontent.com/vernesong/OpenClash/$core_revision/master/meta/clash-linux-arm64.tar.gz"
curl --fail --location --retry 3 "$core_url" -o "$ROOT/output/openclash-core.tar.gz"
tar -xOzf "$ROOT/output/openclash-core.tar.gz" clash > files/etc/openclash/core/clash_meta
test -s files/etc/openclash/core/clash_meta
file files/etc/openclash/core/clash_meta | grep -q 'ELF 64-bit.*ARM aarch64'
chmod 0755 files/etc/openclash/core/clash_meta
{
  printf 'OpenClash core revision: %s\n' "$core_revision"
  printf 'OpenClash core URL: %s\n' "$core_url"
  sha256sum "$ROOT/output/openclash-core.tar.gz" files/etc/openclash/core/clash_meta
} > "$ROOT/output/openclash-core.txt"
rm "$ROOT/output/openclash-core.tar.gz"

{
  printf 'Reference workflow: ianhsu927/cudy-tr3600-openwrt @ 41596930acb13b0f259203de12aa09f50f10eed3\n'
  printf 'Profile: cudy_tr3000-v1 (128MB, stock partition layout)\n'
  printf 'OpenWrt: '; git rev-parse HEAD
  printf 'OpenWrt branch: '; git branch --show-current
  printf 'OpenClash: '; git -C "$ROOT/OpenClash" rev-parse HEAD
  printf 'Argon: '; git -C package/luci-theme-argon rev-parse HEAD
  printf 'Argon config: '; git -C package/luci-app-argon-config rev-parse HEAD
  cat "$custom_sources"
  ./scripts/feeds list -s
} > "$ROOT/output/sources.txt"

cp "$ROOT/config.seed" .config
make defconfig
cp .config "$ROOT/output/build.config"
# Reject dropped dependencies or a different TR3000 flash/bootloader variant.
missing=0
while IFS= read -r setting; do
  case "$setting" in
    CONFIG_*=y)
      grep -Fxq "$setting" .config || {
        echo "Missing required setting: $setting" | tee -a "$ROOT/output/missing-settings.txt"
        missing=1
      }
      ;;
  esac
done < "$ROOT/config.seed"
(( missing == 0 )) || exit 1
mapfile -t devices < <(grep -E '^CONFIG_TARGET_mediatek_filogic_DEVICE_.*=y$' .config)
test "${#devices[@]}" -eq 1
test "${devices[0]}" = 'CONFIG_TARGET_mediatek_filogic_DEVICE_cudy_tr3000-v1=y'
if grep -Eq '^CONFIG_PACKAGE_luci-app-tr3600-(manager|led|fan)=[ym]$' .config; then
  echo 'TR3600-specific package unexpectedly enabled'
  exit 1
fi
