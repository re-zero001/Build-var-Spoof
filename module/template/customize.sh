# shellcheck disable=SC2034
SKIPUNZIP=1

DEBUG=@DEBUG@
SONAME=build_var_spoof
SUPPORTED_ABIS="arm64 x64 arm x86"
MIN_SDK=27

if [ "$BOOTMODE" ] && [ "$KSU" ]; then
  ui_print "- Installing from KernelSU app"
  ui_print "- KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
  if [ "$(which magisk)" ]; then
    ui_print "*********************************************************"
    ui_print "! Multiple root implementation is NOT supported!"
    ui_print "! Please uninstall Magisk before installing Zygisk Next"
    abort    "*********************************************************"
  fi
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
  ui_print "- Installing from Magisk app"
else
  ui_print "*********************************************************"
  ui_print "! Install from recovery is not supported"
  ui_print "! Please install from KernelSU or Magisk app"
  abort    "*********************************************************"
fi

VERSION=$(grep_prop version "${TMPDIR}/module.prop")
ui_print "- Installing $SONAME $VERSION"

# Check architecture
if [ "$ARCH" != "arm" ] && [ "$ARCH" != "arm64" ] && [ "$ARCH" != "x86" ] && [ "$ARCH" != "x64" ]; then
  abort "! Unsupported platform: $ARCH"
else
  ui_print "- Device platform: $ARCH"
fi

ui_print "- Extracting verify.sh"
unzip -o "$ZIPFILE" 'verify.sh' -d "$TMPDIR" >&2
if [ ! -f "$TMPDIR/verify.sh" ]; then
  ui_print "*********************************************************"
  ui_print "! Unable to extract verify.sh!"
  ui_print "! This zip may be corrupted, please try downloading again"
  abort    "*********************************************************"
fi

# check android
if [ "$API" -lt $MIN_SDK ]; then
  ui_print "! Unsupported sdk: $API"
  abort "! Minimal supported sdk is $MIN_SDK"
else
  ui_print "- Device sdk: $API"
fi

. "$TMPDIR/verify.sh"
extract "$ZIPFILE" 'customize.sh'  "$TMPDIR/.vunzip"
extract "$ZIPFILE" 'verify.sh'     "$TMPDIR/.vunzip"

ui_print "- Extracting module files"
extract "$ZIPFILE" 'module.prop'     "$MODPATH"
extract "$ZIPFILE" 'post-fs-data.sh' "$MODPATH"
extract "$ZIPFILE" 'service.sh'      "$MODPATH"

mkdir "$MODPATH/zygisk"

if [ "$ARCH" = "arm64" ]; then
  ui_print "- Extracting arm64 libraries"
  extract "$ZIPFILE" "lib/arm64-v8a/libzygisk.so" "$MODPATH/zygisk" true
  mv "$MODPATH/zygisk/libzygisk.so" "$MODPATH/zygisk/arm64-v8a.so"
elif [ "$ARCH" = "x64" ]; then
  ui_print "- Extracting x64 libraries"
  extract "$ZIPFILE" "lib/x86_64/libzygisk.so" "$MODPATH/zygisk" true
  mv "$MODPATH/zygisk/libzygisk.so" "$MODPATH/zygisk/x86_64.so"
elif [ "$ARCH" = "arm" ]; then
  ui_print "- Extracting arm libraries"
  extract "$ZIPFILE" "lib/armeabi-v7a/libzygisk.so" "$MODPATH/zygisk" true
  mv "$MODPATH/zygisk/libzygisk.so" "$MODPATH/zygisk/armeabi-v7a.so"
elif [ "$ARCH" = "x86" ]; then
  ui_print "- Extracting x86 libraries"
  extract "$ZIPFILE" "lib/x86/libzygisk.so" "$MODPATH/zygisk" true
  mv "$MODPATH/zygisk/libzygisk.so" "$MODPATH/zygisk/x86.so"
fi

CONFIG_DIR=/data/adb/build_var_spoof
if [ ! -d "$CONFIG_DIR" ]; then
  ui_print "- Creating configuration directory"
  mkdir -p "$CONFIG_DIR"
  [ ! -f "$CONFIG_DIR/spoof_build_vars" ] && touch "$CONFIG_DIR/spoof_build_vars"
fi
