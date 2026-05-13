#include <sys/types.h>
#include <asm-generic/fcntl.h>
#include <malloc.h>
#include "SysCalls.h"
#include <vector>
#include "obfusheader.h"
// For Android NDK compatibility
#ifndef AT_FDCWD
#define AT_FDCWD -100
#endif

// Architecture-specific syscall implementations
#if defined(__aarch64__)

// ARM64
static inline long direct_syscall(long number, long arg1, long arg2, long arg3, long arg4) {
    long result;
    asm volatile(
            "mov w8, %w1\n"      // syscall number
            "mov x0, %2\n"       // arg1
            "mov x1, %3\n"       // arg2
            "mov x2, %4\n"       // arg3
            "mov x3, %5\n"       // arg4
            "svc #0\n"           // system call
            "mov %0, x0\n"       // result
            : "=r"(result)
            : "r"(number), "r"(arg1), "r"(arg2), "r"(arg3), "r"(arg4)
            : "cc", "memory", "x0", "x1", "x2", "x3", "x8"
            );
    return result;
}

#elif defined(__arm__)
// ARM 32-bit
static inline long direct_syscall(long number, long arg1, long arg2, long arg3, long arg4) {
    long result;
    asm volatile(
            "mov r7, %1\n"       // syscall number
            "mov r0, %2\n"       // arg1
            "mov r1, %3\n"       // arg2
            "mov r2, %4\n"       // arg3
            "mov r3, %5\n"       // arg4
            "svc #0\n"           // system call
            "mov %0, r0\n"       // result
            : "=r"(result)
            : "r"(number), "r"(arg1), "r"(arg2), "r"(arg3), "r"(arg4)
            : "cc", "memory", "r0", "r1", "r2", "r3", "r7"
            );
    return result;
}

#elif defined(__x86_64__)
// x86_64
static inline long direct_syscall(long number, long arg1, long arg2, long arg3, long arg4) {
    long result;
    asm volatile(
            "mov %1, %%rax\n"    // syscall number
            "mov %2, %%rdi\n"    // arg1
            "mov %3, %%rsi\n"    // arg2
            "mov %4, %%rdx\n"    // arg3
            "mov %5, %%r10\n"    // arg4 (note: r10, not rcx)
            "syscall\n"          // system call
            "mov %%rax, %0\n"    // result
            : "=r"(result)
            : "r"(number), "r"(arg1), "r"(arg2), "r"(arg3), "r"(arg4)
            : "cc", "memory", "rax", "rdi", "rsi", "rdx", "r10", "r11", "rcx"
            );
    return result;
}

#elif defined(__i386__)

// x86 32-bit
static long direct_syscall(long number, long arg1, long arg2, long arg3, long arg4) {
    long result;
    asm volatile(
            "int $0x80"
            : "=a" (result) // Output: result is in the eax register
            : "a" (number), "b" (arg1), "c" (arg2), "d" (arg3), "S" (arg4) // Inputs
            : "cc", "memory" // Clobbered registers (flags and memory)
            );
    return result;
}

#else
#error "Unsupported architecture"
#endif

// Architecture-specific syscall numbers (Android NDK compatible)
#if defined(__aarch64__)
// ARM64 syscall numbers (Android)
#define SYS_OPENAT  56
#define SYS_CLOSE   57
#define SYS_READ    63
#define SYS_WRITE   64
#define SYS_MMAP    222
#define SYS_MUNMAP  215
#elif defined(__arm__)
// ARM32 syscall numbers (Android)
#define SYS_OPENAT  322
#define SYS_CLOSE   6
#define SYS_READ    3
#define SYS_WRITE   4
#define SYS_MMAP2   192
#define SYS_MUNMAP  91
#elif defined(__x86_64__)
// x86_64 syscall numbers (Android x86_64)
#define SYS_OPENAT  257
#define SYS_CLOSE   3
#define SYS_READ    0
#define SYS_WRITE   1
#define SYS_MMAP    9
#define SYS_MUNMAP  11
#elif defined(__i386__)
// x86 32-bit syscall numbers (Android x86)
#define SYS_OPENAT  295
#define SYS_CLOSE   6
#define SYS_READ    3
#define SYS_WRITE   4
#define SYS_MMAP2   192
#define SYS_MUNMAP  91
#endif

static inline long syscall_openat(int dirfd, const char *pathname, int flags, mode_t mode) {
    return direct_syscall(SYS_OPENAT, dirfd, (long) pathname, flags, mode);
}

static inline long syscall_read(int fd, void *buf, size_t count) {
    return direct_syscall(SYS_READ, fd, (long) buf, count, 0);
}


static inline long syscall_close(int fd) {
    return direct_syscall(SYS_CLOSE, fd, 0, 0, 0);
}

static inline int syscall_failed(long result) {
    return result < 0 && result >= -4095;
}


std::vector<uint8_t> SysCalls::read_file_direct_alloc(const char *filepath) {
    long fd = syscall_openat(AT_FDCWD, filepath, O_RDONLY, 0);
    if (syscall_failed(fd)) {
            return std::vector<uint8_t>();
        }

    std::vector<uint8_t> buffer;
    char temp_buffer[4096];
    long bytes_read;

    while ((bytes_read = syscall_read((int) fd, temp_buffer, sizeof(temp_buffer))) > 0) {
        buffer.insert(buffer.end(), temp_buffer, temp_buffer + bytes_read);
    }

    syscall_close((int) fd);

    if (syscall_failed(bytes_read)) {
            return std::vector<uint8_t>();
        }

    return buffer;
}
