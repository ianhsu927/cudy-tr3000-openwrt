#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET="$ROOT/openwrt/bin/targets/mediatek/filogic"
OUTPUT="$ROOT/output"
mkdir -p "$OUTPUT"
shopt -s nullglob
# Exact suffixes avoid collecting 256MB or U-Boot-modified-layout images.
images=("$TARGET"/*-cudy_tr3000-v1-squashfs-sysupgrade.bin)
manifests=("$TARGET"/*-cudy_tr3000-v1.manifest)
(( ${#images[@]} == 1 )) || { echo 'Expected exactly one TR3000 v1 sysupgrade image'; exit 1; }
(( ${#manifests[@]} == 1 )) || { echo 'Expected exactly one TR3000 v1 manifest'; exit 1; }
for package in kernel luci luci-ssl luci-theme-bootstrap luci-theme-argon luci-app-argon-config luci-app-passwall xray-core luci-app-usb-tethering luci-app-net-doctor luci-app-sqm sqm-scripts kmod-ifb kmod-sched-core kmod-sched-cake luci-app-nlbwmon nlbwmon kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware; do
  grep -q "^${package} - " "${manifests[0]}" || { echo "Required package missing from firmware: $package"; exit 1; }
done
if grep -Eq '^luci-app-openclash - ' "${manifests[0]}"; then
  echo 'OpenClash unexpectedly included'
  exit 1
fi
if grep -Eq '^luci-app-tr3600-(manager|led|fan) - ' "${manifests[0]}"; then
  echo 'TR3600-specific plugin present in TR3000 firmware'
  exit 1
fi
python3 - "$TARGET/profiles.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    data = json.load(source)
assert data["target"] == "mediatek/filogic", "Unexpected firmware target"
assert set(data["profiles"]) == {"cudy_tr3000-v1"}, "Unexpected device profiles"
assert any(image["type"] == "sysupgrade" for image in data["profiles"]["cudy_tr3000-v1"]["images"]), "Missing sysupgrade metadata"
PY
cp "${images[@]}" "${manifests[@]}" "$TARGET/profiles.json" "$OUTPUT/"
recovery_images=("$TARGET"/*-cudy_tr3000-v1-initramfs-kernel.bin)
if (( ${#recovery_images[@]} > 0 )); then
  cp "${recovery_images[@]}" "$OUTPUT/"
fi
# Archive only packages actually built in this run, with the same kernel ABI.
tar -czf "$OUTPUT/matching-packages.tar.gz" -C "$ROOT/openwrt/bin" targets/mediatek/filogic/packages packages
(
  cd "$OUTPUT"
  sha256sum ./*.bin matching-packages.tar.gz > sha256sums
)
