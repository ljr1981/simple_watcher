/*
 * simple_watcher.c - File system watcher for Eiffel
 * Copyright (c) 2025 Larry Rix - MIT License
 */

#include "simple_watcher.h"
#include <stdlib.h>
#include <string.h>

static char last_error_msg[512] = {0};

static void store_last_error(void) {
    DWORD err = GetLastError();
    FormatMessageA(
        FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL, err,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        last_error_msg, sizeof(last_error_msg) - 1, NULL
    );
}

static DWORD flags_to_filter(int flags) {
    DWORD filter = 0;
    if (flags & SWF_FILE_NAME)  filter |= FILE_NOTIFY_CHANGE_FILE_NAME;
    if (flags & SWF_DIR_NAME)   filter |= FILE_NOTIFY_CHANGE_DIR_NAME;
    if (flags & SWF_ATTRIBUTES) filter |= FILE_NOTIFY_CHANGE_ATTRIBUTES;
    if (flags & SWF_SIZE)       filter |= FILE_NOTIFY_CHANGE_SIZE;
    if (flags & SWF_LAST_WRITE) filter |= FILE_NOTIFY_CHANGE_LAST_WRITE;
    if (flags & SWF_SECURITY)   filter |= FILE_NOTIFY_CHANGE_SECURITY;
    return filter;
}

static int action_to_event_type(DWORD action) {
    switch (action) {
        case FILE_ACTION_ADDED:            return SWE_FILE_ADDED;
        case FILE_ACTION_REMOVED:          return SWE_FILE_REMOVED;
        case FILE_ACTION_MODIFIED:         return SWE_FILE_MODIFIED;
        case FILE_ACTION_RENAMED_OLD_NAME: return SWE_FILE_RENAMED;
        case FILE_ACTION_RENAMED_NEW_NAME: return SWE_FILE_RENAMED;
        default:                           return SWE_FILE_MODIFIED;
    }
}

sw_watcher* sw_create(const char* path, int watch_subtree, int flags) {
    sw_watcher* w;

    w = (sw_watcher*)malloc(sizeof(sw_watcher));
    if (!w) return NULL;
    memset(w, 0, sizeof(sw_watcher));

    w->watch_path = _strdup(path);
    w->watch_subtree = watch_subtree;
    w->filter = flags_to_filter(flags);

    /* Open directory */
    w->directory_handle = CreateFileA(
        path,
        FILE_LIST_DIRECTORY,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL,
        OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
        NULL
    );

    if (w->directory_handle == INVALID_HANDLE_VALUE) {
        store_last_error();
        w->error_message = _strdup(last_error_msg);
        return w;
    }

    /* Create event for overlapped I/O */
    w->event_handle = CreateEvent(NULL, TRUE, FALSE, NULL);
    if (!w->event_handle) {
        store_last_error();
        w->error_message = _strdup(last_error_msg);
        CloseHandle(w->directory_handle);
        w->directory_handle = INVALID_HANDLE_VALUE;
        return w;
    }

    w->overlapped.hEvent = w->event_handle;

    return w;
}

int sw_start(sw_watcher* watcher) {
    BOOL result;

    if (!watcher || watcher->directory_handle == INVALID_HANDLE_VALUE) {
        return 0;
    }

    ResetEvent(watcher->event_handle);

    result = ReadDirectoryChangesW(
        watcher->directory_handle,
        watcher->buffer,
        sizeof(watcher->buffer),
        watcher->watch_subtree,
        watcher->filter,
        NULL,
        &watcher->overlapped,
        NULL
    );

    if (!result && GetLastError() != ERROR_IO_PENDING) {
        store_last_error();
        if (watcher->error_message) free(watcher->error_message);
        watcher->error_message = _strdup(last_error_msg);
        return 0;
    }

    watcher->is_watching = 1;
    return 1;
}

static sw_event* process_notification(sw_watcher* watcher, FILE_NOTIFY_INFORMATION* info) {
    sw_event* event;
    int filename_len;
    char* filename;

    event = (sw_event*)malloc(sizeof(sw_event));
    if (!event) return NULL;
    memset(event, 0, sizeof(sw_event));

    event->event_type = action_to_event_type(info->Action);

    /* Convert wide filename to narrow */
    filename_len = WideCharToMultiByte(CP_UTF8, 0, info->FileName,
                                       info->FileNameLength / sizeof(WCHAR),
                                       NULL, 0, NULL, NULL);
    filename = (char*)malloc(filename_len + 1);
    if (filename) {
        WideCharToMultiByte(CP_UTF8, 0, info->FileName,
                           info->FileNameLength / sizeof(WCHAR),
                           filename, filename_len, NULL, NULL);
        filename[filename_len] = '\0';
        event->filename = filename;
    }

    return event;
}

sw_event* sw_poll(sw_watcher* watcher) {
    DWORD wait_result;
    DWORD bytes_returned;
    FILE_NOTIFY_INFORMATION* info;
    sw_event* event;

    if (!watcher || !watcher->is_watching) {
        return NULL;
    }

    /* Check if event signaled without waiting */
    wait_result = WaitForSingleObject(watcher->event_handle, 0);
    if (wait_result != WAIT_OBJECT_0) {
        return NULL;
    }

    /* Get result */
    if (!GetOverlappedResult(watcher->directory_handle, &watcher->overlapped,
                             &bytes_returned, FALSE)) {
        return NULL;
    }

    if (bytes_returned == 0) {
        /* Restart watching */
        sw_start(watcher);
        return NULL;
    }

    /* Process first notification */
    info = (FILE_NOTIFY_INFORMATION*)watcher->buffer;
    event = process_notification(watcher, info);

    /* Restart watching for next change */
    sw_start(watcher);

    return event;
}

sw_event* sw_wait(sw_watcher* watcher, int timeout_ms) {
    DWORD wait_result;
    DWORD bytes_returned;
    FILE_NOTIFY_INFORMATION* info;
    sw_event* event;
    DWORD timeout;

    if (!watcher || !watcher->is_watching) {
        return NULL;
    }

    timeout = (timeout_ms < 0) ? INFINITE : (DWORD)timeout_ms;

    wait_result = WaitForSingleObject(watcher->event_handle, timeout);
    if (wait_result != WAIT_OBJECT_0) {
        return NULL;
    }

    /* Get result */
    if (!GetOverlappedResult(watcher->directory_handle, &watcher->overlapped,
                             &bytes_returned, FALSE)) {
        return NULL;
    }

    if (bytes_returned == 0) {
        sw_start(watcher);
        return NULL;
    }

    /* Process first notification */
    info = (FILE_NOTIFY_INFORMATION*)watcher->buffer;
    event = process_notification(watcher, info);

    /* Restart watching */
    sw_start(watcher);

    return event;
}

int sw_is_watching(sw_watcher* watcher) {
    return watcher ? watcher->is_watching : 0;
}

const char* sw_get_path(sw_watcher* watcher) {
    return watcher ? watcher->watch_path : NULL;
}

const char* sw_get_error(sw_watcher* watcher) {
    return watcher ? watcher->error_message : NULL;
}

void sw_close(sw_watcher* watcher) {
    if (watcher) {
        if (watcher->directory_handle != INVALID_HANDLE_VALUE) {
            CancelIo(watcher->directory_handle);
            CloseHandle(watcher->directory_handle);
        }
        if (watcher->event_handle) {
            CloseHandle(watcher->event_handle);
        }
        if (watcher->watch_path) {
            free(watcher->watch_path);
        }
        if (watcher->error_message) {
            free(watcher->error_message);
        }
        if (watcher->pending_event) {
            sw_free_event(watcher->pending_event);
        }
        free(watcher);
    }
}

void sw_free_event(sw_event* event) {
    if (event) {
        if (event->filename) free(event->filename);
        if (event->old_filename) free(event->old_filename);
        free(event);
    }
}
