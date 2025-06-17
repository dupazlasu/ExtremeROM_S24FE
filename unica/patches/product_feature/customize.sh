# [
APPLY_PATCH()
{
    local PATCH
    local OUT

    DECODE_APK "$1"

    cd "$APKTOOL_DIR/$1"
    PATCH="$SRC_DIR/unica/patches/product_feature/$2"
    OUT="$(patch -p1 -s -t -N --dry-run < "$PATCH")" \
        || echo "$OUT" | grep -q "Skipping patch" || false
    patch -p1 -s -t -N --no-backup-if-mismatch < "$PATCH" &> /dev/null || true
    cd - &> /dev/null
}

GET_FP_SENSOR_TYPE()
{
    if [[ "$1" == *"ultrasonic"* ]]; then
        echo "ultrasonic"
    elif [[ "$1" == *"optical"* ]]; then
        echo "optical"
    elif [[ "$1" == *"side"* ]]; then
        echo "side"
    else
        echo "Unsupported type: $1"
        exit 1
    fi
}
# ]

MODEL=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 1)
REGION=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 2)

if [[ "$SOURCE_PRODUCT_FIRST_API_LEVEL" != "$TARGET_PRODUCT_FIRST_API_LEVEL" ]]; then
    echo "Applying MAINLINE_API_LEVEL patches"

    DECODE_APK "system/framework/services.jar"

    FTP="
    system/framework/services.jar/smali/com/android/server/SystemServer.smali
    system/framework/services.jar/smali/com/android/server/enterprise/hdm/HdmVendorController.smali
    system/framework/services.jar/smali/com/android/server/enterprise/hdm/HdmSakManager.smali
    system/framework/services.jar/smali/com/android/server/knox/dar/ddar/ta/TAProxy.smali
    system/framework/services.jar/smali_classes2/com/android/server/power/PowerManagerUtil.smali
    system/framework/services.jar/smali_classes2/com/android/server/sepunion/EngmodeService\$EngmodeTimeThread.smali
    "
    for f in $FTP; do
        sed -i \
            "s/\"MAINLINE_API_LEVEL: $SOURCE_PRODUCT_FIRST_API_LEVEL\"/\"MAINLINE_API_LEVEL: $TARGET_PRODUCT_FIRST_API_LEVEL\"/g" \
            "$APKTOOL_DIR/$f"
        sed -i "s/\"$SOURCE_PRODUCT_FIRST_API_LEVEL\"/\"$TARGET_PRODUCT_FIRST_API_LEVEL\"/g" "$APKTOOL_DIR/$f"
    done
fi

if [[ "$SOURCE_AUTO_BRIGHTNESS_TYPE" != "$TARGET_AUTO_BRIGHTNESS_TYPE" && "$TARGET_AUTO_BRIGHTNESS_TYPE" != "4" ]]; then
    echo "Applying auto brightness type patches"

    DECODE_APK "system/framework/services.jar"
    DECODE_APK "system/framework/ssrm.jar"
    DECODE_APK "system/priv-app/SecSettings/SecSettings.apk"

    FTP="
    system/framework/services.jar/smali_classes2/com/android/server/power/PowerManagerUtil.smali
    system/framework/ssrm.jar/smali/com/android/server/ssrm/PreMonitor.smali
    system/priv-app/SecSettings/SecSettings.apk/smali_classes4/com/samsung/android/settings/Rune.smali
    "
    for f in $FTP; do
        sed -i "s/\"$SOURCE_AUTO_BRIGHTNESS_TYPE\"/\"$TARGET_AUTO_BRIGHTNESS_TYPE\"/g" "$APKTOOL_DIR/$f"
    done

    # WORKAROUND: Skip failure on CALIBRATEDLUX
    if [[ "$TARGET_AUTO_BRIGHTNESS_TYPE" == "3" ]]; then
        HEX_PATCH "$WORK_DIR/system/system/lib64/libsensorservice.so" "0660009420008052" "0660009400008052"
    fi
fi

if [[ "$TARGET_DISPLAY_CUTOUT_TYPE" == "right" ]]; then
    echo "Applying right cutout patch"
    APPLY_PATCH "system_ext/priv-app/SystemUI/SystemUI.apk" "cutout/SystemUI.apk/0001-Add-right-cutout-support.patch"
fi

if [[ "$SOURCE_DVFS_CONFIG_NAME" != "$TARGET_DVFS_CONFIG_NAME" ]]; then
    echo "Applying DVFS patches"

    DECODE_APK "system/framework/ssrm.jar"

    FTP="
    system/framework/ssrm.jar/smali/com/android/server/ssrm/Feature.smali
    "
    for f in $FTP; do
        sed -i "s/\"$SOURCE_DVFS_CONFIG_NAME\"/\"$TARGET_DVFS_CONFIG_NAME\"/g" "$APKTOOL_DIR/$f"
    done
fi

if $SOURCE_IS_ESIM_SUPPORTED; then
    if ! $TARGET_IS_ESIM_SUPPORTED; then
        SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_COMMON_CONFIG_EMBEDDED_SIM_SLOTSWITCH" --delete
        SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_COMMON_SUPPORT_EMBEDDED_SIM" --delete
    fi
fi

if [ -f "$FW_DIR/${MODEL}_${REGION}/system/system/etc/permissions/com.sec.feature.cover.xml" ]; then
    echo "Adding LED Case Cover support"
    ADD_TO_WORK_DIR "p3sxxx" "system" "system/priv-app/LedCoverService/LedCoverService.apk"
    ADD_TO_WORK_DIR "p3sxxx" "system" "system/etc/permissions/privapp-permissions-com.sec.android.cover.ledcover.xml"
fi

