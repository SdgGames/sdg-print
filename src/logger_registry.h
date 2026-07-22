#pragma once

#include "logger_config.h"

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/typed_array.hpp>

namespace godot {

// A collection of logger configurations for the Print system. Each project can
// create its own registry resource and reference it in Project Settings under
// debug/logging/logger_registry_path; the Print singleton loads it at startup
// and creates all defined loggers.
class LoggerRegistry : public Resource {
	GDCLASS(LoggerRegistry, Resource)

	Ref<LoggerConfig> print_logger;
	Ref<LoggerConfig> global_logger;
	TypedArray<LoggerConfig> loggers;

protected:
	static void _bind_methods();

public:
	static const char *REGISTRY_PATH_SETTING; // debug/logging/logger_registry_path
	static const char *REQUIRE_REGISTRY_SETTING; // debug/logging/require_registry

	// Defensive getters: lazily create the required Print/Global configs so a
	// registry is always usable, exactly like the GDScript property getters.
	Ref<LoggerConfig> get_print_logger();
	void set_print_logger(const Ref<LoggerConfig> &p_config);
	Ref<LoggerConfig> get_global_logger();
	void set_global_logger(const Ref<LoggerConfig> &p_config);

	void set_loggers(const TypedArray<LoggerConfig> &p_loggers) { loggers = p_loggers; }
	TypedArray<LoggerConfig> get_loggers() const { return loggers; }

	// Registers logger_registry_path / require_registry in Project Settings.
	// Called by PrintSettings::_register_settings().
	static void register_project_settings();

	// Loads the registry referenced in Project Settings. On any failure an
	// error is printed and a default registry is returned (GDScript used
	// assert(false, ...) here, which only halted debug builds; we match the
	// release behavior: loud but non-fatal).
	static Ref<LoggerRegistry> load_from_project_settings();

	// New registries get a sensible default "Game" logger, matching GDScript's
	// _init(create_game_logger = true).
	LoggerRegistry();
};

} // namespace godot
