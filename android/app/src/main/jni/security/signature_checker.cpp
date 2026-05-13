#include "signature_checker.h"
#include "../helpers/ApkHelper.h"
#include "../helpers/SysCalls.h"
#include "../helpers/obfusheader.h"
#include <android/log.h>
#include <algorithm>
#include <vector>
#include <string>

#define LOG_TAG "SignatureChecker"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace security {

int verify_signature() {
    try {
        std::string apk_path = ApkHelper::get_apk_path();
        if (apk_path.empty()) {
            //LOGE("Failed to get APK path");
            return 0;
        }

       // LOGI("APK path: %s", apk_path.c_str());
        std::vector<uint8_t> apk_data = SysCalls::read_file_direct_alloc(apk_path.c_str());
        if (apk_data.empty()) {
            //LOGE("Failed to read APK via syscalls");
            return 0;
        }

        LOGI("APK size: %zu bytes", apk_data.size());

        //Extract and calculate signature SHA256
        std::string actual_hash = ApkHelper::getAPKCertificateSHA256(apk_data);
        if (actual_hash.empty()) {
            // LOGE("Failed to extract certificate hash");
            // LOGE("This could mean:");
            // LOGE("  - No META-INF/*.RSA/DSA/EC file found in APK");
            // LOGE("  - Certificate file is corrupted");
            // LOGE("  - PKCS7 parsing failed");
            // LOGE("  - APK is not signed or signature format unsupported");
            return 0;
        }
        const std::string expected = OBF("E7B0C8E54EA04D8452E4A7FA361D970C99B889F5A41F3EAC2CF9760D56C7435C");

        //Remove colons from actual hash for comparison
        std::string actual_no_colon = actual_hash;
        actual_no_colon.erase(std::remove(actual_no_colon.begin(), actual_no_colon.end(), ':'), actual_no_colon.end());

        if (actual_no_colon == expected) {
            //LOGI("Signature verification PASSED");
            return 1;
        } else {
           // LOGE("Signature verification FAILED - APK tampered or wrong keystore");
            return 0;
        }

    } catch (const std::exception& e) {
        //LOGE("Exception during verification: %s", e.what());
        return 0;
    } catch (...) {
       // LOGE("Unknown exception during verification");
        return 0;
    }
}

}
