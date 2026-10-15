#!/system/bin/sh
MODDIR=${0%/*}
umask 077
[ ! -f "$MODDIR/boot.log" ] || mv -f "$MODDIR/boot.log" "$MODDIR/boot.previous.log"
exec > "$MODDIR/boot.log" 2>&1 || exit 0
date
set -x
MOUNTED=""
fail() {
  printf 'Error: %s\n' "$1"
  for TARGET in $MOUNTED; do
    nsenter -t 1 -m -- umount "$TARGET" || printf 'Cannot roll back: %s\n' "$TARGET"
  done
  exit 0
}

[ "$(getprop ro.product.device)" = houji ] || fail "Unsupported device"
CONFIG=/odm/etc/camera/camxoverridesettings.txt
[ -f "$CONFIG" ] || fail "Camera settings not found"

for NAME in com.qti.sensormodule.houji_sunny_ovx9000_wide.bin com.qti.sensormodule.houji_sunny_ovx9000_wide_ii.bin; do
  SENSOR="/odm/lib64/camera/$NAME"
  PAYLOAD="$MODDIR/payload/$NAME"
  case "$NAME" in
    com.qti.sensormodule.houji_sunny_ovx9000_wide.bin) STOCKHASH=55077e6254da6c72cf70d58d0aee37538df7a96387e23459b7206913e8a94fac; PAYLOADHASH=341cfef70ec85ccabd92af924f29174c75d19ad8bdd18f2097a41aadc108a1bc ;;
    com.qti.sensormodule.houji_sunny_ovx9000_wide_ii.bin) STOCKHASH=92d549915514952051127b07cc83c3977cff199b92dc79f4691a935e4d39277e; PAYLOADHASH=88ea5e32f546503ec4b4ba41a301cc5086e97a3284478df95f560fbc58e17129 ;;
  esac
  [ -f "$SENSOR" ] || fail "Camera sensor file not found: $NAME"
  HASH=$(sha256sum "$SENSOR") || fail "Cannot read sensor table"
  case "${HASH%% *}" in
    "$STOCKHASH"|"$PAYLOADHASH") ;;
    *) fail "Unsupported sensor table: $NAME" ;;
  esac
  HASH=$(sha256sum "$PAYLOAD") || fail "Payload not found"
  [ "${HASH%% *}" = "$PAYLOADHASH" ] || fail "Invalid payload: $NAME"
  chmod 0644 "$PAYLOAD" || fail "Cannot set payload permissions"
  chcon u:object_r:vendor_file:s0 "$PAYLOAD" || fail "Cannot label sensor payload"
done

awk '
  /^[[:space:]]*VideoSizeCustom[[:space:]]*=/ {
    found = 1
    sub(/\r$/, "")
    if ($0 !~ /[=|]0@8@120([|[:space:]]|$)/) {
      sub(/[[:space:]]*$/, "")
      $0 = $0 "|0@8@120"
    }
  }
  { print }
  END { if (!found) print "VideoSizeCustom=0@8@120" }
' "$CONFIG" > "$MODDIR/native-settings.tmp" || { rm -f "$MODDIR/native-settings.tmp"; fail "Cannot generate video settings"; }
mv -f "$MODDIR/native-settings.tmp" "$MODDIR/native-settings.txt" || fail "Cannot save video settings"
chmod 0644 "$MODDIR/native-settings.txt" || fail "Cannot set settings permissions"
chcon u:object_r:vendor_configs_file:s0 "$MODDIR/native-settings.txt" || fail "Cannot label video settings"

for NAME in com.qti.sensormodule.houji_sunny_ovx9000_wide.bin com.qti.sensormodule.houji_sunny_ovx9000_wide_ii.bin; do
  SENSOR="/odm/lib64/camera/$NAME"
  nsenter -t 1 -m -- mount --bind "$MODDIR/payload/$NAME" "$SENSOR" || fail "Cannot mount sensor table"
  MOUNTED="$SENSOR $MOUNTED"
done
nsenter -t 1 -m -- mount --bind "$MODDIR/native-settings.txt" "$CONFIG" || fail "Cannot mount video settings"
printf 'Applied: 4K120 sensor tables and video settings\n'
