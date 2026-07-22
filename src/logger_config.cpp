#include "logger_config.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void LoggerConfig::_bind_methods() {
	ClassDB::bind_static_method("LoggerConfig", D_METHOD("create", "name", "print_level", "archive_level"), &LoggerConfig::create, DEFVAL("Log"), DEFVAL(5), DEFVAL(5));

	ClassDB::bind_method(D_METHOD("set_logger_name", "name"), &LoggerConfig::set_logger_name);
	ClassDB::bind_method(D_METHOD("get_logger_name"), &LoggerConfig::get_logger_name);
	ClassDB::bind_method(D_METHOD("set_print_level", "level"), &LoggerConfig::set_print_level);
	ClassDB::bind_method(D_METHOD("get_print_level"), &LoggerConfig::get_print_level);
	ClassDB::bind_method(D_METHOD("set_archive_level", "level"), &LoggerConfig::set_archive_level);
	ClassDB::bind_method(D_METHOD("get_archive_level"), &LoggerConfig::get_archive_level);

	ADD_PROPERTY(PropertyInfo(Variant::STRING, "name"), "set_logger_name", "get_logger_name");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "print_level", PROPERTY_HINT_ENUM, "Silent,Error,Warning,Info,Debug,Verbose"), "set_print_level", "get_print_level");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "archive_level", PROPERTY_HINT_ENUM, "Silent,Error,Warning,Info,Debug,Verbose"), "set_archive_level", "get_archive_level");
}

Ref<LoggerConfig> LoggerConfig::create(const String &p_name, int p_print, int p_archive) {
	Ref<LoggerConfig> config;
	config.instantiate();
	config->name = p_name;
	config->print_level = p_print;
	config->archive_level = p_archive;
	return config;
}
