#ifndef SSE_CLIENT_H
#define SSE_CLIENT_H

#include <cstdint>

// SSE connection status codes
enum SseStatus : int32_t {
    SSE_STATUS_CONNECTING   = 1,
    SSE_STATUS_CONNECTED    = 2,
    SSE_STATUS_DISCONNECTED = 3,
    SSE_STATUS_RECONNECTING = 4,
    SSE_STATUS_UNAUTHORIZED = 5,
    SSE_STATUS_FATAL        = 6,
};

// Callback types
using sse_event_cb  = void (*)(const char* event, const char* data);
using sse_status_cb = void (*)(int32_t status, const char* info);

namespace sse {

/**
 * Start SSE client connection
 * @param url SSE endpoint URL
 * @param token Bearer token for authentication
 * @param ca_bundle_path Optional path to CA bundle for SSL verification
 * @param on_event Callback for SSE events
 * @param on_status Callback for connection status changes
 */
void start(const char* url,
           const char* token,
           const char* ca_bundle_path,
           sse_event_cb on_event,
           sse_status_cb on_status);

/**
 * Update bearer token (for token refresh)
 * @param token New bearer token
 */
void update_token(const char* token);

/**
 * Stop SSE client connection
 */
void stop();

/**
 * Check if SSE client is running
 * @return 1 if running, 0 otherwise
 */
int is_running();

} // namespace sse

#endif // SSE_CLIENT_H
