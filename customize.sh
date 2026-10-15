#!/system/bin/sh
SKIPMOUNT=true

ui_print ""
ui_print "  $(sed -n 's/^name=//p' "$MODPATH/module.prop")"
ui_print "  ────────────────────"

[ "$(getprop ro.product.device)" = houji ] || abort "  Unsupported device"
CONFIG=/odm/etc/camera/camxoverridesettings.txt
[ -f "$CONFIG" ] || abort "  Camera settings not found"

for NAME in com.qti.sensormodule.houji_sunny_ovx9000_wide.bin com.qti.sensormodule.houji_sunny_ovx9000_wide_ii.bin; do
  SENSOR="/odm/lib64/camera/$NAME"
  PAYLOAD="$MODPATH/payload/$NAME"
  case "$NAME" in
    com.qti.sensormodule.houji_sunny_ovx9000_wide.bin) STOCKHASH=55077e6254da6c72cf70d58d0aee37538df7a96387e23459b7206913e8a94fac; PAYLOADHASH=341cfef70ec85ccabd92af924f29174c75d19ad8bdd18f2097a41aadc108a1bc ;;
    com.qti.sensormodule.houji_sunny_ovx9000_wide_ii.bin) STOCKHASH=92d549915514952051127b07cc83c3977cff199b92dc79f4691a935e4d39277e; PAYLOADHASH=88ea5e32f546503ec4b4ba41a301cc5086e97a3284478df95f560fbc58e17129 ;;
  esac
  [ -f "$SENSOR" ] || abort "  Camera sensor file not found: $NAME"
  HASH=$(sha256sum "$SENSOR") || abort "  Cannot read sensor table"
  case "${HASH%% *}" in
    "$STOCKHASH"|"$PAYLOADHASH") ;;
    *) abort "  Unsupported sensor table: $NAME" ;;
  esac
  HASH=$(sha256sum "$PAYLOAD") || abort "  Payload not found"
  [ "${HASH%% *}" = "$PAYLOADHASH" ] || abort "  Invalid payload: $NAME"
  set_perm "$PAYLOAD" 0 0 0644
done

set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755

ui_print "  4K120 video recording support."
ui_print "  Ready. Reboot to apply."
ui_print ""
ui_print "  Made by Picters"
