#include "log.h"

#include "error_dump.h"
#include "log_entry.h"
#include "sdg_print.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

// Order must match the Level enum values — level_to_string(level) is the
// replacement for GDScript's Log.Level.keys()[level].
static const char *LEVEL_NAMES[] = {
	"SILENT", "ERROR", "WARNING", "INFO", "DEBUG", "VERBOSE", "FRAME_ONLY"
};
static const int LEVEL_NAME_COUNT = sizeof(LEVEL_NAMES) / sizeof(LEVEL_NAMES[0]);

void Log::_bind_methods() {
	ClassDB::bind_static_method("Log", D_METHOD("level_to_string", "level"), &Log::level_to_string);
	ClassDB::bind_static_method("Log", D_METHOD("level_from_string", "name"), &Log::level_from_string);

	// Bind the prefixed C++ enumerators back to their original GDScript names.
	ClassDB::bind_integer_constant(get_class_static(), "Level", "SILENT", LEVEL_SILENT);
	ClassDB::bind_integer_constant(get_class_static(), "Level", "ERROR", LEVEL_ERROR);
	ClassDB::bind_integer_constant(get_class_static(), "Level", "WARNING", LEVEL_WARNING);
	ClassDB::bind_integer_constant(get_class_static(), "Level", "INFO", LEVEL_INFO);
	ClassDB::bind_integer_constant(get_class_static(), "Level", "DEBUG", LEVEL_DEBUG);
	ClassDB::bind_integer_constant(get_class_static(), "Level", "VERBOSE", LEVEL_VERBOSE);
	ClassDB::bind_integer_constant(get_class_static(), "Level", "FRAME_ONLY", LEVEL_FRAME_ONLY);

	ClassDB::bind_integer_constant(get_class_static(), "LogType", "SINGLETON", LOG_TYPE_SINGLETON);
	ClassDB::bind_integer_constant(get_class_static(), "LogType", "OBJECT", LOG_TYPE_OBJECT);
	ClassDB::bind_integer_constant(get_class_static(), "LogType", "UNKNOWN", LOG_TYPE_UNKNOWN);

	ClassDB::bind_method(D_METHOD("set_id", "id"), &Log::set_id);
	ClassDB::bind_method(D_METHOD("get_id"), &Log::get_id);
	ClassDB::bind_method(D_METHOD("set_print_level", "level"), &Log::set_print_level);
	ClassDB::bind_method(D_METHOD("get_print_level"), &Log::get_print_level);
	ClassDB::bind_method(D_METHOD("set_archive_level", "level"), &Log::set_archive_level);
	ClassDB::bind_method(D_METHOD("get_archive_level"), &Log::get_archive_level);
	ClassDB::bind_method(D_METHOD("set_settings", "settings"), &Log::set_settings);
	ClassDB::bind_method(D_METHOD("get_settings"), &Log::get_settings);

	ADD_PROPERTY(PropertyInfo(Variant::STRING, "id"), "set_id", "get_id");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "print_level", PROPERTY_HINT_ENUM, "SILENT,ERROR,WARNING,INFO,DEBUG,VERBOSE,FRAME_ONLY"), "set_print_level", "get_print_level");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "archive_level", PROPERTY_HINT_ENUM, "SILENT,ERROR,WARNING,INFO,DEBUG,VERBOSE,FRAME_ONLY"), "set_archive_level", "get_archive_level");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "settings", PROPERTY_HINT_RESOURCE_TYPE, "PrintSettings"), "set_settings", "get_settings");

	ClassDB::bind_method(D_METHOD("_second_init", "id", "print_level", "archive_level", "log_type", "custom_settings"), &Log::_second_init,
			DEFVAL(String()), DEFVAL((int)LEVEL_VERBOSE), DEFVAL((int)LEVEL_VERBOSE), DEFVAL(LOG_TYPE_OBJECT), DEFVAL(Ref<PrintSettings>()));
	ClassDB::bind_method(D_METHOD("start"), &Log::start);
	ClassDB::bind_method(D_METHOD("assert_that", "is_true", "message"), &Log::assert_that, DEFVAL(String()));
	ClassDB::bind_method(D_METHOD("error", "message", "dump_error"), &Log::error, DEFVAL(true));
	ClassDB::bind_method(D_METHOD("warning", "message", "dump_warning"), &Log::warning, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("info", "message"), &Log::info);
	ClassDB::bind_method(D_METHOD("debug", "message"), &Log::debug);
	ClassDB::bind_method(D_METHOD("verbose", "message"), &Log::verbose);
	ClassDB::bind_method(D_METHOD("print_at_level", "message", "level"), &Log::print_at_level, DEFVAL((int)LEVEL_DEBUG));
	ClassDB::bind_method(D_METHOD("start_frame", "title"), &Log::start_frame, DEFVAL(String()));
	ClassDB::bind_method(D_METHOD("append_frame_title", "title"), &Log::append_frame_title);
	ClassDB::bind_method(D_METHOD("in_frame", "line"), &Log::in_frame);
	ClassDB::bind_method(D_METHOD("end_frame"), &Log::end_frame);
	ClassDB::bind_method(D_METHOD("get_frame_title"), &Log::get_frame_title);
	ClassDB::bind_method(D_METHOD("get_frame", "prepend_title"), &Log::get_frame, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("to_dict"), &Log::to_dict);
}

// Register with the Print singleton when ready. If this logger is a child of
// an existing node, derive the ID from the parent's path.
void Log::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return; // The GDScript version was not @tool; never run in the editor.
	}
	if (!_initialized) {
		_second_init();
	}
	if (id.is_empty()) {
		id = String(get_parent()->get_path()).replace("/root/", "");
	}
	if (SDG_Print::get_singleton()) {
		SDG_Print::get_singleton()->_register_logger(this);
	}
	start();
}

void Log::_exit_tree() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	if (SDG_Print::get_singleton()) {
		SDG_Print::get_singleton()->_unregister_logger(this);
	}
}

Log *Log::_second_init(const String &p_id, int p_print_level, int p_archive_level, LogType p_log_type, const Ref<PrintSettings> &p_custom_settings) {
	id = p_id;
	if (p_log_type == LOG_TYPE_SINGLETON) {
		set_name(p_id);
	}
	print_level = p_print_level;
	archive_level = p_archive_level;
	_log_type = p_log_type;
	if (p_custom_settings.is_valid()) {
		settings = p_custom_settings;
	} else if (SDG_Print::get_singleton()) {
		settings = SDG_Print::get_singleton()->get_settings();
	} else {
		// GDScript read Print.settings unconditionally (and crashed without the
		// autoload); fall back to defaults so a bare Log node is still usable.
		settings.instantiate();
	}
	_initialized = true;

	// Initialize our history buffers.
	_log_history = RingBuffer::create(settings->get_max_log_entries());
	_frame_history = RingBuffer::create(settings->get_max_frames());
	return this;
}

void Log::set_console(Object *p_console) {
	_console = p_console ? p_console->get_instance_id() : ObjectID();
}

void Log::start() {
	if (_log_history.is_valid()) {
		_log_history->clear();
	}
	if (_frame_history.is_valid()) {
		_frame_history->clear();
	}
	_current_frame.unref();
	_has_frame_changes = false;
}

void Log::assert_that(const Variant &p_is_true, const String &p_message) {
	if (!p_is_true.booleanize()) {
		error(p_message, true);
		// GDScript followed with assert(false) to halt debug builds; the C++
		// equivalent (pausing in the debugger) arrives with Stage 4's pause
		// mechanism, which error() will trigger through the dump path.
	}
}

void Log::error(const String &p_message, bool p_dump_error) {
	SDG_Print *print = SDG_Print::get_singleton();
	if (print) {
		print->set_error_count(print->get_error_count() + 1);
	}
	Ref<LogEntry> entry = _log(LEVEL_ERROR, p_message);

	if (print_level >= LEVEL_ERROR) {
		String formatted = entry->format(settings);
		_print_console(formatted);
		UtilityFunctions::print_rich(formatted);
	}
	if (p_dump_error && print) {
		print->flush_logs(p_message, ErrorDump::DUMP_REASON_ERROR);
	}
	UtilityFunctions::push_error(p_message);
}

void Log::warning(const String &p_message, bool p_dump_warning) {
	SDG_Print *print = SDG_Print::get_singleton();
	if (print) {
		print->set_warning_count(print->get_warning_count() + 1);
	}
	Ref<LogEntry> entry = _log(LEVEL_WARNING, p_message);

	if (print_level >= LEVEL_WARNING) {
		String formatted = entry->format(settings);
		_print_console(formatted);
		UtilityFunctions::print_rich(formatted);
	}
	if (p_dump_warning && print) {
		print->flush_logs(p_message, ErrorDump::DUMP_REASON_WARNING);
	}
	UtilityFunctions::push_warning(p_message);
}

void Log::info(const String &p_message) {
	Ref<LogEntry> entry = _log(LEVEL_INFO, p_message);

	if (print_level >= LEVEL_INFO) {
		String formatted = entry->format(settings);
		_print_console(formatted);
		UtilityFunctions::print_rich(formatted);
	}
}

void Log::debug(const String &p_message) {
	Ref<LogEntry> entry = _log(LEVEL_DEBUG, p_message);

	if (print_level >= LEVEL_DEBUG) {
		String formatted = entry->format(settings);
		_print_console(formatted);
		UtilityFunctions::print_rich(formatted);
	}
}

void Log::verbose(const String &p_message) {
	Ref<LogEntry> entry = _log(LEVEL_VERBOSE, p_message);

	if (print_level >= LEVEL_VERBOSE) {
		String formatted = entry->format(settings);
		_print_console(formatted);
		UtilityFunctions::print_rich(formatted);
	}
}

void Log::start_frame(const String &p_title) {
	if (p_title.is_empty()) {
		_current_frame = FrameLog::create(id);
	} else {
		_current_frame = FrameLog::create(p_title);
	}
	_frame_history->push(LogEntry::wrap_frame(_current_frame, id));
	_has_frame_changes = !p_title.is_empty();
}

void Log::append_frame_title(const String &p_title) {
	if (_current_frame.is_null()) {
		_current_frame = FrameLog::create(id);
	}
	_current_frame->set_title(_current_frame->get_title() + p_title);
	_has_frame_changes = true;
}

void Log::in_frame(const String &p_line) {
	if (_current_frame.is_null()) {
		_current_frame = FrameLog::create(id);
	}
	_current_frame->set_details(_current_frame->get_details() + p_line + String("\n"));
	_has_frame_changes = true;
}

void Log::end_frame() {
	if (_current_frame.is_valid()) {
		_current_frame->set_is_complete(true);
		_has_frame_changes = false;
	}
}

String Log::get_frame_title() const {
	if (_current_frame.is_null()) {
		return String();
	}
	return _current_frame->get_title();
}

String Log::get_frame(bool p_prepend_title) const {
	if (_current_frame.is_null()) {
		return String();
	}
	return _current_frame->format(p_prepend_title);
}

void Log::print_at_level(const String &p_message, const Variant &p_level) {
	switch ((int)p_level) {
		case LEVEL_ERROR:
			error(p_message);
			break;
		case LEVEL_WARNING:
			warning(p_message);
			break;
		case LEVEL_INFO:
			info(p_message);
			break;
		case LEVEL_DEBUG:
			debug(p_message);
			break;
		case LEVEL_VERBOSE:
			verbose(p_message);
			break;
		case LEVEL_SILENT:
			error("Attempted to print at ''SILENT'' logging level.");
			break;
		default:
			error("Attempted to print at an invalid logging level.");
			break;
	}
}

Dictionary Log::to_dict() const {
	Dictionary dict;
	dict["id"] = id;
	dict["log_history"] = _log_history.is_valid() ? _log_history->to_dict() : Dictionary();
	dict["frame_history"] = _frame_history.is_valid() ? _frame_history->to_dict() : Dictionary();
	return dict;
}

Ref<LogEntry> Log::_log(int p_level, const String &p_message) {
	Ref<LogEntry> entry = LogEntry::create(p_level, StringName(id), p_message, _current_frame);
	if (archive_level >= p_level) {
		_log_history->push(entry);
	}
	return entry;
}

void Log::_print_console(const String &p_message) {
	if (_console.is_valid()) {
		Object *console = ObjectDB::get_instance(_console);
		if (console) {
			console->call("print_line", p_message);
		}
	}
}

String Log::level_to_string(int p_level) {
	if (p_level < 0 || p_level >= LEVEL_NAME_COUNT) {
		return String();
	}
	return String(LEVEL_NAMES[p_level]);
}

int Log::level_from_string(const String &p_name) {
	for (int i = 0; i < LEVEL_NAME_COUNT; i++) {
		if (p_name == LEVEL_NAMES[i]) {
			return i;
		}
	}
	return -1;
}
