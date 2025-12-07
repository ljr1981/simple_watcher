note
	description: "[
		SCOOP-compatible file system watcher.
		Uses Win32 ReadDirectoryChangesW via C wrapper.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SIMPLE_WATCHER

create
	make

feature {NONE} -- Initialization

	make (a_path: READABLE_STRING_GENERAL; a_watch_subtree: BOOLEAN; a_flags: INTEGER)
			-- Create watcher for directory `a_path'.
			-- If `a_watch_subtree', subdirectories are also watched.
			-- `a_flags' is combination of Watch_* constants.
		require
			path_not_empty: not a_path.is_empty
		local
			l_path: C_STRING
		do
			create l_path.make (a_path.to_string_8)
			if a_watch_subtree then
				handle := c_sw_create (l_path.item, 1, a_flags)
			else
				handle := c_sw_create (l_path.item, 0, a_flags)
			end
		end

feature -- Constants: Watch Flags

	Watch_file_name: INTEGER = 0x0001
			-- Watch for file name changes (create, delete, rename).

	Watch_dir_name: INTEGER = 0x0002
			-- Watch for directory name changes.

	Watch_attributes: INTEGER = 0x0004
			-- Watch for attribute changes.

	Watch_size: INTEGER = 0x0008
			-- Watch for size changes.

	Watch_last_write: INTEGER = 0x0010
			-- Watch for last write time changes.

	Watch_security: INTEGER = 0x0020
			-- Watch for security descriptor changes.

	Watch_all: INTEGER = 0x003F
			-- Watch for all changes.

feature -- Constants: Event Types

	Event_file_added: INTEGER = 1
			-- A file was added.

	Event_file_removed: INTEGER = 2
			-- A file was removed.

	Event_file_modified: INTEGER = 3
			-- A file was modified.

	Event_file_renamed: INTEGER = 4
			-- A file was renamed.

feature -- Status

	is_valid: BOOLEAN
			-- Is the watcher handle valid?
		do
			Result := handle /= default_pointer
		end

	is_watching: BOOLEAN
			-- Is the watcher actively watching?
		do
			Result := handle /= default_pointer and then c_sw_is_watching (handle) /= 0
		end

	watch_path: detachable STRING_8
			-- The path being watched.
		local
			l_ptr: POINTER
			l_c_string: C_STRING
		do
			if handle /= default_pointer then
				l_ptr := c_sw_get_path (handle)
				if l_ptr /= default_pointer then
					create l_c_string.make_by_pointer (l_ptr)
					Result := l_c_string.string
				end
			end
		end

	last_error: detachable STRING_32
			-- Error message from last failed operation.
		local
			l_ptr: POINTER
			l_c_string: C_STRING
		do
			if handle /= default_pointer then
				l_ptr := c_sw_get_error (handle)
				if l_ptr /= default_pointer then
					create l_c_string.make_by_pointer (l_ptr)
					Result := l_c_string.string.to_string_32
				end
			end
		end

feature -- Operations

	start
			-- Start watching for changes.
		require
			valid: is_valid
		do
			last_start_succeeded := c_sw_start (handle) /= 0
		end

	poll: detachable SIMPLE_WATCH_EVENT
			-- Check for a change event without blocking.
			-- Returns Void if no event is pending.
		require
			valid: is_valid
			watching: is_watching
		local
			l_event_ptr: POINTER
		do
			l_event_ptr := c_sw_poll (handle)
			if l_event_ptr /= default_pointer then
				Result := event_from_pointer (l_event_ptr)
				c_sw_free_event (l_event_ptr)
			end
		end

	wait (a_timeout_ms: INTEGER): detachable SIMPLE_WATCH_EVENT
			-- Wait for a change event with timeout (milliseconds).
			-- Use -1 for infinite wait.
			-- Returns Void on timeout.
		require
			valid: is_valid
			watching: is_watching
		local
			l_event_ptr: POINTER
		do
			l_event_ptr := c_sw_wait (handle, a_timeout_ms)
			if l_event_ptr /= default_pointer then
				Result := event_from_pointer (l_event_ptr)
				c_sw_free_event (l_event_ptr)
			end
		end

	close
			-- Stop watching and release resources.
		do
			if handle /= default_pointer then
				c_sw_close (handle)
				handle := default_pointer
			end
		ensure
			closed: handle = default_pointer
		end

feature -- Status Report

	last_start_succeeded: BOOLEAN
			-- Did the last start operation succeed?

feature {NONE} -- Implementation

	handle: POINTER
			-- C handle to the watcher.

	event_from_pointer (a_ptr: POINTER): SIMPLE_WATCH_EVENT
			-- Create event object from C event pointer.
		local
			l_type: INTEGER
			l_filename_ptr: POINTER
			l_filename: STRING_8
			l_c_string: C_STRING
		do
			l_type := c_event_type (a_ptr)
			l_filename_ptr := c_event_filename (a_ptr)
			if l_filename_ptr /= default_pointer then
				create l_c_string.make_by_pointer (l_filename_ptr)
				l_filename := l_c_string.string
			else
				l_filename := ""
			end
			create Result.make (l_type, l_filename)
		end

feature {NONE} -- C Externals

	c_sw_create (a_path: POINTER; a_subtree, a_flags: INTEGER): POINTER
		external
			"C inline use %"simple_watcher.h%""
		alias
			"return sw_create((const char*)$a_path, $a_subtree, $a_flags);"
		end

	c_sw_start (a_handle: POINTER): INTEGER
		external
			"C inline use %"simple_watcher.h%""
		alias
			"return sw_start((sw_watcher*)$a_handle);"
		end

	c_sw_poll (a_handle: POINTER): POINTER
		external
			"C inline use %"simple_watcher.h%""
		alias
			"return sw_poll((sw_watcher*)$a_handle);"
		end

	c_sw_wait (a_handle: POINTER; a_timeout: INTEGER): POINTER
		external
			"C inline use %"simple_watcher.h%""
		alias
			"return sw_wait((sw_watcher*)$a_handle, $a_timeout);"
		end

	c_sw_is_watching (a_handle: POINTER): INTEGER
		external
			"C inline use %"simple_watcher.h%""
		alias
			"return sw_is_watching((sw_watcher*)$a_handle);"
		end

	c_sw_get_path (a_handle: POINTER): POINTER
		external
			"C inline use %"simple_watcher.h%""
		alias
			"return (char*)sw_get_path((sw_watcher*)$a_handle);"
		end

	c_sw_get_error (a_handle: POINTER): POINTER
		external
			"C inline use %"simple_watcher.h%""
		alias
			"return (char*)sw_get_error((sw_watcher*)$a_handle);"
		end

	c_sw_close (a_handle: POINTER)
		external
			"C inline use %"simple_watcher.h%""
		alias
			"sw_close((sw_watcher*)$a_handle);"
		end

	c_sw_free_event (a_event: POINTER)
		external
			"C inline use %"simple_watcher.h%""
		alias
			"sw_free_event((sw_event*)$a_event);"
		end

	c_event_type (a_event: POINTER): INTEGER
		external
			"C inline use %"simple_watcher.h%""
		alias
			"return ((sw_event*)$a_event)->event_type;"
		end

	c_event_filename (a_event: POINTER): POINTER
		external
			"C inline use %"simple_watcher.h%""
		alias
			"return ((sw_event*)$a_event)->filename;"
		end

end
