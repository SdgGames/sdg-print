#include "logger_registry.h"

#include "log.h"

#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

const char *LoggerRegistry::REGISTRY_PATH_SETTING = "debug/logging/logger_registry_path";
const char *LoggerRegistry::REQUIRE_REGISTRY_SETTING = "debug/logging/require_registry";

void LoggerRegistry::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_print_logger", "config"), &LoggerRegistry::set_print_logger);
	ClassDB::bind_method(D_METHOD("get_print_logger"), &LoggerRegistry::get_print_logger);
	ClassDB::bind_method(D_METHOD("set_global_logger", "config"), &LoggerRegistry::set_global_logger);
	ClassDB::bind_method(D_METHOD("get_global_logger"), &LoggerRegistry::get_global_logger);
	ClassDB::bind_method(D_METHOD("set_loggers", "loggers"), &LoggerRegistry::set_loggers);
	ClassDB::bind_method(D_METHOD("get_loggers"), &LoggerRegistry::get_loggers);

	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "print_logger", PROPERTY_HINT_RESOURCE_TYPE, "LoggerConfig"), "set_print_logger", "get_print_logger");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "global_logger", PROPERTY_HINT_RESOURCE_TYPE, "LoggerConfig"), "set_global_logger", "get_global_logger");
	// Typed array hint: element type OBJECT with a resource-type hint of LoggerConfig,
	// the C++ spelling of GDScript's `Array[LoggerConfig]` export.
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "loggers", PROPERTY_HINT_ARRAY_TYPE,
						 String::num_int64(Variant::OBJECT) + String("/") + String::num_int64(PROPERTY_HINT_RESOURCE_TYPE) + String(":LoggerConfig")),
			"set_loggers", "get_loggers");

	ClassDB::bind_static_method("LoggerRegistry", D_METHOD("register_project_settings"), &LoggerRegistry::register_project_settings);
	ClassDB::bind_static_method("LoggerRegistry", D_METHOD("load_from_project_settings"), &LoggerRegistry::load_from_project_settings);
}

LoggerRegistry::LoggerRegistry() {
	loggers.append(LoggerConfig::create("Game", Log::LEVEL_VERBOSE, Log::LEVEL_VERBOSE));
}

Ref<LoggerConfig> LoggerRegistry::get_print_logger() {
	if (print_logger.is_null()) {
		print_logger = LoggerConfig::create("Print", Log::LEVEL_INFO, Log::LEVEL_VERBOSE);
		notify_property_list_changed();
	}
	return print_logger;
}

void LoggerRegistry::set_print_logger(const Ref<LoggerConfig> &p_config) {
	if (p_config.is_null()) {
		print_logger = LoggerConfig::create("Print", Log::LEVEL_INFO, Log::LEVEL_VERBOSE);
	} else {
		print_logger = p_config;
	}
}

Ref<LoggerConfig> LoggerRegistry::get_global_logger() {
	if (global_logger.is_null()) {
		global_logger = LoggerConfig::create("Global", Log::LEVEL_VERBOSE, Log::LEVEL_VERBOSE);
		notify_property_list_changed();
	}
	return global_logger;
}

void LoggerRegistry::set_global_logger(const Ref<LoggerConfig> &p_config) {
	if (p_config.is_null()) {
		global_logger = LoggerConfig::create("Global", Log::LEVEL_VERBOSE, Log::LEVEL_VERBOSE);
	} else {
		global_logger = p_config;
	}
}

void LoggerRegistry::register_project_settings() {
	ProjectSettings *ps = ProjectSettings::get_singleton();

	if (!ps->has_setting(REGISTRY_PATH_SETTING)) {
		ps->set_setting(REGISTRY_PATH_SETTING, "");
		ps->set_initial_value(REGISTRY_PATH_SETTING, "");

		Dictionary info;
		info["name"] = REGISTRY_PATH_SETTING;
		info["type"] = Variant::STRING;
		info["hint"] = PROPERTY_HINT_FILE;
		info["hint_string"] = "*.tres";
		ps->add_property_info(info);
	}

	if (!ps->has_setting(REQUIRE_REGISTRY_SETTING)) {
		ps->set_setting(REQUIRE_REGISTRY_SETTING, true);
		ps->set_initial_value(REQUIRE_REGISTRY_SETTING, true);

		Dictionary info;
		info["name"] = REQUIRE_REGISTRY_SETTING;
		info["type"] = Variant::BOOL;
		info["hint"] = PROPERTY_HINT_NONE;
		info["hint_string"] = "";
		ps->add_property_info(info);
	}
}

Ref<LoggerRegistry> LoggerRegistry::load_from_project_settings() {
	ProjectSettings *ps = ProjectSettings::get_singleton();
	String registry_path = ps->get_setting(REGISTRY_PATH_SETTING, "");

	// You need to create a resource to manage autoload loggers.
	if (registry_path.is_empty()) {
		if ((bool)ps->get_setting(REQUIRE_REGISTRY_SETTING, true)) {
			ERR_PRINT(String("Please create a LoggerRegistry resource and add it to ") + REGISTRY_PATH_SETTING +
					String(" in the Project Settings. If you don't want to create global loggers this way, disable ") +
					REQUIRE_REGISTRY_SETTING + String(" instead."));
		}
		// GDScript: LoggerRegistry.new(false) — a registry without the default Game logger.
		Ref<LoggerRegistry> registry;
		registry.instantiate();
		registry->loggers.clear();
		return registry;
	}

	if (ResourceLoader::get_singleton()->exists(registry_path)) {
		Ref<LoggerRegistry> registry = ResourceLoader::get_singleton()->load(registry_path);
		if (registry.is_valid()) {
			return registry;
		}
		ERR_PRINT(String("Resource at ") + registry_path + String(" is not a LoggerRegistry"));
	} else {
		ERR_PRINT(String("Log registry not found at path: ") + registry_path);
	}

	Ref<LoggerRegistry> registry;
	registry.instantiate();
	return registry;
}
