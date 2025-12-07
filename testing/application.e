note
	description: "Test application for simple_watcher"
	date: "$Date$"
	revision: "$Revision$"

class
	APPLICATION

create
	make

feature -- Initialization

	make
			-- Run tests.
		local
			l_tests: TEST_SIMPLE_WATCHER
			l_passed, l_failed: INTEGER
		do
			print ("Testing SIMPLE_WATCHER...%N%N")

			create l_tests

			-- Test: Watcher creation
			print ("  test_watcher_creation: ")
			l_tests.on_prepare
			l_tests.test_watcher_creation
			l_tests.on_clean
			print ("PASSED%N")
			l_passed := l_passed + 1

			-- Test: Watcher start
			print ("  test_watcher_start: ")
			l_tests.on_prepare
			l_tests.test_watcher_start
			l_tests.on_clean
			print ("PASSED%N")
			l_passed := l_passed + 1

			-- Test: Watcher close
			print ("  test_watcher_close: ")
			l_tests.on_prepare
			l_tests.test_watcher_close
			l_tests.on_clean
			print ("PASSED%N")
			l_passed := l_passed + 1

			-- Test: Watch path
			print ("  test_watch_path: ")
			l_tests.on_prepare
			l_tests.test_watch_path
			l_tests.on_clean
			print ("PASSED%N")
			l_passed := l_passed + 1

			-- Test: Poll no changes
			print ("  test_poll_no_changes: ")
			l_tests.on_prepare
			l_tests.test_poll_no_changes
			l_tests.on_clean
			print ("PASSED%N")
			l_passed := l_passed + 1

			-- Test: Invalid directory
			print ("  test_invalid_directory: ")
			l_tests.on_prepare
			l_tests.test_invalid_directory
			l_tests.on_clean
			print ("PASSED%N")
			l_passed := l_passed + 1

			-- Test: Watch flag constants
			print ("  test_watch_flag_constants: ")
			l_tests.on_prepare
			l_tests.test_watch_flag_constants
			l_tests.on_clean
			print ("PASSED%N")
			l_passed := l_passed + 1

			-- Test: Event type constants
			print ("  test_event_type_constants: ")
			l_tests.on_prepare
			l_tests.test_event_type_constants
			l_tests.on_clean
			print ("PASSED%N")
			l_passed := l_passed + 1

			-- Test: Watch event class
			print ("  test_watch_event_class: ")
			l_tests.on_prepare
			l_tests.test_watch_event_class
			l_tests.on_clean
			print ("PASSED%N")
			l_passed := l_passed + 1

			print ("%N======================================%N")
			print ("Results: " + l_passed.out + " passed, " + l_failed.out + " failed%N")
		rescue
			print ("FAILED%N")
			l_failed := l_failed + 1
			retry
		end

end
