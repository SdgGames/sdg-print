#pragma once

#include "frame_log.h"
#include "log.h"

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

class PrintSettings;

// A single log entry with all associated metadata, kept as separate components
// (not a formatted string) so output can be filtered and formatted after the fact.
// GDScript's LogEntry.new(level, module, message, frame) becomes LogEntry.create(...).
class LogEntry : public RefCounted {
	GDCLASS(LogEntry, RefCounted)

	int64_t timestamp = 0; // Microseconds (Time.get_ticks_usec).
	int level = Log::LEVEL_SILENT; // Kept as int: from_dict of corrupt data can yield -1, same as GDScript.
	StringName module;
	String message;
	int64_t frame_number = 0;
	Ref<FrameLog> current_frame;

protected:
	static void _bind_methods();

public:
	static Ref<LogEntry> create(int p_level, const StringName &p_module, const String &p_message, const Ref<FrameLog> &p_current_frame);
	static Ref<LogEntry> wrap_frame(const Ref<FrameLog> &p_frame, const StringName &p_module);
	static Ref<LogEntry> from_dict(const Dictionary &p_data, const StringName &p_module);

	void set_timestamp(int64_t p_timestamp) { timestamp = p_timestamp; }
	int64_t get_timestamp() const { return timestamp; }
	void set_level(int p_level) { level = p_level; }
	int get_level() const { return level; }
	void set_module(const StringName &p_module) { module = p_module; }
	StringName get_module() const { return module; }
	void set_message(const String &p_message) { message = p_message; }
	String get_message() const { return message; }
	void set_frame_number(int64_t p_frame_number) { frame_number = p_frame_number; }
	int64_t get_frame_number() const { return frame_number; }
	void set_current_frame(const Ref<FrameLog> &p_frame) { current_frame = p_frame; }
	Ref<FrameLog> get_current_frame() const { return current_frame; }

	String format(const Ref<PrintSettings> &p_settings) const;
	String get_time_string() const; // HH:MM:SS.mmm

	Dictionary to_dict() const;

	LogEntry();
};

} // namespace godot
