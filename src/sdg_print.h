#pragma once

#include "log.h"
#include "print_settings.h"

#include <godot_cpp/classes/node.hpp>

namespace godot {

// The Print singleton. Creates and maintains Log instances, passes generic
// print calls through to the "Global" Log, and dumps all logger history to
// disk when an error occurs. Registered as the autoload "Print" via
// print/print.tscn (an autoload can't point at a C++ class directly).
//
// Startup happens on ENTER_TREE rather than in the constructor: Print must be
// FIRST in the autoload list so other autoloads can log from their _ready.
class SDG_Print : public Node {
	GDCLASS(SDG_Print, Node)

	static SDG_Print *singleton;

	Ref<PrintSettings> settings;
	int64_t warning_count = 0;
	int64_t error_count = 0;
	String current_dump_file;

	Dictionary _logs; // id (String) -> Log*
	Log *_global_logger = nullptr;
	Log *_print_logger = nullptr;
	int64_t _current_module_width = 0;

protected:
	static void _bind_methods();

public:
	// Mirrors GDScript's anonymous enum: Print.SILENT ... Print.FRAME_ONLY.
	enum {
		SILENT = 0,
		PRINT_ERROR = 1, // Bound as "ERROR" (Windows macro collision).
		PRINT_WARNING = 2, // Bound as "WARNING".
		INFO = 3,
		PRINT_DEBUG = 4, // Bound as "DEBUG".
		VERBOSE = 5,
		FRAME_ONLY = 6,
	};

	static SDG_Print *get_singleton() { return singleton; }

	void set_settings(const Ref<PrintSettings> &p_settings) { settings = p_settings; }
	Ref<PrintSettings> get_settings() const { return settings; }
	void set_warning_count(int64_t p_count) { warning_count = p_count; }
	int64_t get_warning_count() const { return warning_count; }
	void set_error_count(int64_t p_count) { error_count = p_count; }
	int64_t get_error_count() const { return error_count; }
	void set_current_dump_file(const String &p_path) { current_dump_file = p_path; }
	String get_current_dump_file() const { return current_dump_file; }
	int64_t get_current_module_width() const { return _current_module_width; }

	Log *create_logger(const Variant &p_identifier, int p_print_level, int p_archive_level, const Ref<PrintSettings> &p_custom_settings = Ref<PrintSettings>());
	Log *get_logger(const Variant &p_identifier, bool p_get_or_create = false);
	void from(const Variant &p_identifier, const String &p_message, const Variant &p_level = Variant((int)Log::LEVEL_DEBUG));
	String get_frame_from(const Variant &p_identifier, bool p_prepend_title = false);
	String get_frame_title_from(const Variant &p_identifier);

	// Dumps all logger data to disk, then resets all loggers.
	void flush_logs(const String &p_context = String(), int p_reason = 0 /* ErrorDump::DUMP_REASON_FLUSH */);

	// Pass-throughs to the Global logger.
	void error(const String &p_message, bool p_dump_error = true);
	void warning(const String &p_message);
	void info(const String &p_message);
	void debug(const String &p_message);
	void verbose(const String &p_message);

	void silence_all();
	void silence_non_error_printing();
	void start_all();
	Array list_loggers();

	// Console hooks.
	void _dump_loggers();
	void _delete_dumps();
	void _test_error();

	// Called by Log from _ready/_exit_tree; internal to the module but must
	// stay callable across the class boundary.
	void _register_logger(Log *p_logger);
	void _unregister_logger(Log *p_logger);

	String _get_id(const Variant &p_identifier);
	Log::LogType _get_type(const Variant &p_identifier);

	virtual void _enter_tree() override;
	virtual void _ready() override;
	virtual void _exit_tree() override;
	void _notification(int p_what);
};

} // namespace godot
