#pragma once

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

// Log information for a single frame of execution: a title plus detail lines.
// Used internally by Log; shouldn't be created manually.
// GDScript's FrameLog.new(title, details) becomes FrameLog.create(title, details).
class FrameLog : public RefCounted {
	GDCLASS(FrameLog, RefCounted)

	String title;
	String details;
	bool is_complete = false;

protected:
	static void _bind_methods();

public:
	static Ref<FrameLog> create(const String &p_title = String(), const String &p_details = String());

	void set_title(const String &p_title) { title = p_title; }
	String get_title() const { return title; }
	void set_details(const String &p_details) { details = p_details; }
	String get_details() const { return details; }
	void set_is_complete(bool p_complete) { is_complete = p_complete; }
	bool get_is_complete() const { return is_complete; }

	String format(bool p_include_title = false) const;

	Dictionary to_dict() const;
	static Ref<FrameLog> from_dict(const Dictionary &p_data);
};

} // namespace godot
