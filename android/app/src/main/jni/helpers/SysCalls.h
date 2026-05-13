#ifndef SYSCALL_SYSCALLS_H
#define SYSCALL_SYSCALLS_H


#include <cstddef>
#include <vector>

class SysCalls {

public:
    static std::vector<uint8_t> read_file_direct_alloc(const char *filepath);



};


#endif //SYSCALL_SYSCALLS_H
