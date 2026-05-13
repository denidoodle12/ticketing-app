//sse notification pakai curl c++ ( walau ratusan line bisa running 10x lebih cpt dari pada flutter dio yg hanya2 line)

#include <jni.h>
#include <android/log.h>

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

#include <curl/curl.h>
#define LOG_TAG "JavaLoader"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
enum SseStatus : int32_t {
    SSE_STATUS_CONNECTING   = 1,
    SSE_STATUS_CONNECTED    = 2,
    SSE_STATUS_DISCONNECTED = 3,
    SSE_STATUS_RECONNECTING = 4,
    SSE_STATUS_UNAUTHORIZED = 5,
    SSE_STATUS_FATAL        = 6,
};
using sse_event_cb  = void (*)(const char* event, const char* data);
using sse_status_cb = void (*)(int32_t status, const char* info);
namespace {

std::atomic<bool> g_running{false};
std::atomic<bool> g_stop_requested{false};
std::atomic<bool> g_token_updated{false};
std::atomic<bool> g_connected_emitted{false};

std::thread      g_worker;
std::mutex       g_token_mutex;
std::string      g_bearer_token;
std::string      g_url;
std::string      g_ca_bundle_path;
sse_event_cb  g_on_event  = nullptr;
sse_status_cb g_on_status = nullptr;
std::string g_line_buf;
std::string g_event_name;
std::string g_event_data;

// Helpers jgn dihapus
void emit_status(int32_t code, const char* info) {
    if (g_on_status) {
        char* info_copy = strdup(info ? info : "");
        g_on_status(code, info_copy);
    }
}

void flush_event() {
    if (!g_event_name.empty() || !g_event_data.empty()) {
        LOGI("[SSE] dispatch event='%s' data_len=%zu",
             g_event_name.c_str(), g_event_data.size());
        if (g_on_event) {
            char* evt_copy = strdup(g_event_name.c_str());
            char* dta_copy = strdup(g_event_data.c_str());
            g_on_event(evt_copy, dta_copy);
        } else {
            LOGW("[SSE] g_on_event is null; dropping event '%s'",
                 g_event_name.c_str());
        }
    }
    g_event_name.clear();
    g_event_data.clear();
}

void handle_line(const std::string& line) {
    if (line.empty()) {
        flush_event();
        return;
    }
    if (line[0] == ':') {
        LOGD("[SSE] heartbeat: %s", line.c_str());
        return;
    }
    LOGI("[SSE] line: %s", line.c_str());
    if (line.rfind("event:", 0) == 0) {
        auto v = line.substr(6);
        size_t s = v.find_first_not_of(" \t");
        g_event_name = (s == std::string::npos) ? "" : v.substr(s);
    } else if (line.rfind("data:", 0) == 0) {
        auto v = line.substr(5);
        size_t s = v.find_first_not_of(" \t");
        g_event_data = (s == std::string::npos) ? "" : v.substr(s);
    }
}
size_t write_cb(char* ptr, size_t size, size_t nmemb, void* /*userdata*/) {
    const size_t n = size * nmemb;
    if (!g_connected_emitted.load() && n > 0) {
        g_connected_emitted.store(true);
        LOGI("[SSE] stream established (first bytes received)");
        emit_status(SSE_STATUS_CONNECTED, nullptr);
    }

    for (size_t i = 0; i < n; ++i) {
        char c = ptr[i];
        if (c == '\r') continue;
        if (c == '\n') {
            handle_line(g_line_buf);
            g_line_buf.clear();
        } else {
            g_line_buf.push_back(c);
        }
    }
    return n;
}
int xfer_cb(void* /*clientp*/,
            curl_off_t /*dltotal*/, curl_off_t /*dlnow*/,
            curl_off_t /*ultotal*/, curl_off_t /*ulnow*/) {
    if (g_stop_requested.load()) return 1;
    return 0;
}

std::string build_auth_header() {
    std::lock_guard<std::mutex> lk(g_token_mutex);
    return std::string("Authorization: Bearer ") + g_bearer_token;
}


void worker_main() {
    LOGI("[SSE] worker_main started");
    curl_global_init(CURL_GLOBAL_DEFAULT);
    int attempt = 0;
    while (!g_stop_requested.load()) {
        g_line_buf.clear();
        g_event_name.clear();
        g_event_data.clear();
        g_token_updated.store(false);
        g_connected_emitted.store(false);

        CURL* curl = curl_easy_init();
        if (!curl) {
            LOGE("[SSE] curl_easy_init failed");
            emit_status(SSE_STATUS_FATAL, "curl_easy_init failed");
            break;
        }

        std::string auth = build_auth_header();

        struct curl_slist* headers = nullptr;
        headers = curl_slist_append(headers, auth.c_str());
        headers = curl_slist_append(headers, "Accept: text/event-stream");
        headers = curl_slist_append(headers, "Cache-Control: no-cache");
        headers = curl_slist_append(headers, "Connection: keep-alive");
        headers = curl_slist_append(headers, "Accept-Encoding: identity");

        std::string url_copy;
        {
            std::lock_guard<std::mutex> lk(g_token_mutex);
            url_copy = g_url;
        }

        curl_easy_setopt(curl, CURLOPT_URL, url_copy.c_str());
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
        curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0L);
        curl_easy_setopt(curl, CURLOPT_XFERINFOFUNCTION, xfer_cb);
        curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 30L);
        curl_easy_setopt(curl, CURLOPT_LOW_SPEED_TIME, 0L);
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, 0L);
        curl_easy_setopt(curl, CURLOPT_TCP_KEEPALIVE, 1L);
        curl_easy_setopt(curl, CURLOPT_TCP_KEEPIDLE, 30L);
        curl_easy_setopt(curl, CURLOPT_TCP_KEEPINTVL, 15L);
        curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
        curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
        {
            std::lock_guard<std::mutex> lk(g_token_mutex);
            if (!g_ca_bundle_path.empty()) {
                curl_easy_setopt(curl, CURLOPT_CAINFO, g_ca_bundle_path.c_str());
            }
        }
        curl_easy_setopt(curl, CURLOPT_HTTP_VERSION, (long)CURL_HTTP_VERSION_1_1);

        LOGI("[SSE] connecting (attempt %d) -> %s", attempt + 1, url_copy.c_str());
        emit_status(SSE_STATUS_CONNECTING, nullptr);
        CURLcode res = curl_easy_perform(curl);

        long http_code = 0;
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);

        if (!g_line_buf.empty()) {
            LOGI("[SSE] flushing trailing line on disconnect: %s",
                 g_line_buf.c_str());
            handle_line(g_line_buf);
            g_line_buf.clear();
        }
        flush_event();

        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);

        if (g_stop_requested.load()) {
            LOGI("[SSE] stop requested; exiting worker");
            emit_status(SSE_STATUS_DISCONNECTED, "stopped");
            break;
        }

        if (http_code == 401) {
            LOGW("[SSE] HTTP 401 — token invalid/expired");
            emit_status(SSE_STATUS_UNAUTHORIZED, "http 401");

            int waited_ms = 0;
            while (waited_ms < 30000 && !g_stop_requested.load() &&
                   !g_token_updated.load()) {
                std::this_thread::sleep_for(std::chrono::milliseconds(200));
                waited_ms += 200;
            }
            if (g_stop_requested.load()) break;
            if (!g_token_updated.load()) {
                LOGE("[SSE] No new token within 30s; giving up");
                emit_status(SSE_STATUS_FATAL, "token refresh timeout");
                break;
            }
            //fall through>immediate retry with new token
            attempt = 0;
            continue;
        }

        LOGW("[SSE] connection ended (CURLcode=%d, http=%ld, %s)",
             (int)res, http_code, curl_easy_strerror(res));

        int delay_s;
        if (http_code == 200) {
            delay_s = 1;
            attempt = 0;
            LOGI("[SSE] server closed mid-stream; quick reconnect in %ds", delay_s);
        } else {
            delay_s = 2 << std::min(attempt, 5);
            if (delay_s > 60) delay_s = 60;
            ++attempt;
            LOGI("[SSE] reconnecting in %ds (attempt %d)", delay_s, attempt);
        }

        emit_status(SSE_STATUS_RECONNECTING, nullptr);
        for (int i = 0; i < delay_s * 10 && !g_stop_requested.load(); ++i) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    }

    curl_global_cleanup();
    g_running.store(false);
    LOGI("[SSE] worker_main exited");
}

}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void ffi_sse_start(const char* url,
                   const char* token,
                   const char* ca_bundle_path,
                   sse_event_cb on_event,
                   sse_status_cb on_status) {
    if (g_running.load()) {
        LOGW("[SSE] start requested but worker already running; ignoring");
        return;
    }
    if (!url || !token) {
        LOGE("[SSE] start called with null url/token");
        return;
    }

    {
        std::lock_guard<std::mutex> lk(g_token_mutex);
        g_url = url;
        g_bearer_token = token;
        g_ca_bundle_path = (ca_bundle_path != nullptr) ? ca_bundle_path : "";
    }
    g_on_event  = on_event;
    g_on_status = on_status;

    g_stop_requested.store(false);
    g_token_updated.store(false);
    g_running.store(true);

    LOGI("[SSE] ffi_sse_start url=%s (token length=%zu, ca=%s)",
         url, strlen(token),
         (ca_bundle_path && *ca_bundle_path) ? ca_bundle_path : "<none>");
    try {
        if (g_worker.joinable()) {
            g_worker.detach();
        }
        g_worker = std::thread(worker_main);
    } catch (const std::exception& e) {
        LOGE("[SSE] failed to spawn worker thread: %s", e.what());
        g_running.store(false);
    }
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void ffi_sse_update_token(const char* token) {
    if (!token) return;
    {
        std::lock_guard<std::mutex> lk(g_token_mutex);
        g_bearer_token = token;
    }
    g_token_updated.store(true);
    LOGI("[SSE] token updated (length=%zu)", strlen(token));
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void ffi_sse_stop() {
    if (!g_running.load()) {
        LOGI("[SSE] stop requested but worker not running");
        return;
    }
    LOGI("[SSE] stop requested");
    g_stop_requested.store(true);
    if (g_worker.joinable()) {
        g_worker.join();
    }
    g_running.store(false);
    g_on_event  = nullptr;
    g_on_status = nullptr;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int ffi_sse_is_running() {
    return g_running.load() ? 1 : 0;
}
