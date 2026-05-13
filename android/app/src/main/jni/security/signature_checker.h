//javaloader 20/02/2023
#ifndef SIGNATURE_CHECKER_H
#define SIGNATURE_CHECKER_H

namespace security {

/**
 * Verify APK signature using unhookable syscalls
 * 
 * This function:
 * - Reads APK via raw syscalls (bypasses libc hooks like Frida/Xposed)
 * - Extracts certificate from META-INF/*.RSA/DSA/EC
 * - Calculates SHA256 hash of the certificate
 * - Compares with obfuscated expected hash from keystore
 * 
 * @return 1 if signature matches (valid), 0 if tampered/wrong keystore
 */
int verify_signature();

} // namespace security

#endif // SIGNATURE_CHECKER_H
