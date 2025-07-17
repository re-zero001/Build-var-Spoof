#!/bin/sh
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH

download_fail() {
    dl_domain=$(echo "$1" | awk -F[/:] '{print $4}')
    echo "$1" | grep -q "\.zip$" && return
    # Clean up on download fail
    rm -rf "$TEMPDIR"
    ping -c 1 -W 5 "$dl_domain" > /dev/null 2>&1 || {
        echo "[!] Unable to connect to $dl_domain, please check your internet connection and try again"
        sleep_pause
        exit 1
    }
    conflict_module=$(ls /data/adb/modules | grep busybox)
    for i in $conflict_module; do
        echo "[!] Please remove $i and try again."
    done
    echo "[!] download failed!"
    echo "[x] bailing out!"
    sleep_pause
    exit 1
}

download() { busybox wget -T 10 --no-check-certificate -qO - "$1" > "$2" || download_fail "$1"; }
if command -v curl > /dev/null 2>&1; then
    download() { curl --connect-timeout 10 -s "$1" > "$2" || download_fail "$1"; }
fi

set_random_beta() {
	if [ "$(echo "$MODEL_LIST" | wc -l)" -ne "$(echo "$PRODUCT_LIST" | wc -l)" ]; then
		echo "Warning: MODEL_LIST and PRODUCT_LIST have different lengths, using Pixel 6 fallback"
		MODEL="Pixel 6"
		PRODUCT="oriole_beta"
	else
		count=$(echo "$MODEL_LIST" | wc -l)
		rand_index=$(( $$ % count ))
		MODEL=$(echo "$MODEL_LIST" | sed -n "$((rand_index + 1))p")
		PRODUCT=$(echo "$PRODUCT_LIST" | sed -n "$((rand_index + 1))p")
	fi
}

case "$1" in
  -h|--help|help) echo "sh autopif2.sh [-a]"; exit 0;;
  -a|--advanced|advanced) ARGS="-a";;
esac;

case "$0" in
  *.sh) DIR="$0";;
  *) DIR="$(lsof -p $$ 2>/dev/null | grep -o '/.*autopif2.sh$')";;
esac;
DIR=$(dirname "$(readlink -f "$DIR")");

if [ "$DIR" = /data/adb/modules/build_var_spoof ]; then
  DIR=$DIR/autopif2;
  mkdir -p $DIR;
fi;
cd "$DIR" || exit;

# Get latest Pixel Beta information
download https://developer.android.com/about/versions PIXEL_VERSIONS_HTML
BETA_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n1)
download "$BETA_URL" PIXEL_LATEST_HTML

# Handle Developer Preview vs Beta
if grep -qE 'Developer Preview|tooltip>.*preview program' PIXEL_LATEST_HTML && [ "$FORCE_PREVIEW" = 0 ]; then
	# Use the second latest version for beta
	BETA_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n2 | tail -n1)
	download "$BETA_URL" PIXEL_BETA_HTML
else
	mv -f PIXEL_LATEST_HTML PIXEL_BETA_HTML
fi

# Get OTA information
OTA_URL="https://developer.android.com$(grep -o 'href=".*download-ota.*"' PIXEL_BETA_HTML | cut -d\" -f2 | head -n1)"
download "$OTA_URL" PIXEL_OTA_HTML

# Extract device information
MODEL_LIST="$(grep -A1 'tr id=' PIXEL_OTA_HTML | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')"
PRODUCT_LIST="$(grep -o 'tr id="[^"]*"' PIXEL_OTA_HTML | awk -F\" '{print $2 "_beta"}')"
OTA_LIST="$(grep 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\" -f2)"

# Select and configure device
echo "- Selecting Pixel Beta device ..."
[ -z "$PRODUCT" ] && set_random_beta
echo "$MODEL ($PRODUCT)"

# Get device fingerprint and security patch from OTA metadata
(ulimit -f 2; download "$(echo "$OTA_LIST" | grep "$PRODUCT")" PIXEL_ZIP_METADATA) >/dev/null 2>&1
FINGERPRINT="$(strings PIXEL_ZIP_METADATA | grep -am1 'post-build=' | cut -d= -f2)"
SECURITY_PATCH="$(strings PIXEL_ZIP_METADATA | grep -am1 'security-patch-level=' | cut -d= -f2)"

# Validate required field to prevent empty pif.prop
if [ -z "$FINGERPRINT" ] || [ -z "$SECURITY_PATCH" ]; then
	# link to download pixel rom metadata that skipped connection check due to ulimit
	download_fail "https://dl.google.com"
fi

echo "- Dumping values to spoof_build_vars ...\n"
cat <<EOF | tee spoof_build_vars
MANUFACTURER=Google
MODEL=$MODEL
FINGERPRINT=$FINGERPRINT
SECURITY_PATCH=$SECURITY_PATCH
EOF

cat "$DIR/spoof_build_vars" > /data/adb/build_var_spoof/spoof_build_vars
echo "\n- new spoof_build_vars saved to \n/data/adb/build_var_spoof/spoof_build_vars"

echo "- Cleaning up ..."
rm -rf "$DIR"

for i in $(busybox pidof com.google.android.gms.unstable); do
	echo "- Killing pid $i"
	kill -9 "$i"
done
