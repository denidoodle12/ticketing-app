#ifndef SYSCALL_APKHELPER_H
#define SYSCALL_APKHELPER_H


#include <jni.h>
#include <cstdlib>
#include <vector>
#include <string>


class ApkHelper {

public:
    static std::string getAPKCertificateSHA256(std::vector<uint8_t>  apk_data);

    static std::string get_apk_path();

    static std::string calculateSHA256FromCert(const std::vector<uint8_t> &cert_data);


};


#endif //SYSCALL_APKHELPER_H
