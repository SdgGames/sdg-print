#include "dump_data.h"

#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <vector>

using namespace godot;

// -- LoggerData --------------------------------------------------------------

void LoggerData::_bind_methods() {
	ClassDB::bind_static_method("LoggerData", D_METHOD("create", "logger_id"), &LoggerData::create);

	ClassDB::bind_method(D_METHOD("set_id", "id"), &LoggerData::set_id);
	ClassDB::bind_method(D_METHOD("get_id"), &LoggerData::get_id);
	ClassDB::bind_method(D_METHOD("set_log_history", "history"), &LoggerData::set_log_history);
	ClassDB::bind_method(D_METHOD("get_log_history"), &LoggerData::get_log_history);
	ClassDB::bind_method(D_METHOD("set_frame_history", "history"), &LoggerData::set_frame_history);
	ClassDB::bind_method(D_METHOD("get_frame_history"), &LoggerData::get_frame_history);
	ADD_PROPERTY(PropertyInfo(Variant::STRING_NAME, "id"), "set_id", "get_id");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "log_history", PROPERTY_HINT_RESOURCE_TYPE, "RingBuffer"), "set_log_history", "get_log_history");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "frame_history", PROPERTY_HINT_RESOURCE_TYPE, "RingBuffer"), "set_frame_history", "get_frame_history");

	ClassDB::bind_method(D_METHOD("load_from_dict", "data"), &LoggerData::load_from_dict);
	ClassDB::bind_method(D_METHOD("get_entries", "min_level"), &LoggerData::get_entries, DEFVAL((int)Log::LEVEL_FRAME_ONLY));
}

Ref<LoggerData> LoggerData::create(const StringName &p_logger_id) {
	Ref<LoggerData> data;
	data.instantiate();
	data->id = p_logger_id;
	return data;
}

// Rebuilds a RingBuffer from serialized data with LogEntry items bound to this
// logger's id. (GDScript used RingBuffer.from_dict with LogEntry.from_dict.bind(id);
// the manual loop is the same operation.)
static Ref<RingBuffer> entries_from_dict(const Dictionary &p_data, const StringName &p_id) {
	Ref<RingBuffer> buffer = RingBuffer::create(p_data["capacity"]);
	Array items = p_data["items"];
	for (int64_t i = 0; i < items.size(); i++) {
		buffer->push(LogEntry::from_dict(items[i], p_id));
	}
	return buffer;
}

void LoggerData::load_from_dict(const Dictionary &p_data) {
	log_history = entries_from_dict(p_data["log_history"], id);
	frame_history = entries_from_dict(p_data["frame_history"], id);
}

TypedArray<LogEntry> LoggerData::get_entries(int p_min_level) {
	TypedArray<LogEntry> entries;

	// Add log entries that meet the minimum level.
	Array logs = log_history->get_all();
	for (int64_t i = 0; i < logs.size(); i++) {
		Ref<LogEntry> entry = logs[i];
		if (entry->get_level() <= p_min_level) {
			entries.append(entry);
		}
	}

	// Add frame entries.
	Array frames = frame_history->get_all();
	for (int64_t i = 0; i < frames.size(); i++) {
		entries.append(frames[i]);
	}

	return entries;
}

// -- DumpData ----------------------------------------------------------------

void DumpData::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_metadata", "metadata"), &DumpData::set_metadata);
	ClassDB::bind_method(D_METHOD("get_metadata"), &DumpData::get_metadata);
	ClassDB::bind_method(D_METHOD("set_loggers", "loggers"), &DumpData::set_loggers);
	ClassDB::bind_method(D_METHOD("get_loggers"), &DumpData::get_loggers);
	ClassDB::bind_method(D_METHOD("set_dump_index", "index"), &DumpData::set_dump_index);
	ClassDB::bind_method(D_METHOD("get_dump_index"), &DumpData::get_dump_index);
	ClassDB::bind_method(D_METHOD("set_collated_root", "root"), &DumpData::set_collated_root);
	ClassDB::bind_method(D_METHOD("get_collated_root"), &DumpData::get_collated_root);
	ClassDB::bind_method(D_METHOD("set_module_root", "root"), &DumpData::set_module_root);
	ClassDB::bind_method(D_METHOD("get_module_root"), &DumpData::get_module_root);
	ClassDB::bind_method(D_METHOD("get_formatted_header"), &DumpData::get_formatted_header);

	ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "metadata"), "set_metadata", "get_metadata");
	ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "loggers"), "set_loggers", "get_loggers");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "dump_index"), "set_dump_index", "get_dump_index");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "collated_root", PROPERTY_HINT_RESOURCE_TYPE, "LogNode"), "set_collated_root", "get_collated_root");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "module_root", PROPERTY_HINT_RESOURCE_TYPE, "LogNode"), "set_module_root", "get_module_root");
	ADD_PROPERTY(PropertyInfo(Variant::STRING, "formatted_header", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NONE), "", "get_formatted_header");

	ClassDB::bind_method(D_METHOD("load_from_dict", "data"), &DumpData::load_from_dict);
}

String DumpData::get_formatted_header() const {
	Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_unix_time((int64_t)(double)metadata["timestamp"]);
	String date_str = String::num_int64(datetime["month"]).pad_zeros(2) + String("-") +
			String::num_int64(datetime["day"]).pad_zeros(2) + String("-") +
			String::num_int64(datetime["year"]) + String(" ") +
			String::num_int64(datetime["hour"]).pad_zeros(2) + String(":") +
			String::num_int64(datetime["minute"]).pad_zeros(2) + String(":") +
			String::num_int64(datetime["second"]).pad_zeros(2);
	return String("Dump ") + String::num_int64(dump_index) + String(" | ") + date_str +
			String(" | Reason: ") + String(metadata["reason"]);
}

bool DumpData::load_from_dict(const Dictionary &p_data) {
	metadata = Dictionary();
	metadata["timestamp"] = p_data["timestamp"];
	metadata["reason"] = p_data["reason"];
	metadata["module_width"] = p_data["module_width"];

	// Load each logger's data.
	Dictionary data_loggers = p_data["loggers"];
	Array logger_ids = data_loggers.keys();
	for (int64_t i = 0; i < logger_ids.size(); i++) {
		StringName logger_id = logger_ids[i];
		Ref<LoggerData> logger_data = LoggerData::create(logger_id);
		logger_data->load_from_dict(data_loggers[logger_ids[i]]);
		loggers[logger_ids[i]] = logger_data;
	}

	// Build both views.
	_build_view_trees();

	return true;
}

// Sort newest first (descending timestamp), like the GDScript sort_custom.
static void sort_entries_newest_first(Array &p_entries) {
	std::vector<Ref<LogEntry>> buffer;
	buffer.reserve(p_entries.size());
	for (int64_t i = 0; i < p_entries.size(); i++) {
		buffer.push_back(p_entries[i]);
	}
	std::sort(buffer.begin(), buffer.end(), [](const Ref<LogEntry> &a, const Ref<LogEntry> &b) {
		return a->get_timestamp() > b->get_timestamp();
	});
	for (int64_t i = 0; i < p_entries.size(); i++) {
		p_entries[i] = buffer[i];
	}
}

void DumpData::_build_view_trees() {
	// Create dump header entry.
	Ref<LogEntry> dump_header = LogEntry::create(Log::LEVEL_SILENT, StringName("DUMP"), get_formatted_header(), Ref<FrameLog>());

	// Build collated view.
	Array all_entries = _get_collated_entries();
	collated_root = LogNode::create(LogNode::NODE_TYPE_ROOT, dump_header);
	collated_root->consume_entries(all_entries);

	// Build module view.
	module_root = LogNode::create(LogNode::NODE_TYPE_ROOT, dump_header);

	// Sort module IDs for consistent ordering.
	Array module_ids = loggers.keys();
	module_ids.sort();

	String empty_modules;

	// Create module nodes and feed them their entries.
	for (int64_t i = 0; i < module_ids.size(); i++) {
		String module_id = module_ids[i];
		Ref<LoggerData> logger = loggers[module_ids[i]];
		Array entries = logger->get_entries();

		// Don't add empty modules - they just add visual clutter.
		if (entries.size() == 0) {
			empty_modules += empty_modules.is_empty() ? module_id : (String(", ") + module_id);
			continue;
		}

		// Sort entries by timestamp, newest first.
		sort_entries_newest_first(entries);

		// Create and add module node.
		Ref<LogNode> module_node = LogNode::create(LogNode::NODE_TYPE_ROOT,
				LogEntry::create(Log::LEVEL_SILENT, StringName(module_id), String(), Ref<FrameLog>()));
		module_root->add_child(module_node);

		// Let the module node process its entries.
		module_node->consume_entries(entries);
	}

	// Add a list of all empty modules (in case the user is looking for them).
	if (!empty_modules.is_empty()) {
		module_root->add_child(LogNode::create(LogNode::NODE_TYPE_ENTRY,
				LogEntry::create(Log::LEVEL_INFO, StringName(""), String("Modules with no logs to display:\n") + empty_modules, Ref<FrameLog>())));
	}
}

// All entries from all loggers in timestamp order (newest first).
Array DumpData::_get_collated_entries() {
	Array all_entries;

	// Collect all entries.
	Array values = loggers.values();
	for (int64_t i = 0; i < values.size(); i++) {
		Ref<LoggerData> logger = values[i];
		all_entries.append_array(logger->get_entries());
	}

	// Sort by timestamp, newest first.
	sort_entries_newest_first(all_entries);

	return all_entries;
}
