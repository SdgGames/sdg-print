#pragma once

#include "log_node.h"
#include "ring_buffer.h"

#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

// A single logger's data within an error dump. (GDScript's inner class
// DumpData.LoggerData — GDExtension has no nested classes, so it registers as
// the top-level "LoggerData"; nothing outside the runtime referenced the
// scoped name.)
class LoggerData : public RefCounted {
	GDCLASS(LoggerData, RefCounted)

	StringName id;
	Ref<RingBuffer> log_history;
	Ref<RingBuffer> frame_history;

protected:
	static void _bind_methods();

public:
	static Ref<LoggerData> create(const StringName &p_logger_id);

	void set_id(const StringName &p_id) { id = p_id; }
	StringName get_id() const { return id; }
	void set_log_history(const Ref<RingBuffer> &p_history) { log_history = p_history; }
	Ref<RingBuffer> get_log_history() const { return log_history; }
	void set_frame_history(const Ref<RingBuffer> &p_history) { frame_history = p_history; }
	Ref<RingBuffer> get_frame_history() const { return frame_history; }

	void load_from_dict(const Dictionary &p_data);

	// All archived entries at or above the given priority, plus all frames.
	TypedArray<LogEntry> get_entries(int p_min_level = Log::LEVEL_FRAME_ONLY);
};

// The data for one error dump: metadata plus per-logger histories, with the
// collated and per-module view trees the dump viewer renders.
class DumpData : public RefCounted {
	GDCLASS(DumpData, RefCounted)

	Dictionary metadata;
	Dictionary loggers; // logger id -> LoggerData
	int64_t dump_index = -1;

	Ref<LogNode> collated_root;
	Ref<LogNode> module_root;

	void _build_view_trees();
	Array _get_collated_entries();

protected:
	static void _bind_methods();

public:
	void set_metadata(const Dictionary &p_metadata) { metadata = p_metadata; }
	Dictionary get_metadata() const { return metadata; }
	void set_loggers(const Dictionary &p_loggers) { loggers = p_loggers; }
	Dictionary get_loggers() const { return loggers; }
	void set_dump_index(int64_t p_index) { dump_index = p_index; }
	int64_t get_dump_index() const { return dump_index; }
	void set_collated_root(const Ref<LogNode> &p_root) { collated_root = p_root; }
	Ref<LogNode> get_collated_root() const { return collated_root; }
	void set_module_root(const Ref<LogNode> &p_root) { module_root = p_root; }
	Ref<LogNode> get_module_root() const { return module_root; }

	String get_formatted_header() const;

	bool load_from_dict(const Dictionary &p_data);
};

} // namespace godot
