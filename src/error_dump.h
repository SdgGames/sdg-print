#pragma once

#include "dump_data.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/typed_array.hpp>

namespace godot {

// Static-style class that handles saving and loading of error dump files.
// Manages dump file versioning, formatting, and aggregation across sessions.
//
// A session's dumps accumulate in ONE JSON array per file: the first write is
// "[\n{...}\n]", later writes seek to 2 bytes before EOF and insert ",\n{...}\n]".
// The format (including tab indentation) is byte-compatible with the GDScript
// version so old dump files still load.
class ErrorDump : public RefCounted {
	GDCLASS(ErrorDump, RefCounted)

public:
	// File used by the dump viewer. Only generated when running from the editor.
	// (GDScript exposed this as the constant LATEST_DUMP_PATH; native classes
	// can't bind string constants, so callers use get_latest_dump_path().)
	static const char *LATEST_DUMP_PATH;

	// Enum ordering is load-bearing: comparisons like `reason >= APP_CLOSE`
	// gate the editor mirror/pause. Prefixed to dodge the Windows ERROR macro;
	// bound to the clean names (ErrorDump.DumpReason.ERROR) in _bind_methods.
	enum DumpReason {
		DUMP_REASON_FLUSH = 0, // Routine dump to disk; nothing is wrong.
		DUMP_REASON_MANUAL = 1, // User manually requested dump.
		DUMP_REASON_APP_CLOSE = 2, // Program closed normally with debugging enabled.
		DUMP_REASON_WARNING = 3, // Warning triggered dump.
		DUMP_REASON_ERROR = 4, // Error triggered dump.
		DUMP_REASON_UNSPECIFIED = 5, // Unknown/unspecified reason.
	};

private:
	static String _generate_session_file_path();
	static void _append_to_file(const Ref<FileAccess> &p_file, const Dictionary &p_dump_dict, bool p_is_first);
	static void _ensure_dumps_directory();

protected:
	static void _bind_methods();

public:
	static String get_latest_dump_path();

	// Saves a dump to the current session's dump file (creating it if needed).
	static Error save_dump(const Dictionary &p_logger_data, int p_reason = DUMP_REASON_UNSPECIFIED, const String &p_context = String());

	// Shows the crash-report window with the given session file loaded.
	static void show_debug_window(const String &p_session_path);

	// Loads and validates all dumps from a file, skipping any that fail.
	static TypedArray<DumpData> load_dumps(const String &p_file_path);

	// Lists all dump files in the dumps directory.
	static TypedArray<String> list_dump_files();

	// Keeps only the newest p_keep_count dump files.
	static void cleanup_old_dumps(int p_keep_count = 10);

	// Builds the standardized dump dictionary with metadata.
	static Dictionary create_dump_dict(const Dictionary &p_logger_data, int p_reason, const String &p_context = String());
};

} // namespace godot

VARIANT_ENUM_CAST(godot::ErrorDump::DumpReason);
