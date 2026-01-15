#!/system/bin/sh

check_reset_prop() {
  NAME=$1
  EXPECTED=$2
  VALUE="$(resetprop "$NAME" 2>/dev/null || true)"
  if [ -z "${VALUE:-}" ] || [ "$VALUE" != "$EXPECTED" ]; then
    resetprop -n "$NAME" "$EXPECTED"
  fi
}

contains_reset_prop() {
  NAME=$1
  CONTAINS=$2
  NEWVAL=$3
  CUR="$(resetprop "$NAME" 2>/dev/null || true)"
  case "$CUR" in
    *"$CONTAINS"*) resetprop -n "$NAME" "$NEWVAL" ;;
  esac
}

# mark boot not completed before spoofing
resetprop -w sys.boot_completed 0

check_reset_prop "ro.boot.vbmeta.device_state" "locked"
check_reset_prop "ro.boot.verifiedbootstate" "green"
check_reset_prop "ro.boot.flash.locked" "1"
check_reset_prop "ro.boot.veritymode" "enforcing"
check_reset_prop "ro.boot.warranty_bit" "0"
check_reset_prop "ro.warranty_bit" "0"
check_reset_prop "ro.build.type" "user"
check_reset_prop "ro.build.tags" "release-keys"
check_reset_prop "ro.vendor.boot.warranty_bit" "0"
check_reset_prop "ro.vendor.warranty_bit" "0"
check_reset_prop "vendor.boot.vbmeta.device_state" "locked"
check_reset_prop "vendor.boot.verifiedbootstate" "green"
check_reset_prop "sys.oem_unlock_allowed" "0"

# MIUI specific
check_reset_prop "ro.secureboot.lockstate" "locked"

# Realme specific
check_reset_prop "ro.boot.realmebootstate" "green"
check_reset_prop "ro.boot.realme.lockstate" "1"

# Hide that we booted from recovery when magisk is in recovery mode
contains_reset_prop "ro.bootmode" "recovery" "unknown"
contains_reset_prop "ro.boot.bootmode" "recovery" "unknown"
contains_reset_prop "vendor.boot.bootmode" "recovery" "unknown"
