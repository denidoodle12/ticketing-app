LOCAL_PATH := $(call my-dir)

# ---------------------------------------------------------------------------
# Prebuilt: libcurl (static)
# ---------------------------------------------------------------------------
include $(CLEAR_VARS)
LOCAL_MODULE := curl-prebuilt
LOCAL_SRC_FILES := curl/curl-android-$(TARGET_ARCH_ABI)/lib/libcurl.a
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/curl/curl-android-$(TARGET_ARCH_ABI)/include
include $(PREBUILT_STATIC_LIBRARY)

# ---------------------------------------------------------------------------
# Prebuilt: libssl (static, OpenSSL)
# ---------------------------------------------------------------------------
include $(CLEAR_VARS)
LOCAL_MODULE := ssl-prebuilt
LOCAL_SRC_FILES := curl/openssl-android-$(TARGET_ARCH_ABI)/lib/libssl.a
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/curl/openssl-android-$(TARGET_ARCH_ABI)/include
include $(PREBUILT_STATIC_LIBRARY)

# ---------------------------------------------------------------------------
# Prebuilt: libcrypto (static, OpenSSL)
# ---------------------------------------------------------------------------
include $(CLEAR_VARS)
LOCAL_MODULE := crypto-prebuilt
LOCAL_SRC_FILES := curl/openssl-android-$(TARGET_ARCH_ABI)/lib/libcrypto.a
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/curl/openssl-android-$(TARGET_ARCH_ABI)/include
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE    := javaloader
LOCAL_SRC_FILES := javaloader.cpp \
                   sse/sse_client.cpp \
                   security/signature_checker.cpp \
                   helpers/ApkHelper.cpp \
                   helpers/ZipHelper.cpp \
                   helpers/SysCalls.cpp

LOCAL_C_INCLUDES := \
    $(LOCAL_PATH)/rapidjson \
    $(LOCAL_PATH)/sse \
    $(LOCAL_PATH)/security \
    $(LOCAL_PATH)/helpers \
    $(LOCAL_PATH)/tools/obfuscator/lib \
    $(LOCAL_PATH)/curl/curl-android-$(TARGET_ARCH_ABI)/include \
    $(LOCAL_PATH)/curl/openssl-android-$(TARGET_ARCH_ABI)/include

LOCAL_CPPFLAGS  := -std=c++17 -fvisibility=hidden -fexceptions
LOCAL_LDLIBS    := -llog -lz

#curl depends on ssl, ssl depends on crypto.
LOCAL_STATIC_LIBRARIES := curl-prebuilt ssl-prebuilt crypto-prebuilt

include $(BUILD_SHARED_LIBRARY)
