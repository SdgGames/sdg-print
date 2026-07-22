#include "error_dump.h"

#include "sdg_print.h"

#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/engine_debugger.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

const char *ErrorDump::LATEST_DUMP_PATH = "user://dumps/latest_dump.json";

// Order must match the DumpReason enum values (DumpReason.keys()[reason]).
static const char *DUMP_REASON_KEYS[] = {
	"FLUSH", "MANUAL", "APP_CLOSE", "WARNING", "ERROR", "UNSPECIFIED"
};
static const int DUMP_REASON_KEY_COUNT = sizeof(DUMP_REASON_KEYS) / sizeof(DUMP_REASON_KEYS[0]);

void ErrorDump::_bind_methods() {
	ClassDB::bind_static_method("ErrorDump", D_METHOD("get_latest_dump_path"), &ErrorDump::get_latest_dump_path);
	ClassDB::bind_static_method("ErrorDump", D_METHOD("save_dump", "logger_data", "reason", "context"), &ErrorDump::save_dump, DEFVAL((int)DUMP_REASON_UNSPECIFIED), DEFVAL(String()));
	ClassDB::bind_static_method("ErrorDump", D_METHOD("show_debug_window", "session_path"), &ErrorDump::show_debug_window);
	ClassDB::bind_static_method("ErrorDump", D_METHOD("load_dumps", "file_path"), &ErrorDump::load_dumps);
	ClassDB::bind_static_method("ErrorDump", D_METHOD("list_dump_files"), &ErrorDump::list_dump_files);
	ClassDB::bind_static_method("ErrorDump", D_METHOD("cleanup_old_dumps", "keep_count"), &ErrorDump::cleanup_old_dumps, DEFVAL(10));
	ClassDB::bind_static_method("ErrorDump", D_METHOD("create_dump_dict", "logger_data", "reason", "context"), &ErrorDump::create_dump_dict, DEFVAL(String()));

	ClassDB::bind_integer_constant(get_class_static(), "DumpReason", "FLUSH", DUMP_REASON_FLUSH);
	ClassDB::bind_integer_constant(get_class_static(), "DumpReason", "MANUAL", DUMP_REASON_MANUAL);
	ClassDB::bind_integer_constant(get_class_static(), "DumpReason", "APP_CLOSE", DUMP_REASON_APP_CLOSE);
	ClassDB::bind_integer_constant(get_class_static(), "DumpReason", "WARNING", DUMP_REASON_WARNING);
	ClassDB::bind_integer_constant(get_class_static(), "DumpReason", "ERROR", DUMP_REASON_ERROR);
	ClassDB::bind_integer_constant(get_class_static(), "DumpReason", "UNSPECIFIED", DUMP_REASON_UNSPECIFIED);
}

String ErrorDump::get_latest_dump_path() {
	return String(LATEST_DUMP_PATH);
}

Error ErrorDump::save_dump(const Dictionary &p_logger_data, int p_reason, const String &p_context) {
	_ensure_dumps_directory();

	// Create the dump dictionary once.
	Dictionary dump_dict = create_dump_dict(p_logger_data, p_reason, p_context);

	// Handle session file.
	SDG_Print *print = SDG_Print::get_singleton();
	String session_path = print ? print->get_current_dump_file() : String();
	if (session_path.is_empty()) {
		session_path = _generate_session_file_path();
		if (print) {
			print->set_current_dump_file(session_path);
		}

		// Create new file with opening bracket.
		Ref<FileAccess> file = FileAccess::open(session_path, FileAccess::WRITE);
		if (file.is_null()) {
			UtilityFunctions::push_error(String("Failed to create session dump file: ") + session_path);
			return ERR_CANT_CREATE;
		}
		_append_to_file(file, dump_dict, true);
	} else {
		// Append to existing file.
		Ref<FileAccess> file = FileAccess::open(session_path, FileAccess::READ_WRITE);
		if (file.is_null()) {
			UtilityFunctions::push_error(String("Failed to open session dump file: ") + session_path);
			return ERR_FILE_CANT_OPEN;
		}

		// Seek to just before the last two characters (the newline and closing bracket).
		file->seek(file->get_length() - 2);
		_append_to_file(file, dump_dict, false);
	}

	if (p_reason == DUMP_REASON_MANUAL) {
		show_debug_window(session_path);
	}

	// Mirror to latest dump file if we're in the editor.
	if (OS::get_singleton()->has_feature("editor") && p_reason >= DUMP_REASON_APP_CLOSE) {
		// Copy the entire session file to latest_dump.
		Ref<FileAccess> session_file = FileAccess::open(session_path, FileAccess::READ);
		Ref<FileAccess> latest_file = FileAccess::open(LATEST_DUMP_PATH, FileAccess::WRITE);

		if (session_file.is_valid() && latest_file.is_valid()) {
			latest_file->store_string(session_file->get_as_text());
			latest_file->close();
			session_file->close();

			// Pause execution and load the dump in the editor immediately.
			// (GDScript used the `breakpoint` keyword here.) EngineDebugger.debug
			// fires the debug session's `breaked` signal so DumpDebugger loads
			// the dump into the Print tab; with no debugger attached (exported
			// game, headless) it is skipped, matching `breakpoint`'s no-op.
			if (p_reason >= DUMP_REASON_WARNING) {
				EngineDebugger *debugger = EngineDebugger::get_singleton();
				if (debugger && debugger->is_active()) {
					debugger->debug(true, true);
				}
			}
		}
	}
	return OK;
}

// Temporary debug function to show the print editor tab in a window.
void ErrorDump::show_debug_window(const String &p_session_path) {
	// Create window.
	Window *window = memnew(Window);
	window->set_title("Print Debug Viewer");

	// Get the game window size and position.
	SceneTree *tree = Object::cast_to<SceneTree>(Engine::get_singleton()->get_main_loop());
	ERR_FAIL_NULL(tree);
	Window *game_window = tree->get_root()->get_window();
	Vector2i screen_size = DisplayServer::get_singleton()->screen_get_size();

	// Set size to 95% of game window size.
	window->set_size(Vector2i((int)(game_window->get_size().x * 0.95), (int)(game_window->get_size().y * 0.95)));

	// Center on screen.
	window->set_position(Vector2i((screen_size.x - window->get_size().x) / 2, (screen_size.y - window->get_size().y) / 2));

	// Enable window features.
	window->set_flag(Window::FLAG_RESIZE_DISABLED, false); // unresizable = false
	window->set_min_size(Vector2i(400, 300)); // Set minimum size.
	window->set_max_size(Vector2i(0, 0)); // No maximum size (0,0 means unlimited).
	window->set_mode(Window::MODE_WINDOWED); // Start in windowed mode.
	window->set_flag(Window::FLAG_BORDERLESS, false);
	window->set_transparent_background(false);
	window->connect("close_requested", Callable(window, "queue_free"));

	// Load and add print editor tab.
	Ref<PackedScene> crash_report = ResourceLoader::get_singleton()->load("res://addons/sdg-print/dumps/crash_report.tscn");
	ERR_FAIL_COND_MSG(crash_report.is_null(), "Failed to load crash_report.tscn");
	Node *editor_tab = crash_report->instantiate();
	window->add_child(editor_tab);

	// Make editor tab fill window.
	editor_tab->set("anchors_preset", (int)Control::PRESET_FULL_RECT);

	// Add window to scene tree.
	tree->get_root()->add_child(window);

	// Load the latest dump.
	editor_tab->call("load_latest_dump", p_session_path);
}

TypedArray<DumpData> ErrorDump::load_dumps(const String &p_file_path) {
	TypedArray<DumpData> dump_data;

	if (!FileAccess::file_exists(p_file_path)) {
		UtilityFunctions::push_error(String("Dump file not found: ") + p_file_path);
		return dump_data;
	}

	Ref<FileAccess> file = FileAccess::open(p_file_path, FileAccess::READ);
	if (file.is_null()) {
		UtilityFunctions::push_error(String("Failed to open dump file: ") + p_file_path);
		return dump_data;
	}

	Ref<JSON> json;
	json.instantiate();
	if (json->parse(file->get_as_text()) != OK) {
		UtilityFunctions::push_error(String("Failed to parse dump file: ") + json->get_error_message());
		return dump_data;
	}

	Variant dumps_variant = json->get_data();
	if (dumps_variant.get_type() != Variant::ARRAY) {
		UtilityFunctions::push_error("Invalid dump file format - expected array of dumps");
		return dump_data;
	}

	Array dumps = dumps_variant;
	for (int64_t idx = 0; idx < dumps.size(); idx++) {
		Dictionary dump_dict = dumps[idx];
		Ref<DumpData> dump;
		dump.instantiate();
		dump->set_dump_index(idx + 1);
		if (dump->load_from_dict(dump_dict)) {
			dump_data.append(dump);
		}
	}

	return dump_data;
}

TypedArray<String> ErrorDump::list_dump_files() {
	_ensure_dumps_directory();

	TypedArray<String> files;
	Ref<DirAccess> dir = DirAccess::open("user://dumps");
	if (dir.is_valid()) {
		dir->list_dir_begin();
		String file_name = dir->get_next();
		while (!file_name.is_empty()) {
			if (!dir->current_is_dir() && file_name.ends_with(".json")) {
				files.append(String("user://dumps/") + file_name);
			}
			file_name = dir->get_next();
		}
	}

	return files;
}

void ErrorDump::cleanup_old_dumps(int p_keep_count) {
	TypedArray<String> files = list_dump_files();
	files.sort(); // Timestamp in filename ensures chronological order.

	if (files.size() <= p_keep_count) {
		return;
	}

	for (int64_t i = 0; i < files.size() - p_keep_count; i++) {
		String file_path = files[i];
		Ref<DirAccess> dir = DirAccess::open("user://dumps");
		if (dir.is_valid()) {
			dir->remove(file_path);
		}
	}
}

Dictionary ErrorDump::create_dump_dict(const Dictionary &p_logger_data, int p_reason, const String &p_context) {
	String reason_key = (p_reason >= 0 && p_reason < DUMP_REASON_KEY_COUNT) ? DUMP_REASON_KEYS[p_reason] : DUMP_REASON_KEYS[DUMP_REASON_UNSPECIFIED];
	String reason_string = String(reason_key).capitalize();
	if (!p_context.is_empty()) {
		reason_string += String(" - ") + p_context;
	}
	SDG_Print *print = SDG_Print::get_singleton();
	Dictionary dict;
	dict["timestamp"] = Time::get_singleton()->get_unix_time_from_system();
	dict["reason"] = reason_string;
	dict["module_width"] = print ? print->get_current_module_width() : 0;
	dict["loggers"] = p_logger_data;
	return dict;
}

// Generates a dump file path for the current game session.
String ErrorDump::_generate_session_file_path() {
	Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_system();
	String file_name = String("error_dump_") +
			String::num_int64(datetime["year"]) +
			String::num_int64(datetime["month"]).pad_zeros(2) +
			String::num_int64(datetime["day"]).pad_zeros(2) + String("_") +
			String::num_int64(datetime["hour"]).pad_zeros(2) +
			String::num_int64(datetime["minute"]).pad_zeros(2) +
			String::num_int64(datetime["second"]).pad_zeros(2) + String(".json");
	return String("user://dumps/") + file_name;
}

// Add this dump to the current file with the appropriate array punctuation.
void ErrorDump::_append_to_file(const Ref<FileAccess> &p_file, const Dictionary &p_dump_dict, bool p_is_first) {
	// Matches GDScript's JSON.stringify(dump_dict, "\t") — sort_keys defaults
	// to true there, so keys are sorted here too for byte compatibility.
	String json_str = JSON::stringify(p_dump_dict, "\t", true, false);
	if (p_is_first) {
		p_file->store_string(String("[\n") + json_str + String("\n]"));
	} else {
		p_file->store_string(String(",\n") + json_str + String("\n]"));
	}
}

// Ensures the dumps directory exists.
void ErrorDump::_ensure_dumps_directory() {
	Ref<DirAccess> dir = DirAccess::open("user://");
	if (dir.is_valid() && !dir->dir_exists("dumps")) {
		dir->make_dir("dumps");
	}
}
