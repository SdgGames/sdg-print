#pragma once

#include "frame_log.h"
#include "print_settings.h"
#include "ring_buffer.h"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/type_info.hpp>

namespace godot {

class LogEntry;

// A logging helper for a module or individual object. Prints to standard
// output (and the in-game console if present) subject to print_level, and
// silently archives history subject to archive_level so the full picture is
// available when an error dump fires.
class Log : public Node {
	GDCLASS(Log, Node)

public:
	// Lower number = higher priority. Filtering is `archive_level >= level`.
	// Enumerators carry a LEVEL_ prefix because ERROR/WARNING/DEBUG are Windows
	// system macros; they are bound to the clean names (Log.Level.ERROR) in
	// _bind_methods so the GDScript-facing API is unchanged.
	enum Level {
		LEVEL_SILENT = 0,
		LEVEL_ERROR = 1,
		LEVEL_WARNING = 2,
		LEVEL_INFO = 3,
		LEVEL_DEBUG = 4,
		LEVEL_VERBOSE = 5,
		LEVEL_FRAME_ONLY = 6, // Internal value for storing frames in dump files.
	};

	// Whether this logger is a member of the Print singleton, an instanced
	// node, or unknown.
	enum LogType {
		LOG_TYPE_SINGLETON = 0,
		LOG_TYPE_OBJECT = 1,
		LOG_TYPE_UNKNOWN = 2,
	};

private:
	String id;
	int print_level = LEVEL_VERBOSE;
	int archive_level = LEVEL_VERBOSE;
	Ref<PrintSettings> settings;

	bool _initialized = false;
	LogType _log_type = LOG_TYPE_OBJECT;
	ObjectID _console;

	Ref<RingBuffer> _log_history;
	Ref<RingBuffer> _frame_history;
	Ref<FrameLog> _current_frame;
	bool _has_frame_changes = false;

	Ref<LogEntry> _log(int p_level, const String &p_message);
	void _print_console(const String &p_message);

protected:
	static void _bind_methods();

public:
	void set_id(const String &p_id) { id = p_id; }
	String get_id() const { return id; }
	void set_print_level(int p_level) { print_level = p_level; }
	int get_print_level() const { return print_level; }
	void set_archive_level(int p_level) { archive_level = p_level; }
	int get_archive_level() const { return archive_level; }
	void set_settings(const Ref<PrintSettings> &p_settings) { settings = p_settings; }
	Ref<PrintSettings> get_settings() const { return settings; }

	LogType get_log_type() const { return _log_type; }
	void set_console(Object *p_console);

	// Setup that can't happen in the constructor (mirrors GDScript's pattern of
	// Godot calling _init for nodes in the scene tree). Returns self so calls
	// chain: Log.new()._second_init(...).
	Log *_second_init(const String &p_id = String(), int p_print_level = LEVEL_VERBOSE, int p_archive_level = LEVEL_VERBOSE,
			LogType p_log_type = LOG_TYPE_OBJECT, const Ref<PrintSettings> &p_custom_settings = Ref<PrintSettings>());

	// Clears the message and frame history for this logger instance.
	void start();

	// Throws an error if the statement is false.
	void assert_that(const Variant &p_is_true, const String &p_message = String());

	void error(const String &p_message, bool p_dump_error = true);
	void warning(const String &p_message, bool p_dump_warning = false);
	void info(const String &p_message);
	void debug(const String &p_message);
	void verbose(const String &p_message);
	void print_at_level(const String &p_message, const Variant &p_level);

	void start_frame(const String &p_title = String());
	void append_frame_title(const String &p_title);
	void in_frame(const String &p_line);
	void end_frame();
	String get_frame_title() const;
	String get_frame(bool p_prepend_title = false) const;

	Dictionary to_dict() const;

	// Mirrors GDScript's Log.Level.keys()[level] / .find(name), which native
	// enums don't support. All dump serialization goes through these so the
	// JSON format stays byte-compatible (level names, not numbers).
	static String level_to_string(int p_level);
	static int level_from_string(const String &p_name); // -1 when unknown.

	virtual void _ready() override;
	virtual void _exit_tree() override;
};

} // namespace godot

VARIANT_ENUM_CAST(godot::Log::Level);
VARIANT_ENUM_CAST(godot::Log::LogType);
