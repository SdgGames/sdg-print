#include "frame_log.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void FrameLog::_bind_methods() {
	ClassDB::bind_static_method("FrameLog", D_METHOD("create", "title", "details"), &FrameLog::create, DEFVAL(String()), DEFVAL(String()));

	ClassDB::bind_method(D_METHOD("set_title", "title"), &FrameLog::set_title);
	ClassDB::bind_method(D_METHOD("get_title"), &FrameLog::get_title);
	ClassDB::bind_method(D_METHOD("set_details", "details"), &FrameLog::set_details);
	ClassDB::bind_method(D_METHOD("get_details"), &FrameLog::get_details);
	ClassDB::bind_method(D_METHOD("set_is_complete", "is_complete"), &FrameLog::set_is_complete);
	ClassDB::bind_method(D_METHOD("get_is_complete"), &FrameLog::get_is_complete);
	ADD_PROPERTY(PropertyInfo(Variant::STRING, "title"), "set_title", "get_title");
	ADD_PROPERTY(PropertyInfo(Variant::STRING, "details"), "set_details", "get_details");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_complete"), "set_is_complete", "get_is_complete");

	ClassDB::bind_method(D_METHOD("format", "include_title"), &FrameLog::format, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("to_dict"), &FrameLog::to_dict);
	ClassDB::bind_static_method("FrameLog", D_METHOD("from_dict", "data"), &FrameLog::from_dict);
}

Ref<FrameLog> FrameLog::create(const String &p_title, const String &p_details) {
	Ref<FrameLog> frame;
	frame.instantiate();
	frame->title = p_title;
	frame->details = p_details;
	frame->is_complete = false;
	return frame;
}

String FrameLog::format(bool p_include_title) const {
	String output;

	if (!is_complete) {
		output = "[WARNING: Frame capture incomplete]\n";
	}

	if (p_include_title && !title.is_empty()) {
		output += title + String("\n");
	}

	if (!details.is_empty()) {
		output += details;
	}

	return output;
}

Dictionary FrameLog::to_dict() const {
	Dictionary dict;
	dict["title"] = title;
	dict["details"] = details;
	dict["is_complete"] = is_complete;
	return dict;
}

Ref<FrameLog> FrameLog::from_dict(const Dictionary &p_data) {
	Ref<FrameLog> frame = create(p_data["title"], p_data["details"]);
	frame->is_complete = p_data["is_complete"];
	return frame;
}
