#include "sdg_print.h"

#include "error_dump.h"
#include "logger_registry.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

SDG_Print *SDG_Print::singleton = nullptr;

// Mirrors GDScript's Log.LogType.find_key(type) for log messages.
static String log_type_key(Log::LogType p_type) {
	switch (p_type) {
		case Log::LOG_TYPE_SINGLETON:
			return "SINGLETON";
		case Log::LOG_TYPE_OBJECT:
			return "OBJECT";
		default:
			return "UNKNOWN";
	}
}

void SDG_Print::_bind_methods() {
	// The anonymous-enum constants: Print.SILENT ... Print.FRAME_ONLY.
	ClassDB::bind_integer_constant(get_class_static(), "", "SILENT", SILENT);
	ClassDB::bind_integer_constant(get_class_static(), "", "ERROR", PRINT_ERROR);
	ClassDB::bind_integer_constant(get_class_static(), "", "WARNING", PRINT_WARNING);
	ClassDB::bind_integer_constant(get_class_static(), "", "INFO", INFO);
	ClassDB::bind_integer_constant(get_class_static(), "", "DEBUG", PRINT_DEBUG);
	ClassDB::bind_integer_constant(get_class_static(), "", "VERBOSE", VERBOSE);
	ClassDB::bind_integer_constant(get_class_static(), "", "FRAME_ONLY", FRAME_ONLY);

	ClassDB::bind_method(D_METHOD("set_settings", "settings"), &SDG_Print::set_settings);
	ClassDB::bind_method(D_METHOD("get_settings"), &SDG_Print::get_settings);
	ClassDB::bind_method(D_METHOD("set_warning_count", "count"), &SDG_Print::set_warning_count);
	ClassDB::bind_method(D_METHOD("get_warning_count"), &SDG_Print::get_warning_count);
	ClassDB::bind_method(D_METHOD("set_error_count", "count"), &SDG_Print::set_error_count);
	ClassDB::bind_method(D_METHOD("get_error_count"), &SDG_Print::get_error_count);
	ClassDB::bind_method(D_METHOD("set_current_dump_file", "path"), &SDG_Print::set_current_dump_file);
	ClassDB::bind_method(D_METHOD("get_current_dump_file"), &SDG_Print::get_current_dump_file);
	ClassDB::bind_method(D_METHOD("get_current_module_width"), &SDG_Print::get_current_module_width);

	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "settings", PROPERTY_HINT_RESOURCE_TYPE, "PrintSettings"), "set_settings", "get_settings");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "warning_count"), "set_warning_count", "get_warning_count");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "error_count"), "set_error_count", "get_error_count");
	// Script-accessible like the GDScript plain vars, but hidden from the inspector.
	ADD_PROPERTY(PropertyInfo(Variant::STRING, "current_dump_file", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NONE), "set_current_dump_file", "get_current_dump_file");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "_current_module_width", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NONE), "", "get_current_module_width");

	ClassDB::bind_method(D_METHOD("create_logger", "identifier", "print_level", "archive_level", "custom_settings"), &SDG_Print::create_logger, DEFVAL(Ref<PrintSettings>()));
	ClassDB::bind_method(D_METHOD("get_logger", "identifier", "get_or_create"), &SDG_Print::get_logger, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("from", "identifier", "message", "level"), &SDG_Print::from, DEFVAL((int)Log::LEVEL_DEBUG));
	ClassDB::bind_method(D_METHOD("get_frame_from", "identifier", "prepend_title"), &SDG_Print::get_frame_from, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("get_frame_title_from", "identifier"), &SDG_Print::get_frame_title_from);
	ClassDB::bind_method(D_METHOD("flush_logs", "context", "reason"), &SDG_Print::flush_logs, DEFVAL(String()), DEFVAL((int)ErrorDump::DUMP_REASON_FLUSH));
	ClassDB::bind_method(D_METHOD("error", "message", "dump_error"), &SDG_Print::error, DEFVAL(true));
	ClassDB::bind_method(D_METHOD("warning", "message"), &SDG_Print::warning);
	ClassDB::bind_method(D_METHOD("info", "message"), &SDG_Print::info);
	ClassDB::bind_method(D_METHOD("debug", "message"), &SDG_Print::debug);
	ClassDB::bind_method(D_METHOD("verbose", "message"), &SDG_Print::verbose);
	ClassDB::bind_method(D_METHOD("silence_all"), &SDG_Print::silence_all);
	ClassDB::bind_method(D_METHOD("silence_non_error_printing"), &SDG_Print::silence_non_error_printing);
	ClassDB::bind_method(D_METHOD("start_all"), &SDG_Print::start_all);
	ClassDB::bind_method(D_METHOD("list_loggers"), &SDG_Print::list_loggers);
	ClassDB::bind_method(D_METHOD("_dump_loggers"), &SDG_Print::_dump_loggers);
	ClassDB::bind_method(D_METHOD("_delete_dumps"), &SDG_Print::_delete_dumps);
	ClassDB::bind_method(D_METHOD("_test_error"), &SDG_Print::_test_error);
	ClassDB::bind_method(D_METHOD("_register_logger", "logger"), &SDG_Print::_register_logger);
	ClassDB::bind_method(D_METHOD("_unregister_logger", "logger"), &SDG_Print::_unregister_logger);
	ClassDB::bind_method(D_METHOD("_get_id", "identifier"), &SDG_Print::_get_id);
	ClassDB::bind_method(D_METHOD("_get_type", "identifier"), &SDG_Print::_get_type);
}

// Do all of our work as early as possible (ENTER_TREE, since GDExtension has
// no _init-with-scene-context) so other autoloads can print from their _ready.
void SDG_Print::_enter_tree() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return; // The GDScript version was not @tool; never boot in the editor.
	}
	singleton = this;

	// Register project settings.
	PrintSettings::_register_settings();

	// Initialize global settings.
	settings = PrintSettings::from_project_settings();

	// Clean up extra files from previous sessions.
	ErrorDump::cleanup_old_dumps(settings->get_max_log_files());

	Ref<LoggerRegistry> registry = LoggerRegistry::load_from_project_settings();

	// Initialize Print logger from registry.
	Ref<LoggerConfig> print_config = registry->get_print_logger();
	_print_logger = memnew(Log);
	_print_logger->_second_init("Print", print_config->get_print_level(), print_config->get_archive_level(), Log::LOG_TYPE_SINGLETON, settings);
	add_child(_print_logger);
	_print_logger->set_process_priority(get_process_priority() + 1);

	// Initialize Global logger from registry.
	Ref<LoggerConfig> global_config = registry->get_global_logger();
	_global_logger = create_logger("Global", global_config->get_print_level(), global_config->get_archive_level());

	// Create all additional loggers from registry.
	TypedArray<LoggerConfig> registry_loggers = registry->get_loggers();
	for (int64_t i = 0; i < registry_loggers.size(); i++) {
		Ref<LoggerConfig> config = registry_loggers[i];
		if (config.is_null()) {
			continue;
		}
		_print_logger->verbose(String("Creating logger from registry: ") + config->get_logger_name());
		create_logger(config->get_logger_name(), config->get_print_level(), config->get_archive_level());
	}
}

// Connect to the Console (if it is present).
void SDG_Print::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	if (has_node(NodePath("/root/Console"))) {
		Node *console = get_node<Node>(NodePath("/root/Console"));
		_global_logger->set_console(console);
		console->call("add_command", "Print.silence_all", Callable(this, "silence_all"), 0, 0,
				"Disables all printing to this console and the Output window or external console");
		console->call("add_command", "Print.silence_non_error_logs", Callable(this, "silence_non_error_printing"), 0, 0,
				"Disables all non-error printing.");
		console->call("add_command", "Print.dump_all_loggers", Callable(this, "_dump_loggers"), 0, 0,
				"Dumps all of the prints stored in all of the loggers. Dumps to file, but also copies to the clipboard.");
		console->call("add_command", "Print.list_loggers", Callable(this, "list_loggers"), 0, 0,
				"Prints the names of all of the loggers to the console.");
		console->call("add_command", "Print.clear_all_dumps", Callable(this, "_delete_dumps"), 0, 0,
				"Deletes all of the dump files in user://dumps.");
		console->call("add_command", "Print.push_test_error", Callable(this, "_test_error"), 0, 0,
				"Pushes an error to the console and dump file. Logs at each level first, ending with the error.");
	}
}

void SDG_Print::_exit_tree() {
	if (singleton == this) {
		singleton = nullptr;
	}
}

// Dump loggers when we detect that the application is exiting.
// Don't dump on application close in release builds.
void SDG_Print::_notification(int p_what) {
	if (p_what == NOTIFICATION_WM_CLOSE_REQUEST) {
		if (Engine::get_singleton()->is_editor_hint() || singleton != this) {
			return;
		}
		if (OS::get_singleton()->has_feature("editor") || OS::get_singleton()->is_debug_build()) {
			// Create the final dump.
			_print_logger->info("Application closing, final dump created");
			flush_logs("", ErrorDump::DUMP_REASON_APP_CLOSE);
		}
	}
}

Log *SDG_Print::create_logger(const Variant &p_identifier, int p_print_level, int p_archive_level, const Ref<PrintSettings> &p_custom_settings) {
	String log_id = _get_id(p_identifier);
	if (_logs.has(log_id)) {
		_print_logger->info(String("Print.create_logger found existing logger \"") + log_id +
				String("\". If you are trying to instance a new logger, then this is an error."));
		Log *logger = Object::cast_to<Log>(_logs[log_id]);
		logger->set_print_level(p_print_level);
		logger->set_archive_level(p_archive_level);
		if (p_custom_settings.is_valid()) {
			logger->set_settings(p_custom_settings);
		}
		return logger;
	} else {
		_print_logger->debug(String("Print.create_logger creating new logger ") + log_id + String("."));
		// Update the module width if this logger has a longer name.
		_current_module_width = MAX(_current_module_width, (int64_t)log_id.length());

		Ref<PrintSettings> logger_settings = p_custom_settings.is_valid() ? p_custom_settings : settings;
		Log *logger = memnew(Log);
		logger->_second_init(log_id, p_print_level, p_archive_level, _get_type(p_identifier), logger_settings);
		add_child(logger);
		_logs[log_id] = logger;
		return logger;
	}
}

Log *SDG_Print::get_logger(const Variant &p_identifier, bool p_get_or_create) {
	String log_id = _get_id(p_identifier);
	if (_logs.has(log_id)) {
		_print_logger->verbose(String("get_logger found existing logger ") + log_id + String("."));
		return Object::cast_to<Log>(_logs[log_id]);
	} else if (p_get_or_create) {
		return create_logger(p_identifier, VERBOSE, VERBOSE);
	} else {
		_print_logger->error(String("No logger exists with name ") + log_id + String("."));
		return nullptr;
	}
}

void SDG_Print::from(const Variant &p_identifier, const String &p_message, const Variant &p_level) {
	String logger_id = _get_id(p_identifier);
	if (_logs.has(logger_id)) {
		Object::cast_to<Log>(_logs[logger_id])->print_at_level(p_message, p_level);
	} else {
		_print_logger->error(String("No log with this identifier: ") + logger_id);
	}
}

String SDG_Print::get_frame_from(const Variant &p_identifier, bool p_prepend_title) {
	String logger_id = _get_id(p_identifier);
	if (_logs.has(logger_id)) {
		return Object::cast_to<Log>(_logs[logger_id])->get_frame(p_prepend_title);
	} else {
		_print_logger->error(String("No log with this identifier: ") + logger_id);
		return String();
	}
}

String SDG_Print::get_frame_title_from(const Variant &p_identifier) {
	String logger_id = _get_id(p_identifier);
	if (_logs.has(logger_id)) {
		return Object::cast_to<Log>(_logs[logger_id])->get_frame_title();
	} else {
		_print_logger->error(String("No log with this identifier: ") + logger_id);
		return String();
	}
}

void SDG_Print::flush_logs(const String &p_context, int p_reason) {
	// Logging an info will also allow us to fold lower quality logs at the
	// start of the dump.
	_print_logger->info("Dumping all loggers to file.");

	Dictionary logger_data;
	Array keys = _logs.keys();
	for (int64_t i = 0; i < keys.size(); i++) {
		logger_data[keys[i]] = Object::cast_to<Log>(_logs[keys[i]])->to_dict();
	}

	if (ErrorDump::save_dump(logger_data, p_reason, p_context) != OK) {
		// Do not trigger an error dump when throwing an error here.
		_print_logger->error("Failed to save dump to file!", false);
	}
	start_all();
}

void SDG_Print::error(const String &p_message, bool p_dump_error) {
	_global_logger->error(p_message, p_dump_error);
}

void SDG_Print::warning(const String &p_message) {
	_global_logger->warning(p_message);
}

void SDG_Print::info(const String &p_message) {
	_global_logger->info(p_message);
}

void SDG_Print::debug(const String &p_message) {
	_global_logger->debug(p_message);
}

void SDG_Print::verbose(const String &p_message) {
	_global_logger->verbose(p_message);
}

void SDG_Print::silence_all() {
	Array keys = _logs.keys();
	for (int64_t i = 0; i < keys.size(); i++) {
		Log *logger = Object::cast_to<Log>(_logs[keys[i]]);
		logger->set_print_level(Log::LEVEL_SILENT);
		logger->set_archive_level(Log::LEVEL_SILENT);
	}
}

void SDG_Print::silence_non_error_printing() {
	Array keys = _logs.keys();
	for (int64_t i = 0; i < keys.size(); i++) {
		Object::cast_to<Log>(_logs[keys[i]])->set_print_level(Log::LEVEL_ERROR);
	}
}

void SDG_Print::start_all() {
	Array keys = _logs.keys();
	for (int64_t i = 0; i < keys.size(); i++) {
		Object::cast_to<Log>(_logs[keys[i]])->start();
	}
	_print_logger->info("All loggers reset.");
}

Array SDG_Print::list_loggers() {
	info(UtilityFunctions::str(_logs.keys()));
	return _logs.keys();
}

void SDG_Print::_dump_loggers() {
	flush_logs("User initiated dump from console.", ErrorDump::DUMP_REASON_MANUAL);
}

void SDG_Print::_delete_dumps() {
	ErrorDump::cleanup_old_dumps(0);
}

void SDG_Print::_test_error() {
	// Mirrors the GDScript exactly, including never restoring these levels.
	Array levels;
	levels.append(_global_logger->get_print_level());
	levels.append(_global_logger->get_archive_level());
	_global_logger->set_print_level(Log::LEVEL_VERBOSE);

	Log *l = get_logger("Player");
	(void)l;
	_global_logger->start_frame("Testing frame data output.");
	_global_logger->in_frame("About to print at each level.");
	_global_logger->end_frame();
	_global_logger->verbose("Test print - verbose");
	_global_logger->debug("Test print - debug");
	_global_logger->info("Test print - info");
	_global_logger->warning("Test print - warning");
	_global_logger->error("Test error");
}

void SDG_Print::_register_logger(Log *p_logger) {
	ERR_FAIL_NULL(p_logger);
	String log_id = p_logger->get_id();
	if (_logs.has(log_id)) {
		if (Object::cast_to<Log>(_logs[log_id]) != p_logger) {
			_print_logger->error(String("A logger with the identifier '") + log_id + String("' is already registered."));
		}
		// Else, we already added this logger in the create_logger call.
		return;
	}
	_logs[log_id] = p_logger;
	_print_logger->debug(String("Registered ") + log_id + String(" logger of type ") +
			log_type_key(p_logger->get_log_type()).to_camel_case() + String("."));
	if (has_node(NodePath("/root/Console"))) {
		p_logger->set_console(get_node<Node>(NodePath("/root/Console")));
	}
}

void SDG_Print::_unregister_logger(Log *p_logger) {
	ERR_FAIL_NULL(p_logger);
	String log_id = p_logger->get_id();
	if (_logs.has(log_id)) {
		_logs.erase(log_id);
		_print_logger->debug(String("Un-Registered ") + log_id + String(" logger of type ") +
				log_type_key(p_logger->get_log_type()).to_camel_case() + String("."));

		// Recalculate the maximum module width.
		_current_module_width = 0;
		Array keys = _logs.keys();
		for (int64_t i = 0; i < keys.size(); i++) {
			_current_module_width = MAX(_current_module_width, (int64_t)String(keys[i]).length());
		}
	} else {
		_print_logger->error(String("A logger with the identifier '") + log_id + String("' is not registered."));
	}
}

String SDG_Print::_get_id(const Variant &p_identifier) {
	switch (_get_type(p_identifier)) {
		case Log::LOG_TYPE_SINGLETON:
			return p_identifier;
		case Log::LOG_TYPE_OBJECT: {
			Object *obj = p_identifier;
			return String(obj->call("get_path"));
		}
		default:
			return UtilityFunctions::str(p_identifier);
	}
}

Log::LogType SDG_Print::_get_type(const Variant &p_identifier) {
	if (p_identifier.get_type() == Variant::STRING) {
		return Log::LOG_TYPE_SINGLETON;
	} else if (p_identifier.get_validated_object() != nullptr) { // is_instance_valid(identifier)
		return Log::LOG_TYPE_OBJECT;
	}
	return Log::LOG_TYPE_UNKNOWN;
}
