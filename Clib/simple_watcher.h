/*
 * simple_watcher.h - Cross-platform File system watcher for Eiffel
 *
 * Windows: Uses ReadDirectoryChangesW with overlapped I/O
 * Linux: Uses inotify
 * macOS: Uses FSEvents (TODO - not implemented yet)
 *
 * Copyright (c) 2025 Larry Rix - MIT License
 */

#ifndef SIMPLE_WATCHER_H
#define SIMPLE_WATCHER_H

#if defined(_WIN32) || defined(EIF_WINDOWS)
#include <windows.h>
#endif

/* Change event types */
#define SWE_FILE_ADDED      1
#define SWE_FILE_REMOVED    2
#define SWE_FILE_MODIFIED   3
#define SWE_FILE_RENAMED    4

/* Watch flags */
#define SWF_FILE_NAME       0x0001
#define SWF_DIR_NAME        0x0002
#define SWF_ATTRIBUTES      0x0004
#define SWF_SIZE            0x0008
#define SWF_LAST_WRITE      0x0010
#define SWF_SECURITY        0x0020
#define SWF_ALL             0x003F

/* Change event structure */
typedef struct {
    int event_type;
    char* filename;
    char* old_filename;  /* For rename events */
} sw_event;

/* Watcher handle structure - Platform specific */
#if defined(_WIN32) || defined(EIF_WINDOWS)
typedef struct {
    HANDLE directory_handle;
    HANDLE event_handle;
    OVERLAPPED overlapped;
    char* watch_path;
    int watch_subtree;
    DWORD filter;
    unsigned char buffer[8192];
    int is_watching;
    sw_event* pending_event;
    char* error_message;
} sw_watcher;
#else
/* Linux inotify implementation */
typedef struct {
    int inotify_fd;           /* inotify file descriptor */
    int watch_descriptor;     /* watch descriptor for the directory */
    char* watch_path;
    int watch_subtree;        /* Note: inotify doesn't natively support subtree */
    int filter;               /* Our SWF_* flags */
    unsigned char buffer[8192];
    int buffer_len;           /* Bytes in buffer */
    int buffer_pos;           /* Current position in buffer */
    int is_watching;
    sw_event* pending_event;
    char* error_message;
} sw_watcher;
#endif

/* Create a watcher for a directory.
 * path: directory to watch
 * watch_subtree: if non-zero, watch subdirectories too
 * flags: combination of SWF_* flags
 * Returns NULL on failure.
 */
sw_watcher* sw_create(const char* path, int watch_subtree, int flags);

/* Start watching for changes. Must be called before polling.
 * Returns 1 on success.
 */
int sw_start(sw_watcher* watcher);

/* Check for a change event without blocking.
 * Returns event if one is available, NULL otherwise.
 * Caller must free the event with sw_free_event.
 */
sw_event* sw_poll(sw_watcher* watcher);

/* Wait for a change event with timeout (milliseconds).
 * Returns event if one is received, NULL on timeout.
 * Use -1 for infinite wait.
 */
sw_event* sw_wait(sw_watcher* watcher, int timeout_ms);

/* Check if watcher is active. */
int sw_is_watching(sw_watcher* watcher);

/* Get the watch path. */
const char* sw_get_path(sw_watcher* watcher);

/* Get the last error message. */
const char* sw_get_error(sw_watcher* watcher);

/* Stop watching and free resources. */
void sw_close(sw_watcher* watcher);

/* Free an event structure. */
void sw_free_event(sw_event* event);

#endif /* SIMPLE_WATCHER_H */
