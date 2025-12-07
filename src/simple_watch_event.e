note
	description: "File system change event"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SIMPLE_WATCH_EVENT

create
	make

feature {NONE} -- Initialization

	make (a_type: INTEGER; a_filename: STRING_8)
			-- Create event with `a_type' and `a_filename'.
		do
			event_type := a_type
			filename := a_filename
		end

feature -- Access

	event_type: INTEGER
			-- Type of change: 1=added, 2=removed, 3=modified, 4=renamed.

	filename: STRING_8
			-- Name of the affected file.

feature -- Status

	is_added: BOOLEAN
			-- Was a file added?
		do
			Result := event_type = 1
		end

	is_removed: BOOLEAN
			-- Was a file removed?
		do
			Result := event_type = 2
		end

	is_modified: BOOLEAN
			-- Was a file modified?
		do
			Result := event_type = 3
		end

	is_renamed: BOOLEAN
			-- Was a file renamed?
		do
			Result := event_type = 4
		end

	event_type_string: STRING_8
			-- Human-readable event type.
		do
			inspect event_type
			when 1 then Result := "added"
			when 2 then Result := "removed"
			when 3 then Result := "modified"
			when 4 then Result := "renamed"
			else
				Result := "unknown"
			end
		end

end
