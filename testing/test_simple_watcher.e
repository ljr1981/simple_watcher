note
	description: "Tests for SIMPLE_WATCHER library"
	testing: "type/manual"

class
	TEST_SIMPLE_WATCHER

inherit
	TEST_SET_BASE
		redefine
			on_prepare,
			on_clean
		end

feature -- Setup

	on_prepare
			-- Set up test fixtures.
		local
			l_dir: DIRECTORY
		do
			-- Create test directory
			create l_dir.make (test_dir_path)
			if not l_dir.exists then
				l_dir.create_dir
			end
		end

	on_clean
			-- Clean up after tests.
		local
			l_dir: DIRECTORY
			l_file: RAW_FILE
		do
			-- Clean up test files
			create l_file.make_with_name (test_dir_path + "\test_file.txt")
			if l_file.exists then
				l_file.delete
			end
			create l_file.make_with_name (test_dir_path + "\another_file.txt")
			if l_file.exists then
				l_file.delete
			end
			-- Remove test directory (must be empty)
			create l_dir.make (test_dir_path)
			if l_dir.exists and l_dir.is_empty then
				l_dir.delete
			end
		end

feature -- Access

	test_dir_path: STRING = "simple_watcher_test_dir"
			-- Path to test directory.

	Watch_all_flag: INTEGER = 0x003F
			-- Watch all changes flag value.

feature -- Test: Watcher Creation

	test_watcher_creation
			-- Test creating a watcher.
		local
			l_watcher: SIMPLE_WATCHER
		do
			create l_watcher.make (test_dir_path, False, Watch_all_flag)
			assert ("watcher valid", l_watcher.is_valid)
			assert ("not watching initially", not l_watcher.is_watching)
			l_watcher.close
		end

	test_watcher_start
			-- Test starting a watcher.
		local
			l_watcher: SIMPLE_WATCHER
		do
			create l_watcher.make (test_dir_path, False, Watch_all_flag)
			assert ("watcher valid", l_watcher.is_valid)

			l_watcher.start
			assert ("start succeeded", l_watcher.last_start_succeeded)
			assert ("is watching", l_watcher.is_watching)

			l_watcher.close
		end

	test_watcher_close
			-- Test closing a watcher.
		local
			l_watcher: SIMPLE_WATCHER
		do
			create l_watcher.make (test_dir_path, False, Watch_all_flag)
			l_watcher.start
			assert ("watching", l_watcher.is_watching)

			l_watcher.close
			assert ("not valid after close", not l_watcher.is_valid)
		end

feature -- Test: Watch Path

	test_watch_path
			-- Test getting the watch path.
		local
			l_watcher: SIMPLE_WATCHER
			l_path: detachable STRING_8
		do
			create l_watcher.make (test_dir_path, False, Watch_all_flag)
			l_path := l_watcher.watch_path
			assert ("path not void", l_path /= Void)
			if attached l_path as p then
				assert ("path correct", p.same_string (test_dir_path))
			end
			l_watcher.close
		end

feature -- Test: Poll Without Changes

	test_poll_no_changes
			-- Test polling when no changes occurred.
		local
			l_watcher: SIMPLE_WATCHER
			l_event: detachable SIMPLE_WATCH_EVENT
		do
			create l_watcher.make (test_dir_path, False, Watch_all_flag)
			l_watcher.start

			-- Poll immediately - should have no events
			l_event := l_watcher.poll
			assert ("no event on immediate poll", l_event = Void)

			l_watcher.close
		end

feature -- Test: Invalid Directory

	test_invalid_directory
			-- Test creating watcher for nonexistent directory.
		local
			l_watcher: SIMPLE_WATCHER
		do
			create l_watcher.make ("nonexistent_dir_12345", False, Watch_all_flag)
			-- May or may not be valid depending on how the C code handles it
			-- But should not crash
			if l_watcher.is_valid then
				l_watcher.close
			end
		end

feature -- Test: Watch Flags

	test_watch_flag_constants
			-- Test that watch flag constants are defined.
		local
			l_watcher: SIMPLE_WATCHER
		do
			create l_watcher.make (test_dir_path, False, Watch_all_flag)
			assert ("file_name flag", l_watcher.Watch_file_name = 0x0001)
			assert ("dir_name flag", l_watcher.Watch_dir_name = 0x0002)
			assert ("attributes flag", l_watcher.Watch_attributes = 0x0004)
			assert ("size flag", l_watcher.Watch_size = 0x0008)
			assert ("last_write flag", l_watcher.Watch_last_write = 0x0010)
			assert ("security flag", l_watcher.Watch_security = 0x0020)
			assert ("all flag", l_watcher.Watch_all = 0x003F)
			l_watcher.close
		end

feature -- Test: Event Type Constants

	test_event_type_constants
			-- Test that event type constants are defined.
		local
			l_watcher: SIMPLE_WATCHER
		do
			create l_watcher.make (test_dir_path, False, Watch_all_flag)
			assert ("added event", l_watcher.Event_file_added = 1)
			assert ("removed event", l_watcher.Event_file_removed = 2)
			assert ("modified event", l_watcher.Event_file_modified = 3)
			assert ("renamed event", l_watcher.Event_file_renamed = 4)
			l_watcher.close
		end

feature -- Test: Watch Event

	test_watch_event_class
			-- Test SIMPLE_WATCH_EVENT class.
		local
			l_event: SIMPLE_WATCH_EVENT
		do
			create l_event.make (1, "test.txt")
			assert ("is added", l_event.is_added)
			assert ("not removed", not l_event.is_removed)
			assert ("filename", l_event.filename.same_string ("test.txt"))
			assert ("type string", l_event.event_type_string.same_string ("added"))

			create l_event.make (2, "deleted.txt")
			assert ("is removed", l_event.is_removed)

			create l_event.make (3, "changed.txt")
			assert ("is modified", l_event.is_modified)

			create l_event.make (4, "renamed.txt")
			assert ("is renamed", l_event.is_renamed)
		end

end
