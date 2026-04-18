# android_kernel_rainx_theloop

LineageOS 23.2 (Android 16) kernel for the **theloop** smart speaker (MediaTek
MT6877).

This repo is a fork of [UN1CA/kernel_samsung_a34x](https://github.com/UN1CA/kernel_samsung_a34x)
with theloop-specific additions. The Samsung Galaxy A34 5G shares enough of
theloop's hardware (SoC, combo chip, DRM/audio paths) that its kernel works on
theloop with a small defconfig overlay. No kernel source changes, just config.

## Branches

- **`sixteen`** — tracks UN1CA upstream unchanged. Used as the base for rebases
  when pulling security updates.
- **`lineage-23.2`** — theloop branch. `sixteen` + 1 commit adding
  `theloop_overlay.config` and theloop build wrapper.

## Layout

```
build_kernel.sh                                         # wrapper
kernel/kernel_device_modules-6.6/
    kernel/configs/theloop_overlay.config               # theloop defconfig overlay
    kernel/configs/mt6877_overlay.config                # (upstream) MT6877 overlay
    ...
```

## Building

Fresh checkout on Ubuntu 22.04, ~50 GB disk free, working internet:

```bash
git clone https://github.com/LosSantosPro/android_kernel_rainx_theloop.git
cd android_kernel_rainx_theloop
git checkout lineage-23.2
./build_kernel.sh
```

The wrapper is idempotent. It will:

1. Install `repo` if not already present.
2. `repo sync` the AOSP `common-android15-6.6` kernel manifest into `aosp-kernel/`.
3. Download Clang r536225 prebuilt.
4. Patch Kleaf build configs for reproducible builds (SOURCE_DATE_EPOCH,
   strip `-maybe-dirty`, pin clang version).
5. Run `build.sh` (Bazel) with `theloop_overlay.config` appended to the
   defconfig overlay stack.

Outputs land in `out/target/product/a34x/obj/KLEAF_OBJ/dist/`:

- `Image.gz`
- `dtb.img`
- `dtbo.img`
- ~200 `.ko` modules

Expected vermagic:
`6.6.127-android15-8-abogkiA346BXXSEEZB6-4k SMP preempt mod_unload modversions aarch64`

## Integrating with the device tree

The theloop LineageOS device tree at
[LosSantosPro/android_device_rainx_theloop](https://github.com/LosSantosPro/android_device_rainx_theloop)
consumes the kernel as prebuilts, not as source. After building:

```bash
# Kernel image + dtb/dtbo
cp out/target/product/a34x/obj/KLEAF_OBJ/dist/Image.gz  <device-tree>/prebuilts/
cp out/target/product/a34x/obj/KLEAF_OBJ/dist/dtb.img   <device-tree>/prebuilts/
cp out/target/product/a34x/obj/KLEAF_OBJ/dist/dtbo.img  <device-tree>/prebuilts/

# Updated connectivity / DRM / audio kernel modules live in vendor_dlkm
cp out/target/product/a34x/obj/KLEAF_OBJ/dist/<module>.ko  <device-tree>/prebuilts/vendor_dlkm/
```

The device tree's `BoardConfig.mk` references these prebuilts via
`TARGET_PREBUILT_KERNEL`, `TARGET_PREBUILT_DTB`, and `BOARD_PREBUILT_DTBOIMAGE`.
There is no Kleaf integration into Soong — MediaTek Kleaf kernels are built
separately and imported as prebuilts, same as most modern Mediatek LineageOS
ports.

## theloop_overlay.config contents

```
CONFIG_SND_SOC_RT5512=m                     # RT5512 audio amplifier
# CONFIG_SMCDSD_PANEL is not set             # Disable Samsung panel framework
# CONFIG_SMCDSD_* is not set                 # ...and related options
# CONFIG_DRM_PANEL_MCD_COMMON is not set     # theloop uses DTS-driven panel driver
```

Rationale in the file's inline comments.

## Pulling ASB updates from upstream

```bash
git checkout sixteen
git pull upstream sixteen
git checkout lineage-23.2
git rebase sixteen
# resolve conflicts in build_kernel.sh / theloop_overlay.config if any
./build_kernel.sh  # rebuild + copy prebuilts to device tree
```

## Credits

- Upstream kernel maintenance: [UN1CA](https://github.com/UN1CA)
- Base: AOSP `common-android15-6.6` GKI
- MTK device modules: Samsung/MediaTek (via UN1CA)
