#!/bin/sh
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH

download() { busybox wget -T 10 --no-check-certificate -qO - "$1"; }
if command -v curl > /dev/null 2>&1; then
	download() { curl --connect-timeout 10 -s "$1"; }
fi

download_fail() {
	echo "[!] download failed!"
	echo "[x] bailing out!"
	exit 1
}

set_random_beta() {
    if [ "$(echo "$MODEL_LIST" | wc -l)" -ne "$(echo "$PRODUCT_LIST" | wc -l)" ]; then
            echo "Error: MODEL_LIST and PRODUCT_LIST have different lengths."
            exit 1
    fi
    count=$(echo "$MODEL_LIST" | wc -l)
    rand_index=$(( $$ % count ))
    MODEL=$(echo "$MODEL_LIST" | sed -n "$((rand_index + 1))p")
    PRODUCT=$(echo "$PRODUCT_LIST" | sed -n "$((rand_index + 1))p")
    OTA=$(echo "$OTA_LIST" | sed -n "$((rand_index + 1))p")
    DEVICE=$(echo "$PRODUCT" | sed 's/_beta//')
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
cd "$DIR";

echo "Crawling Android Developers for latest Pixel Beta ...";
wget -q -O PIXEL_VERSIONS_HTML --no-check-certificate https://developer.android.com/about/versions 2>&1 || download_fail;
wget -q -O PIXEL_LATEST_HTML --no-check-certificate $(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n1) 2>&1 || download_fail;
case "$1" in -p) FORCE_PREVIEW=1; shift;; esac;
if grep -qE 'Developer Preview|tooltip>.*preview program' PIXEL_LATEST_HTML && [ ! "$FORCE_PREVIEW" ]; then
  wget -q -O PIXEL_BETA_HTML --no-check-certificate $(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n2 | tail -n1) 2>&1 || download_fail;
else
  TITLE="Preview";
  mv -f PIXEL_LATEST_HTML PIXEL_BETA_HTML;
fi;
case "$1" in -d) FORCE_DEPTH=$2; shift 2;; *) FORCE_DEPTH=1;; esac;
wget -q -O PIXEL_OTA_HTML --no-check-certificate https://developer.android.com$(grep -o 'href=".*download-ota.*"' PIXEL_BETA_HTML | cut -d\" -f2 | head -n$FORCE_DEPTH | tail -n1) 2>&1 || download_fail;
echo "$(grep -m1 -oE 'tooltip>Android .*[0-9]' PIXEL_OTA_HTML | cut -d\> -f2) $TITLE$(grep -oE 'tooltip>QPR.* Beta' PIXEL_OTA_HTML | cut -d\> -f2 | head -n$FORCE_DEPTH | tail -n1)";

BETA_REL_DATE="$(date -d '%B %e, %Y' -d "$(grep -m1 -A1 'Release date' PIXEL_OTA_HTML | tail -n1 | sed 's;.*<td>\(.*\)</td>.*;\1;')" '+%Y-%m-%d')";
echo "Beta Released: $BETA_REL_DATE\E";

MODEL_LIST="$(grep -A1 'tr id=' PIXEL_OTA_HTML | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')";
PRODUCT_LIST="$(grep -o 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\/ -f2)";
OTA_LIST="$(grep 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\" -f2)";

echo "- Selecting Pixel Beta device ..."
[ -z "$PRODUCT" ] && set_random_beta
echo "$MODEL ($PRODUCT)"

(ulimit -f 2; wget -q -O PIXEL_ZIP_METADATA --no-check-certificate $OTA) 2>/dev/null;
FINGERPRINT="$(grep -am1 'post-build=' PIXEL_ZIP_METADATA | cut -d= -f2)";
SECURITY_PATCH="$(grep -am1 'security-patch-level=' PIXEL_ZIP_METADATA | cut -d= -f2)";
if [ -z "$FINGERPRINT" -o -z "$SECURITY_PATCH" ]; then
  echo "\nError: Failed to extract information from metadata!";
  exit 1;
fi;

echo "- Dumping values to spoof_build_vars ...\n"
if [ -n "$FINGERPRINT" ]; then
    BRAND=$(echo $FINGERPRINT | cut -d'/' -f1)
    PRODUCT=$(echo $FINGERPRINT | cut -d'/' -f2)
    DEVICE=$(echo $FINGERPRINT | cut -d'/' -f3 | cut -d':' -f1)
    RELEASE=$(echo $FINGERPRINT | cut -d':' -f2 | cut -d'/' -f1)
    ID=$(echo $FINGERPRINT | cut -d'/' -f4)
    INCREMENTAL=$(echo $FINGERPRINT | cut -d'/' -f5 | cut -d':' -f1)
    TYPE=$(echo $FINGERPRINT | cut -d':' -f3 | cut -d'/' -f1)
    TAGS=$(echo $FINGERPRINT | cut -d':' -f3 | cut -d'/' -f2)
fi
cat <<EOF | tee spoof_build_vars
MANUFACTURER=Google
MODEL=$MODEL
FINGERPRINT=$FINGERPRINT
BRAND=$BRAND
PRODUCT=$PRODUCT
DEVICE=$DEVICE
RELEASE=$RELEASE
ID=$ID
INCREMENTAL=$INCREMENTAL
TYPE=$TYPE
TAGS=$TAGS
SECURITY_PATCH=$SECURITY_PATCH
EOF

cat "$DIR/spoof_build_vars" > /data/adb/build_var_spoof/spoof_build_vars
echo "\n- new spoof_build_vars saved to /data/adb/build_var_spoof/spoof_build_vars"

echo "- Cleaning up ..."
rm -rf "$DIR"

for i in $(busybox pidof com.google.android.gms.unstable); do
	echo "- Killing pid $i"
	kill -9 "$i"
done

