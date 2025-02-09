#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=camera
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        vendor/lib64/libsdmcore.so)
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v33.so" "${2}"
            ;;
        vendor/lib/libsdmcore.so)
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v33.so" "${2}"
            ;;
        vendor/lib64/hw/displayfeature.default.so)
            "${PATCHELF}" --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
            ;;
        system_ext/lib64/libwfdnative.so)
            "${PATCHELF}" --remove-needed "android.hidl.base@1.0.so" "${2}"
            ;;            
        vendor/lib64/android.hardware.secure_element@1.0-impl.so)
            "${PATCHELF}" --remove-needed "android.hidl.base@1.0.so" "${2}"
            ;;
        system/lib64/libcamera_algoup_jni.xiaomi.so | system/lib64/libcamera_mianode_jni.xiaomi.so)
            "${PATCHELF}" --add-needed "libgui_shim_miuicamera.so" "${2}"
            ;;
        vendor/bin/hw/vendor.dolby.hardware.dms@2.0-service)
            "${PATCHELF}" --add-needed "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/etc/init/init.embmssl_server.rc)
            sed -i -n '/interface/!p' "${2}"
            ;;
        vendor/etc/vintf/manifest/c2_manifest_vendor.xml)
            sed -ni '/ozoaudio/!p' "${2}"
            ;;
        vendor/lib/libcodec2_hidl@1.0_vendor.so)
            "${PATCHELF}" --set-soname "libcodec2_hidl@1.0_vendor.so" "${2}"
            "${PATCHELF}" --replace-needed "libcodec2_vndk.so" "libcodec2_vndk_vendor.so" "${2}"
            ;;
        vendor/lib/libcodec2_vndk_vendor.so)
            "${PATCHELF}" --set-soname "libcodec2_vndk_vendor.so" "${2}"
            ;;
        vendor/lib64/c2.dolby.client.so)
            "${PATCHELF}" --replace-needed "libcodec2_vndk.so" "libcodec2_vndk_vendor.so" "${2}"
            "${PATCHELF}" --replace-needed "libcodec2_hidl@1.0.so" "libcodec2_hidl@1.0_vendor.so" "${2}"
            ;;
        vendor/bin/hw/dolbycodec2)
            "${PATCHELF}" --add-needed "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/etc/media_lahaina/video_system_specs.json \
        |vendor/etc/media_shima_v1/video_system_specs.json \
        |vendor/etc/media_yupik_v1/video_system_specs.json)
            sed -i "/max_retry_alloc_output_timeout/ s/10000/0/" "${2}"
            ;;
        vendor/etc/vintf/manifest/c2_manifest_vendor.xml)
            sed -ni '/ozoaudio/!p' "${2}"
            ;;
        system/priv-app/MiuiCamera/MiuiCamera.apk)
            tmp_dir="${EXTRACT_TMP_DIR}/MiuiCamera"
            apktool d -q "$2" -o "$tmp_dir" -f
            grep -rl "com.miui.gallery" "$tmp_dir" | xargs sed -i 's|"com.miui.gallery"|"com.google.android.apps.photos"|g'
            apktool b -q "$tmp_dir" -o "$2"
            rm -rf "$tmp_dir"
            split --bytes=20M -d "$2" "$2".part
       ;;
    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
