#pragma once

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/resource.hpp>

namespace godot {

// Configuration for a specific logger: a unique name plus print/archive
// verbosity levels. Instances can be added to a LoggerRegistry to initialize
// loggers automatically at startup.
// GDScript's LoggerConfig.new(name, print, archive) becomes LoggerConfig.create(...).
class LoggerConfig : public Resource {
	GDCLASS(LoggerConfig, Resource)

	String name = "Log";
	// Levels are stored as plain ints (0-5) exactly like the GDScript
	// @export_enum("Silent", ..., "Verbose") int properties.
	int print_level = 5;
	int archive_level = 5;

protected:
	static void _bind_methods();

public:
	static Ref<LoggerConfig> create(const String &p_name = "Log", int p_print = 5, int p_archive = 5);

	// Accessor names avoid Resource's own set_name/get_name (resource_name);
	// the bound property is still called "name" so the GDScript API is unchanged.
	void set_logger_name(const String &p_name) { name = p_name; }
	String get_logger_name() const { return name; }
	void set_print_level(int p_level) { print_level = p_level; }
	int get_print_level() const { return print_level; }
	void set_archive_level(int p_level) { archive_level = p_level; }
	int get_archive_level() const { return archive_level; }
};

} // namespace godot
