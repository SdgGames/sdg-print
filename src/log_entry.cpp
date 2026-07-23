#include "log_entry.h"

#include "print_settings.h"
#include "sdg_print.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

// Left-justify in a field of p_width spaces, without truncating.
// Equivalent to GDScript's "%-*s" % [p_width, p_string].
static String ljust(const String &p_string, int64_t p_width) {
	if (p_string.length() >= p_width) {
		return p_string;
	}
	return p_string + String(" ").repeat(p_width - p_string.length());
}

// Microsecond timestamp -> "HH:MM:SS.mmm", matching the GDScript integer math.
static String format_time(int64_t p_usec) {
	int64_t msec = p_usec / 1000;
	int64_t seconds = msec / 1000;
	int64_t minutes = seconds / 60;
	int64_t hours = minutes / 60;

	return String::num_int64(hours % 24).pad_zeros(2) + String(":") +
			String::num_int64(minutes % 60).pad_zeros(2) + String(":") +
			String::num_int64(seconds % 60).pad_zeros(2) + String(".") +
			String::num_int64(msec % 1000).pad_zeros(3);
}

void LogEntry::_bind_methods() {
	ClassDB::bind_static_method("LogEntry", D_METHOD("create", "level", "module", "message", "current_frame"), &LogEntry::create);
	ClassDB::bind_static_method("LogEntry", D_METHOD("wrap_frame", "frame", "module"), &LogEntry::wrap_frame);
	ClassDB::bind_static_method("LogEntry", D_METHOD("from_dict", "data", "module"), &LogEntry::from_dict);

	ClassDB::bind_method(D_METHOD("set_timestamp", "timestamp"), &LogEntry::set_timestamp);
	ClassDB::bind_method(D_METHOD("get_timestamp"), &LogEntry::get_timestamp);
	ClassDB::bind_method(D_METHOD("set_level", "level"), &LogEntry::set_level);
	ClassDB::bind_method(D_METHOD("get_level"), &LogEntry::get_level);
	ClassDB::bind_method(D_METHOD("set_module", "module"), &LogEntry::set_module);
	ClassDB::bind_method(D_METHOD("get_module"), &LogEntry::get_module);
	ClassDB::bind_method(D_METHOD("set_message", "message"), &LogEntry::set_message);
	ClassDB::bind_method(D_METHOD("get_message"), &LogEntry::get_message);
	ClassDB::bind_method(D_METHOD("set_frame_number", "frame_number"), &LogEntry::set_frame_number);
	ClassDB::bind_method(D_METHOD("get_frame_number"), &LogEntry::get_frame_number);
	ClassDB::bind_method(D_METHOD("set_current_frame", "current_frame"), &LogEntry::set_current_frame);
	ClassDB::bind_method(D_METHOD("get_current_frame"), &LogEntry::get_current_frame);

	ADD_PROPERTY(PropertyInfo(Variant::INT, "timestamp"), "set_timestamp", "get_timestamp");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "level"), "set_level", "get_level");
	ADD_PROPERTY(PropertyInfo(Variant::STRING_NAME, "module"), "set_module", "get_module");
	ADD_PROPERTY(PropertyInfo(Variant::STRING, "message"), "set_message", "get_message");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "frame_number"), "set_frame_number", "get_frame_number");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "current_frame", PROPERTY_HINT_RESOURCE_TYPE, "FrameLog"), "set_current_frame", "get_current_frame");

	ClassDB::bind_method(D_METHOD("format", "settings"), &LogEntry::format);
	ClassDB::bind_method(D_METHOD("get_time_string"), &LogEntry::get_time_string);
	ClassDB::bind_method(D_METHOD("to_dict"), &LogEntry::to_dict);
}

LogEntry::LogEntry() {
	// GDScript's _init always stamped the entry; keep that for every construction path.
	if (Time::get_singleton()) {
		timestamp = Time::get_singleton()->get_ticks_usec();
	}
	if (Engine::get_singleton()) {
		frame_number = Engine::get_singleton()->get_frames_drawn();
	}
}

Ref<LogEntry> LogEntry::create(int p_level, const StringName &p_module, const String &p_message, const Ref<FrameLog> &p_current_frame) {
	Ref<LogEntry> entry;
	entry.instantiate();
	entry->level = p_level;
	entry->module = p_module;
	entry->message = p_message;
	entry->current_frame = p_current_frame;
	return entry;
}

Ref<LogEntry> LogEntry::wrap_frame(const Ref<FrameLog> &p_frame, const StringName &p_module) {
	// Empty message minimizes file size; a message can be generated when
	// building from a dictionary later.
	return create(Log::LEVEL_FRAME_ONLY, p_module, String(), p_frame);
}

Ref<LogEntry> LogEntry::from_dict(const Dictionary &p_data, const StringName &p_module) {
	int level_idx = Log::level_from_string(p_data["level"]);
	Ref<LogEntry> entry = create(level_idx, p_module, p_data["message"], Ref<FrameLog>());
	entry->timestamp = p_data["timestamp"]; // Load raw microseconds.
	entry->frame_number = p_data["frame_number"];
	if (p_data["current_frame"].get_type() != Variant::NIL) {
		entry->current_frame = FrameLog::from_dict(p_data["current_frame"]);
	}
	return entry;
}

String LogEntry::format(const Ref<PrintSettings> &p_settings) const {
	ERR_FAIL_COND_V_MSG(p_settings.is_null(), message, "LogEntry.format called with null settings.");

	String formatted_message;
	int64_t module_width = p_settings->get_max_module_width();
	if (!Engine::get_singleton()->is_editor_hint() && SDG_Print::get_singleton()) {
		module_width = SDG_Print::get_singleton()->get_current_module_width();
	}

	if (p_settings->get_show_timestamps()) {
		formatted_message += String("[color=#") + p_settings->get_timestamp_color().to_html(false) + String("][") +
				format_time(timestamp) + String("][/color] ");
	}

	if (p_settings->get_show_module_names()) {
		formatted_message += String("[b][color=#") + p_settings->get_module_name_color().to_html(false) + String("]") +
				ljust(String(module), module_width) + String("[/color][/b] ");
	}

	if (p_settings->get_show_log_levels()) {
		formatted_message += String("[color=#") + p_settings->get_level_color(level).to_html(false) + String("]") +
				ljust(Log::level_to_string(level) + String(":"), 8) + String("[/color] ");
	}

	formatted_message += message;

	return formatted_message;
}

String LogEntry::get_time_string() const {
	return format_time(timestamp);
}

Dictionary LogEntry::to_dict() const {
	Dictionary dict;
	dict["timestamp"] = timestamp; // Store raw microseconds.
	dict["level"] = Log::level_to_string(level);
	dict["message"] = message;
	dict["frame_number"] = frame_number;
	dict["current_frame"] = current_frame.is_null() ? Variant() : Variant(current_frame->to_dict());
	return dict;
}
