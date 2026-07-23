#include "print_settings.h"

#include "log.h"
#include "logger_registry.h"

#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

const char *PrintSettings::SETTINGS_PATH = "debug/logging/";

// Bind a property and its accessors in one go (plain, and hinted variants).
#define BIND_SETTING(m_type, m_name)                                                                   \
	ClassDB::bind_method(D_METHOD("set_" #m_name, "value"), &PrintSettings::set_##m_name);             \
	ClassDB::bind_method(D_METHOD("get_" #m_name), &PrintSettings::get_##m_name);                      \
	ADD_PROPERTY(PropertyInfo(m_type, #m_name), "set_" #m_name, "get_" #m_name);

#define BIND_SETTING_HINT(m_type, m_name, m_hint, m_hint_string)                                       \
	ClassDB::bind_method(D_METHOD("set_" #m_name, "value"), &PrintSettings::set_##m_name);             \
	ClassDB::bind_method(D_METHOD("get_" #m_name), &PrintSettings::get_##m_name);                      \
	ADD_PROPERTY(PropertyInfo(m_type, #m_name, m_hint, m_hint_string), "set_" #m_name, "get_" #m_name);

void PrintSettings::_bind_methods() {
	// Groups and hints mirror the @export_group / @export_range layout of the
	// GDScript version, so the inspector looks identical.
	ADD_GROUP("Maximum Log History Sizes", "");
	BIND_SETTING_HINT(Variant::INT, max_log_entries, PROPERTY_HINT_RANGE, "1,10000,10");
	BIND_SETTING_HINT(Variant::INT, max_frames, PROPERTY_HINT_RANGE, "1,1000,1");
	BIND_SETTING_HINT(Variant::INT, max_log_files, PROPERTY_HINT_RANGE, "-1,100,1");

	ADD_GROUP("Log Formatting Options", "");
	BIND_SETTING(Variant::BOOL, show_timestamps);
	BIND_SETTING(Variant::BOOL, show_module_names);
	BIND_SETTING(Variant::BOOL, show_log_levels);
	BIND_SETTING_HINT(Variant::INT, max_module_width, PROPERTY_HINT_RANGE, "1,100,1,or_greater");

	ADD_GROUP("Log Level Colors", "");
	BIND_SETTING(Variant::COLOR, error_color);
	BIND_SETTING(Variant::COLOR, warning_color);
	BIND_SETTING(Variant::COLOR, info_color);
	BIND_SETTING(Variant::COLOR, debug_color);
	BIND_SETTING(Variant::COLOR, verbose_color);

	ADD_GROUP("Component Colors", "");
	BIND_SETTING(Variant::COLOR, timestamp_color);
	BIND_SETTING(Variant::COLOR, frame_number_color);
	BIND_SETTING(Variant::COLOR, frame_data_color);
	BIND_SETTING(Variant::COLOR, module_name_color);

	ADD_GROUP("Dump Viewer Colors", "");
	BIND_SETTING(Variant::COLOR, default_message_color);
	BIND_SETTING(Variant::COLOR, dump_header_color);

	ClassDB::bind_method(D_METHOD("get_level_color", "level"), &PrintSettings::get_level_color);

	ClassDB::bind_static_method("PrintSettings", D_METHOD("_register_settings"), &PrintSettings::_register_settings);
	ClassDB::bind_static_method("PrintSettings", D_METHOD("from_project_settings"), &PrintSettings::from_project_settings);
	ClassDB::bind_method(D_METHOD("load_from_project_settings"), &PrintSettings::load_from_project_settings);
	ClassDB::bind_method(D_METHOD("duplicate_with_overrides", "overrides"), &PrintSettings::duplicate_with_overrides, DEFVAL(Dictionary()));
}

Color PrintSettings::get_level_color(int p_level) const {
	switch (p_level) {
		case Log::LEVEL_ERROR:
			return error_color;
		case Log::LEVEL_WARNING:
			return warning_color;
		case Log::LEVEL_INFO:
			return info_color;
		case Log::LEVEL_DEBUG:
			return debug_color;
		case Log::LEVEL_VERBOSE:
			return verbose_color;
		default:
			return Color(1, 1, 1); // Default fallback (Color.WHITE).
	}
}

// Registers one setting the same way the GDScript version did: set the value
// and its initial (default) value only when absent, then attach property info
// so the Project Settings dialog shows the right editor.
static void register_setting(const String &p_name, Variant::Type p_type, const Variant &p_value, PropertyHint p_hint = PROPERTY_HINT_NONE, const String &p_hint_string = String()) {
	ProjectSettings *ps = ProjectSettings::get_singleton();
	String full_path = String(PrintSettings::SETTINGS_PATH) + p_name;

	if (ps->has_setting(full_path)) {
		return;
	}
	ps->set_setting(full_path, p_value);
	ps->set_initial_value(full_path, p_value);

	Dictionary info;
	info["name"] = full_path;
	info["type"] = p_type;
	if (p_hint != PROPERTY_HINT_NONE) {
		info["hint"] = p_hint;
		info["hint_string"] = p_hint_string;
	}
	ps->add_property_info(info);
}

void PrintSettings::_register_settings() {
	LoggerRegistry::register_project_settings();

	register_setting("history/max_log_entries", Variant::INT, 1000, PROPERTY_HINT_RANGE, "1,100000");
	register_setting("history/max_frames", Variant::INT, 100, PROPERTY_HINT_RANGE, "1,1000");
	register_setting("history/max_log_files", Variant::INT, 15, PROPERTY_HINT_RANGE, "-1,100");

	register_setting("format/show_timestamps", Variant::BOOL, true);
	register_setting("format/show_module_names", Variant::BOOL, true);
	register_setting("format/show_log_levels", Variant::BOOL, true);
	register_setting("format/module_name_max_padding_width", Variant::INT, 20, PROPERTY_HINT_RANGE, "1,100,1");

	register_setting("colors/error", Variant::COLOR, Color::hex(0xCD5C5CFF));
	register_setting("colors/warning", Variant::COLOR, Color::hex(0xFFA500FF));
	register_setting("colors/info", Variant::COLOR, Color::hex(0x00FFFFFF));
	register_setting("colors/debug", Variant::COLOR, Color::hex(0x32CD32FF));
	register_setting("colors/verbose", Variant::COLOR, Color::hex(0x9370DBFF));
	register_setting("colors/timestamp", Variant::COLOR, Color::hex(0x6495EDFF));
	register_setting("colors/module_name", Variant::COLOR, Color::hex(0xFF00FFFF));
	register_setting("colors/frame_number", Variant::COLOR, Color::hex(0xB0C4DEFF));
	register_setting("colors/frame_data", Variant::COLOR, Color::hex(0x32CD32FF));
	register_setting("colors/default_message", Variant::COLOR, Color::hex(0xF5F5F5FF));
	register_setting("colors/dump_header", Variant::COLOR, Color::hex(0xFFD700FF));
}

Ref<PrintSettings> PrintSettings::from_project_settings() {
	Ref<PrintSettings> settings;
	settings.instantiate();
	settings->load_from_project_settings();
	return settings;
}

void PrintSettings::load_from_project_settings() {
	ProjectSettings *ps = ProjectSettings::get_singleton();
	String path = SETTINGS_PATH;

	max_log_entries = ps->get_setting(path + String("history/max_log_entries"));
	max_frames = ps->get_setting(path + String("history/max_frames"));
	max_log_files = ps->get_setting(path + String("history/max_log_files"));

	show_timestamps = ps->get_setting(path + String("format/show_timestamps"));
	show_module_names = ps->get_setting(path + String("format/show_module_names"));
	show_log_levels = ps->get_setting(path + String("format/show_log_levels"));
	max_module_width = ps->get_setting(path + String("format/module_name_max_padding_width"));

	error_color = ps->get_setting(path + String("colors/error"));
	warning_color = ps->get_setting(path + String("colors/warning"));
	info_color = ps->get_setting(path + String("colors/info"));
	debug_color = ps->get_setting(path + String("colors/debug"));
	verbose_color = ps->get_setting(path + String("colors/verbose"));
	timestamp_color = ps->get_setting(path + String("colors/timestamp"));
	module_name_color = ps->get_setting(path + String("colors/module_name"));
	frame_number_color = ps->get_setting(path + String("colors/frame_number"));
	frame_data_color = ps->get_setting(path + String("colors/frame_data"));
	default_message_color = ps->get_setting(path + String("colors/default_message"));
	dump_header_color = ps->get_setting(path + String("colors/dump_header"));
}

Ref<PrintSettings> PrintSettings::duplicate_with_overrides(const Dictionary &p_overrides) {
	Ref<PrintSettings> new_settings = duplicate();
	Array keys = p_overrides.keys();
	for (int64_t i = 0; i < keys.size(); i++) {
		const Variant &key = keys[i];
		if (new_settings->get(key) != Variant()) { // Only set if property exists.
			new_settings->set(key, p_overrides[key]);
		}
	}
	return new_settings;
}
