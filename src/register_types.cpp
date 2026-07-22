#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "dump_data.h"
#include "error_dump.h"
#include "frame_log.h"
#include "log_node.h"
#include "log.h"
#include "log_entry.h"
#include "logger_config.h"
#include "logger_registry.h"
#include "print_settings.h"
#include "ring_buffer.h"
#include "sdg_print.h"

using namespace godot;

void initialize_sdg_print_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	// Log first: other classes reference its Level enum in their bindings.
	ClassDB::register_class<Log>();
	ClassDB::register_class<PrintSettings>();
	ClassDB::register_class<RingBuffer>();
	ClassDB::register_class<FrameLog>();
	ClassDB::register_class<LogEntry>();
	ClassDB::register_class<LoggerConfig>();
	ClassDB::register_class<LoggerRegistry>();
	ClassDB::register_class<LogNode>();
	ClassDB::register_class<LoggerData>();
	ClassDB::register_class<DumpData>();
	ClassDB::register_class<ErrorDump>();
	ClassDB::register_class<SDG_Print>();
}

void uninitialize_sdg_print_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
// Library entry point. The engine finds this symbol by the name given as
// `entry_symbol` in sdg_print.gdextension.
GDExtensionBool GDE_EXPORT sdg_print_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_sdg_print_module);
	init_obj.register_terminator(uninitialize_sdg_print_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}
