#include "log_node.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void LogNode::_bind_methods() {
	ClassDB::bind_static_method("LogNode", D_METHOD("create", "type", "entry"), &LogNode::create);

	ClassDB::bind_method(D_METHOD("set_type", "type"), &LogNode::set_type);
	ClassDB::bind_method(D_METHOD("get_type"), &LogNode::get_type);
	ClassDB::bind_method(D_METHOD("set_entry", "entry"), &LogNode::set_entry);
	ClassDB::bind_method(D_METHOD("get_entry"), &LogNode::get_entry);
	ClassDB::bind_method(D_METHOD("set_children", "children"), &LogNode::set_children);
	ClassDB::bind_method(D_METHOD("get_children"), &LogNode::get_children);
	ClassDB::bind_method(D_METHOD("set_effective_fold_level", "level"), &LogNode::set_effective_fold_level);
	ClassDB::bind_method(D_METHOD("get_effective_fold_level"), &LogNode::get_effective_fold_level);

	ADD_PROPERTY(PropertyInfo(Variant::INT, "type"), "set_type", "get_type");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "entry", PROPERTY_HINT_RESOURCE_TYPE, "LogEntry"), "set_entry", "get_entry");
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "children", PROPERTY_HINT_ARRAY_TYPE,
						 String::num_int64(Variant::OBJECT) + String("/") + String::num_int64(PROPERTY_HINT_RESOURCE_TYPE) + String(":LogNode")),
			"set_children", "get_children");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "effective_fold_level"), "set_effective_fold_level", "get_effective_fold_level");

	ClassDB::bind_method(D_METHOD("add_child", "child"), &LogNode::add_child);
	ClassDB::bind_method(D_METHOD("consume_entries", "entries"), &LogNode::consume_entries);

	ClassDB::bind_integer_constant(get_class_static(), "NodeType", "ROOT", NODE_TYPE_ROOT);
	ClassDB::bind_integer_constant(get_class_static(), "NodeType", "ENTRY", NODE_TYPE_ENTRY);
	ClassDB::bind_integer_constant(get_class_static(), "NodeType", "FOLD_POINT", NODE_TYPE_FOLD_POINT);
}

Ref<LogNode> LogNode::create(int p_type, const Ref<LogEntry> &p_entry) {
	Ref<LogNode> node;
	node.instantiate();
	node->type = p_type;
	node->entry = p_entry;

	// Set initial effective fold level based on type.
	switch (p_type) {
		case NODE_TYPE_ROOT:
			node->_fold_level = Log::LEVEL_SILENT;
			break;
		default:
			node->_fold_level = p_entry.is_null() ? (int)Log::LEVEL_FRAME_ONLY : p_entry->get_level();
			break;
	}
	node->effective_fold_level = node->_fold_level;
	return node;
}

void LogNode::add_child(const Ref<LogNode> &p_child) {
	children.append(p_child);
}

Ref<LogNode> LogNode::_create_fold_point(int p_level) {
	Ref<LogEntry> fold_entry = LogEntry::create(p_level, StringName("FOLD_POINT"), String(), Ref<FrameLog>());
	return create(NODE_TYPE_FOLD_POINT, fold_entry);
}

int LogNode::_look_ahead_for_fold_point(const Array &p_entries) {
	Ref<LogEntry> first = p_entries[0];
	int highest_level = first->get_level(); // Start with first child's level.
	int current_level = _fold_level;

	// Look ahead until we find an entry at our level or higher.
	for (int64_t i = 0; i < p_entries.size(); i++) {
		Ref<LogEntry> test_entry = p_entries[i];
		if (test_entry->get_level() <= current_level) {
			break;
		}
		highest_level = MIN(highest_level, test_entry->get_level()); // Remember lowest number = highest priority.
	}

	return highest_level;
}

// Consumes entries from the front of the (shared, mutated) array, building the
// child tree. Entries more verbose than this node nest below it; a fold point
// is inserted when the verbosity gap is 2+ levels and a higher-priority entry
// is coming up before our level would close the group.
void LogNode::consume_entries(const Array &p_entries) {
	// godot::Array shares storage, so pop_front here is visible to every caller
	// up the recursion — the same aliasing GDScript relied on.
	Array entries = p_entries;
	while (!entries.is_empty()) {
		Ref<LogEntry> next_entry = entries[0];

		// If next entry is more verbose, or same level, it might be our child.
		if (next_entry->get_level() > _fold_level || type == NODE_TYPE_ROOT) {
			// If there's a gap of 2+ levels, do look-ahead for first child.
			if (next_entry->get_level() > _fold_level + 1 && children.is_empty()) {
				int highest_level = _look_ahead_for_fold_point(entries);

				// If highest level is higher priority than next entry:
				if (highest_level < next_entry->get_level()) {
					// Add a fold point at that level and continue processing.
					Ref<LogNode> fold_node = _create_fold_point(highest_level);
					add_child(fold_node);
					fold_node->consume_entries(entries);
					continue; // Continue processing remaining entries.
				} else {
					// Set our effective fold level to one level above next entry.
					effective_fold_level = next_entry->get_level() - 1;
				}
			}

			Ref<LogNode> child = create(NODE_TYPE_ENTRY, next_entry);
			add_child(child);
			entries.pop_front();
			child->consume_entries(entries);
		} else {
			// Found a higher priority entry, stop consuming.
			break;
		}
	}
}
