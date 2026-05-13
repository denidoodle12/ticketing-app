#include "ApkHelper.h"
#include "jni.h"
#include <cstdlib>
#include <vector>
#include <openssl/sha.h>
#include <openssl/x509.h>
#include <openssl/pkcs7.h>
#include <openssl/bio.h>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include "ZipHelper.h"
#include "obfusheader.h"
#include "SysCalls.h"
#include <android/log.h>

#define LOG_TAG "ApkHelper"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using namespace std;

string ApkHelper::calculateSHA256FromCert(const std::vector<uint8_t> &cert_data) {
    BIO *bio = BIO_new_mem_buf(cert_data.data(), cert_data.size());
    if (!bio) return "";

    PKCS7 *pkcs7 = d2i_PKCS7_bio(bio, nullptr);
    BIO_free(bio);
    if (!pkcs7) return "";

    std::string fingerprint;
    STACK_OF(X509) *certs = nullptr;

    if (PKCS7_type_is_signed(pkcs7)) {
            certs = pkcs7->d.sign->cert;
        }

    if (certs && sk_X509_num(certs) > 0) {
            X509 *cert = sk_X509_value(certs, 0);
            if (cert) {
                    unsigned char hash[SHA256_DIGEST_LENGTH];
                    unsigned int hash_len;

                    if (X509_digest(cert, EVP_sha256(), hash, &hash_len) == 1) {
                            std::stringstream ss;
                            for (unsigned int i = 0; i < hash_len; i++) {
                                    if (i > 0) ss << ":";
                                    ss << std::hex << std::setw(2) << std::setfill('0')
                                       << std::uppercase << (int) hash[i];
                                }
                            fingerprint = ss.str();
                        }
                }
        }

    PKCS7_free(pkcs7);
    return fingerprint;
}


std::string ApkHelper::getAPKCertificateSHA256(std::vector<uint8_t> apk_data) {
    if (apk_data.size() <= 0) {
            LOGE("APK data is empty");
            return "";
        }

    if (apk_data.data() == nullptr) {
            LOGE("APK data pointer is null");
            return "";
        }

    LOGI("Creating ZipHelper for APK (%zu bytes)", apk_data.size());
    ZipHelper reader(apk_data, apk_data.size());
    std::string cert_file = reader.findCertFile();

    if (cert_file.empty()) {
            LOGE("No certificate file found in META-INF/ (*.RSA/DSA/EC)");
            return "";
        }

    LOGI("Found certificate file: %s", cert_file.c_str());
    std::vector<uint8_t> cert_data = reader.extractFile(cert_file);

    if (cert_data.empty()) {
            LOGE("Failed to extract certificate file: %s", cert_file.c_str());
            return "";
        }

    LOGI("Extracted certificate data (%zu bytes), calculating SHA256...", cert_data.size());
    std::string sha256 = CALL(&calculateSHA256FromCert, cert_data);

    if (sha256.empty()) {
            LOGE("Failed to calculate SHA256 from certificate (PKCS7 parsing failed)");
            return "";
        }

    LOGI("Certificate SHA256: %s", sha256.c_str());
    return sha256;
}

void replaceAll(std::string &str, const std::string &from, const std::string &to) {
    size_t pos = 0;
    while ((pos = str.find(from, pos)) != std::string::npos) {
        str.replace(pos, from.length(), to);
        pos += to.length();  // In case 'to' contains 'from'
    }
}

string ApkHelper::get_apk_path() {
    std::vector<uint8_t> content = CALL(&SysCalls::read_file_direct_alloc, OBF("/proc/self/maps"));
    if (content.empty()) {
            return "";
        }
    std::string data(content.begin(), content.end());
    std::istringstream stream(data);
    std::string line;

    for (;;) {
            if (!std::getline(stream, line)) {
                    break;
                }
            if (strstr(line.c_str(), "/base.apk")) {
                    char *path = strchr(const_cast<char *>(line.c_str()), '/');
                    if (path) {
                            std::string apkPath(path);
                            while (!apkPath.empty() &&
                                   (apkPath.back() == ' ' || apkPath.back() == '\t' ||
                                    apkPath.back() == '\r')) {
                                apkPath.pop_back();
                            }

                            replaceAll(apkPath, "]", "");
                            return apkPath;
                        }
                }
        }
    return "";
}