#include <cstdint>
#include "ZipHelper.h"
#include <vector>
#include <zlib.h>
#include <algorithm>
#include <string>
#include "obfusheader.h"

#pragma pack(push, 1)
struct ZipCentralDirEntry {
    uint32_t signature;
    uint16_t version_made;
    uint16_t version_needed;
    uint16_t flags;
    uint16_t compression;
    uint16_t mod_time;
    uint16_t mod_date;
    uint32_t crc32;
    uint32_t compressed_size;
    uint32_t uncompressed_size;
    uint16_t filename_len;
    uint16_t extra_len;
    uint16_t comment_len;
    uint16_t disk_start;
    uint16_t internal_attr;
    uint32_t external_attr;
    uint32_t offset;
};

struct ZipEndCentralDir {
    uint32_t signature;
    uint16_t disk_num;
    uint16_t disk_start;
    uint16_t disk_entries;
    uint16_t total_entries;
    uint32_t central_size;
    uint32_t central_offset;
    uint16_t comment_len;
};

struct ZipLocalFileHeader {
    uint32_t signature;
    uint16_t version;
    uint16_t flags;
    uint16_t compression;
    uint16_t mod_time;
    uint16_t mod_date;
    uint32_t crc32;
    uint32_t compressed_size;
    uint32_t uncompressed_size;
    uint16_t filename_len;
    uint16_t extra_len;
};
#pragma pack(pop)

ZipHelper::ZipHelper(const std::vector<uint8_t>& zip_data, size_t zip_size) : data(zip_data), size(zip_size) {}

ZipEndCentralDir* ZipHelper::findEndCentralDir() {
    if (data.size() < sizeof(ZipEndCentralDir)) {
            return nullptr;
        }

    const uint32_t ecd_signature = OBF(0x06054b50);
    size_t max_comment_len = 65535;
    size_t search_range = std::min(max_comment_len + sizeof(ZipEndCentralDir), data.size());

    for (size_t i = 0; i < search_range - sizeof(ZipEndCentralDir) + 1; i++) {
            size_t offset = data.size() - sizeof(ZipEndCentralDir) - i;
            if (offset + sizeof(ZipEndCentralDir) > data.size()) {
                    continue;
                }

            const uint8_t* ptr = data.data() + offset;
            uint32_t sig_value = *reinterpret_cast<const uint32_t*>(ptr);

            if (sig_value == ecd_signature) {
                    ZipEndCentralDir* ecd = reinterpret_cast<ZipEndCentralDir*>(const_cast<uint8_t*>(ptr));

                    if (ecd->central_offset >= data.size()) {
                            continue;
                        }

                    if (ecd->central_offset + ecd->central_size > data.size()) {
                            continue;
                        }

                    return ecd;
                }
        }

    return nullptr;
}

std::vector<uint8_t> ZipHelper::extractFileData(ZipCentralDirEntry* entry) {
    if (entry->offset >= data.size()) {
            return {};
        }

    const uint8_t* local_ptr = data.data() + entry->offset;

    if (entry->offset + sizeof(ZipLocalFileHeader) > data.size()) {
            return {};
        }

    const ZipLocalFileHeader* local_header = reinterpret_cast<const ZipLocalFileHeader*>(local_ptr);

    if (local_header->signature != OBF(0x04034b50)) {
            return {};
        }

    size_t file_data_offset = entry->offset + sizeof(ZipLocalFileHeader) + local_header->filename_len + local_header->extra_len;

    if (file_data_offset >= data.size() || file_data_offset + entry->compressed_size > data.size()) {
            return {};
        }

    const uint8_t* file_data = data.data() + file_data_offset;

    if (entry->compression == 0) {
            return std::vector<uint8_t>(file_data, file_data + entry->compressed_size);
        } else if (entry->compression == 8) {
                    std::vector<uint8_t> result(entry->uncompressed_size);
                    z_stream strm = {};
                    strm.next_in = const_cast<Bytef*>(file_data);
                    strm.avail_in = entry->compressed_size;
                    strm.next_out = result.data();
                    strm.avail_out = entry->uncompressed_size;

                    int ret = inflateInit2(&strm, -MAX_WBITS);
                    if (ret == Z_OK) {
                            ret = inflate(&strm, Z_FINISH);
                            inflateEnd(&strm);
                            if (ret == Z_STREAM_END) {
                                    return result;
                                }
                        }
                }

    return {};
}

std::vector<uint8_t> ZipHelper::extractFile(const std::string& target_filename) {
    ZipEndCentralDir* ecd = findEndCentralDir();
    if (!ecd) {
            return {};
        }

    if (ecd->central_offset >= data.size()) {
            return {};
        }

    const uint8_t* cd_ptr = data.data() + ecd->central_offset;
    const uint8_t* cd_end = cd_ptr + ecd->central_size;

    for (uint16_t i = 0; i < ecd->total_entries; i++) {
            if (cd_ptr + sizeof(ZipCentralDirEntry) > cd_end) {
                    return {};
                }

            ZipCentralDirEntry* entry = reinterpret_cast<ZipCentralDirEntry*>(const_cast<uint8_t*>(cd_ptr));

            if (entry->signature != OBF(0x02014b50)) {
                    return {};
                }

            cd_ptr += sizeof(ZipCentralDirEntry);

            if (cd_ptr + entry->filename_len > cd_end) {
                    return {};
                }

            std::string filename(reinterpret_cast<const char*>(cd_ptr), entry->filename_len);

            if (filename == target_filename) {
                    return extractFileData(entry);
                }

            cd_ptr += entry->filename_len + entry->extra_len + entry->comment_len;

            if (cd_ptr > cd_end) {
                    return {};
                }
        }

    return {};
}

std::string ZipHelper::findCertFile() {
    ZipEndCentralDir* ecd = findEndCentralDir();
    if (!ecd) {
            return "";
        }

    if (ecd->central_offset >= data.size()) {
            return "";
        }

    if (ecd->central_offset + ecd->central_size > data.size()) {
            return "";
        }

    const uint8_t* cd_ptr = data.data() + ecd->central_offset;
    const uint8_t* cd_end = cd_ptr + ecd->central_size;

    for (uint16_t i = 0; i < ecd->total_entries && cd_ptr < cd_end; i++) {
            if (cd_ptr + sizeof(ZipCentralDirEntry) > cd_end) {
                    return "";
                }

            ZipCentralDirEntry* entry = reinterpret_cast<ZipCentralDirEntry*>(const_cast<uint8_t*>(cd_ptr));

            if (entry->signature != OBF(0x02014b50)) {
                    return "";
                }

            if (entry->filename_len == 0 || entry->filename_len > 1024) {
                    return "";
                }

            if (cd_ptr + sizeof(ZipCentralDirEntry) + entry->filename_len > cd_end) {
                    return "";
                }

            const char* filename_ptr = reinterpret_cast<const char*>(cd_ptr + sizeof(ZipCentralDirEntry));
            std::string filename(filename_ptr, entry->filename_len);

            if (filename.rfind(OBF("META-INF/"), 0) == 0) {
                    std::string upper_filename = filename;
                    std::transform(upper_filename.begin(), upper_filename.end(),
                                   upper_filename.begin(),
                                   ::toupper);

                    size_t len = upper_filename.length();
                    if ((len > 4 && upper_filename.rfind(OBF(".RSA")) == len - 4) ||
                        (len > 4 && upper_filename.rfind(OBF(".DSA")) == len - 4) ||
                        (len > 3 && upper_filename.rfind(OBF(".EC")) == len - 3)) {
                            return filename;
                        }
                }

            size_t next_offset = sizeof(ZipCentralDirEntry) + entry->filename_len + entry->extra_len + entry->comment_len;

            if (cd_ptr + next_offset > cd_end) {
                    return "";
                }

            cd_ptr += next_offset;
        }

    return "";
}