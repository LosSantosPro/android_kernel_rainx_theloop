#!/bin/bash
set -e  # exit on error

mkdir -p bin
export PATH="$(pwd)/bin:$PATH"

# curl/wget already installed - skip sudo apt-get

if [ ! -f bin/repo ]; then
  curl https://storage.googleapis.com/git-repo-downloads/repo > bin/repo
  chmod a+x bin/repo
fi

mkdir -p aosp-kernel
cd aosp-kernel
if [ ! -d .repo ]; then
  repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6 --depth=1
fi
echo "=== Starting repo sync ==="
repo sync -j$(nproc --all)
echo "=== Repo sync complete ==="

cd prebuilts/clang/host/linux-x86
if [ ! -d clang-r536225 ] || [ -z "$(ls -A clang-r536225/bin 2>/dev/null)" ]; then
  echo "=== Downloading Clang r536225 ==="
  rm -rf clang-r536225 clang-r536225.tar.gz
  wget --show-progress -O clang-r536225.tar.gz https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main-kernel-2025/clang-r536225.tar.gz
  mkdir clang-r536225
  cd clang-r536225
  echo "=== Extracting Clang ==="
  tar xzf ../clang-r536225.tar.gz
  rm ../clang-r536225.tar.gz
  cd ..
  echo "=== Clang ready ==="
fi

cd kleaf
if ! grep -q '"r536225"' versions.bzl; then
  echo "=== Patching versions.bzl ==="
  sed -i '/# keep sorted/a\    "r536225",' versions.bzl
fi
cd ..
cd ../../../../

if [ ! -e "../kernel/prebuilts" ]; then
  ln -s "$(pwd)/prebuilts" "../kernel/prebuilts"
fi
cd ..

cd kernel

echo "=== Patching build configs ==="
FTP="
build/kernel/_setup_env.sh
build/kernel/kleaf/impl/stamp.bzl
build/kernel/kleaf/impl/kernel_env.bzl
"

for f in $FTP; do
  if [ -f "$f" ]; then
    sed -i "s/SOURCE_DATE_EPOCH=0/SOURCE_DATE_EPOCH=\\\"\$(date +%s)\\\"/g" "$f"
  fi
done

sed -i "s/-maybe-dirty//g" "build/kernel/kleaf/impl/stamp.bzl" 2>/dev/null || true
sed -i "s/stable_scmversion_cmd = _get_status_at_path.*/stable_scmversion_cmd = \"echo ''\"/g" "build/kernel/kleaf/impl/stamp.bzl" 2>/dev/null || true
sed -i 's|SOURCE_DATE_EPOCH=0|SOURCE_DATE_EPOCH=\\"$(date +%s)\\"|' "kernel_device_modules-6.6/scripts/gen_build_config.py" 2>/dev/null || true
sed -i "s/r510928/r536225/" "kernel-6.6/build.config.constants" 2>/dev/null || true

echo "=== Generating build.config ==="
mkdir -p ../out/target/product/a34x/obj/KERNEL_OBJ
python kernel_device_modules-6.6/scripts/gen_build_config.py \
  --kernel-defconfig mediatek-bazel_defconfig \
  --kernel-defconfig-overlays "sec_ogki_fragment.config mt6877_overlay.config mt6877_teegris_5_overlay.config theloop_overlay.config" \
  --kernel-build-config-overlays "" \
  -m user \
  -o ../out/target/product/a34x/obj/KERNEL_OBJ/build.config

export DEVICE_MODULES_DIR="kernel_device_modules-6.6"
export BUILD_CONFIG="../out/target/product/a34x/obj/KERNEL_OBJ/build.config"
export OUT_DIR="../out/target/product/a34x/obj/KLEAF_OBJ"
export DIST_DIR="../out/target/product/a34x/obj/KLEAF_OBJ/dist"
export DEFCONFIG_OVERLAYS="sec_ogki_fragment.config mt6877_overlay.config mt6877_teegris_5_overlay.config theloop_overlay.config"
export PROJECT="mgk_64_k66"
export MODE="user"
export SOURCE_DATE_EPOCH="$(date +%s)"
export SEC_BUILDNUMBER="ogkiA346BXXSEEZB6"

# Enable verbose debug output to see the actual failing command
export DEBUG_ARGS="--verbose_failures"
export SANDBOX_ARGS="--sandbox_debug"

echo "=== Starting kernel build (Bazel with verbose_failures + sandbox_debug) ==="
chmod +x ./kernel_device_modules-6.6/build.sh
./kernel_device_modules-6.6/build.sh
