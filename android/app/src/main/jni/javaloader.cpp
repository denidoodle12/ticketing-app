// FFI Entry Point for Native Functions
// This file serves as the bridge between Dart FFI and native C++ implementations

#include <jni.h>
#include "sse/sse_client.h"
#include "security/signature_checker.h"

// ============================================================================
// SSE Client FFI Exports
// ============================================================================

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void ffi_sse_start(const char* url,
                   const char* token,
                   const char* ca_bundle_path,
                   sse_event_cb on_event,
                   sse_status_cb on_status) {
    sse::start(url, token, ca_bundle_path, on_event, on_status);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void ffi_sse_update_token(const char* token) {
    sse::update_token(token);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void ffi_sse_stop() {
    sse::stop();
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int ffi_sse_is_running() {
    return sse::is_running();
}

// ============================================================================
// Signature Verification FFI Export
// ============================================================================

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int ffi_verify_signature() {
    return security::verify_signature();
}
