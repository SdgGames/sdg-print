#pragma once

#include <godot_cpp/classes/resource.hpp>

namespace godot {

// Formatting and color settings for loggers. Settings can be configured
// globally through ProjectSettings (under debug/logging/), created in the
// editor, or generated at runtime. Each logger can use the global settings
// from the Print singleton or carry its own PrintSettings instance.
class PrintSettings : public Resource {
	GDCLASS(PrintSettings, Resource)

public:
	// ProjectSettings prefix for all logging settings ("debug/logging/").
	static const char *SETTINGS_PATH;

private:

	int64_t max_log_entries = 1000;
	int64_t max_frames = 100;
	int64_t max_log_files = 15;

	bool show_timestamps = true;
	bool show_module_names = true;
	bool show_log_levels = true;
	int64_t max_module_width = 20;

	Color error_color = Color::hex(0xCD5C5CFF); // INDIAN_RED
	Color warning_color = Color::hex(0xFFA500FF); // ORANGE
	Color info_color = Color::hex(0x00FFFFFF); // CYAN
	Color debug_color = Color::hex(0x32CD32FF); // LIME_GREEN
	Color verbose_color = Color::hex(0x9370DBFF); // MEDIUM_PURPLE

	Color timestamp_color = Color::hex(0x6495EDFF); // CORNFLOWER_BLUE
	Color frame_number_color = Color::hex(0xB0C4DEFF); // LIGHT_STEEL_BLUE
	Color frame_data_color = Color::hex(0x32CD32FF); // LIME_GREEN
	Color module_name_color = Color::hex(0xFF00FFFF); // MAGENTA

	Color default_message_color = Color::hex(0xF5F5F5FF); // WHITE_SMOKE
	Color dump_header_color = Color::hex(0xFFD700FF); // GOLD

protected:
	static void _bind_methods();

public:
	void set_max_log_entries(int64_t p_value) { max_log_entries = p_value; }
	int64_t get_max_log_entries() const { return max_log_entries; }
	void set_max_frames(int64_t p_value) { max_frames = p_value; }
	int64_t get_max_frames() const { return max_frames; }
	void set_max_log_files(int64_t p_value) { max_log_files = p_value; }
	int64_t get_max_log_files() const { return max_log_files; }

	void set_show_timestamps(bool p_value) { show_timestamps = p_value; }
	bool get_show_timestamps() const { return show_timestamps; }
	void set_show_module_names(bool p_value) { show_module_names = p_value; }
	bool get_show_module_names() const { return show_module_names; }
	void set_show_log_levels(bool p_value) { show_log_levels = p_value; }
	bool get_show_log_levels() const { return show_log_levels; }
	void set_max_module_width(int64_t p_value) { max_module_width = p_value; }
	int64_t get_max_module_width() const { return max_module_width; }

	void set_error_color(const Color &p_value) { error_color = p_value; }
	Color get_error_color() const { return error_color; }
	void set_warning_color(const Color &p_value) { warning_color = p_value; }
	Color get_warning_color() const { return warning_color; }
	void set_info_color(const Color &p_value) { info_color = p_value; }
	Color get_info_color() const { return info_color; }
	void set_debug_color(const Color &p_value) { debug_color = p_value; }
	Color get_debug_color() const { return debug_color; }
	void set_verbose_color(const Color &p_value) { verbose_color = p_value; }
	Color get_verbose_color() const { return verbose_color; }

	void set_timestamp_color(const Color &p_value) { timestamp_color = p_value; }
	Color get_timestamp_color() const { return timestamp_color; }
	void set_frame_number_color(const Color &p_value) { frame_number_color = p_value; }
	Color get_frame_number_color() const { return frame_number_color; }
	void set_frame_data_color(const Color &p_value) { frame_data_color = p_value; }
	Color get_frame_data_color() const { return frame_data_color; }
	void set_module_name_color(const Color &p_value) { module_name_color = p_value; }
	Color get_module_name_color() const { return module_name_color; }

	void set_default_message_color(const Color &p_value) { default_message_color = p_value; }
	Color get_default_message_color() const { return default_message_color; }
	void set_dump_header_color(const Color &p_value) { dump_header_color = p_value; }
	Color get_dump_header_color() const { return dump_header_color; }

	Color get_level_color(int p_level) const;

	// Registers all logging-related settings in ProjectSettings if they don't
	// exist. Called automatically by the Print singleton during initialization.
	static void _register_settings();

	// Creates a new PrintSettings instance with values from ProjectSettings.
	static Ref<PrintSettings> from_project_settings();

	// Updates this instance with values from ProjectSettings.
	void load_from_project_settings();

	// Duplicates this instance, applying overrides for property names that exist.
	Ref<PrintSettings> duplicate_with_overrides(const Dictionary &p_overrides = Dictionary());
};

} // namespace godot
