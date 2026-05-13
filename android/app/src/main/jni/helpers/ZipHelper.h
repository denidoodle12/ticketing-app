#ifndef SYSCALL_ZIPHELPER_H
#define SYSCALL_ZIPHELPER_H

#include <vector>
#include <string>
#include <cstdint>

struct ZipEndCentralDir;
struct ZipCentralDirEntry;

class ZipHelper {
private:
    std::vector<uint8_t> data;
    size_t size;

    /**
     * Find the End of Central Directory record in the ZIP file
     * @return Pointer to ECD record or nullptr if not found
     */
    ZipEndCentralDir* findEndCentralDir();

    /**
     * Extract file data from a central directory entry
     * @param entry Pointer to the central directory entry
     * @return Vector containing the extracted file data
     */
    std::vector<uint8_t> extractFileData(ZipCentralDirEntry* entry);

public:
    /**
     * Constructor
     * @param zip_data Vector containing the ZIP file data
     * @param zip_size Size of the ZIP data (should match zip_data.size())
     */
    ZipHelper(const std::vector<uint8_t>& zip_data, size_t zip_size);

    /**
     * Extract a specific file from the ZIP archive
     * @param target_filename Name of the file to extract
     * @return Vector containing the file data, empty if file not found
     */
    std::vector<uint8_t> extractFile(const std::string& target_filename);

    /**
     * Find a certificate file (.RSA, .DSA, .EC) in the META-INF directory
     * @return Filename of the certificate file, empty string if not found
     */
    std::string findCertFile();

    /**
     * Get the size of the ZIP data
     * @return Size in bytes
     */
    size_t getSize() const { return data.size(); }

    /**
     * Check if the ZIP data is valid (non-empty)
     * @return True if data is valid, false otherwise
     */
    bool isValid() const { return !data.empty(); }
};


#endif //SYSCALL_ZIPHELPER_H
