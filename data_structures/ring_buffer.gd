class_name RingBuffer extends RefCounted
## A fixed-size circular buffer implementation.
##
## RingBuffer maintains a fixed number of elements in a circular fashion.
## When the buffer is full, adding new elements overwrites the oldest ones.
##
## RingBuffers can store any type of data. However, items should have a
## [method to_dict] method if you want to save a buffer to a dictionary. You
## can load a buffer from a dictionary as well, as long as you supply a factory
## method for loading the element from a dictionary.

## The maximum number of elements this buffer can hold
var capacity: int

## The current number of elements in the buffer
var size: int:
	get:
		return _size

## The actual data storage
var _data: Array
## Current write position
var _write_pos: int
## Current size
var _size: int


func _init(max_size: int):
	capacity = max_size
	_data = []
	_data.resize(capacity)
	_write_pos = 0
	_size = 0


## Adds an item to the buffer. If the buffer is full, overwrites the oldest item.
func push(item) -> void:
	_data[_write_pos] = item
	_write_pos = (_write_pos + 1) % capacity
	_size = mini(_size + 1, capacity)


## Returns all items in chronological order (oldest first).
func get_all() -> Array:
	if _size == 0:
		return []
		
	var result = []
	# If we haven't wrapped around yet, just return the populated portion
	if _size < capacity:
		for i in range(_size):
			result.push_back(_data[i])
		return result
	
	# If we've wrapped around, need to reconstruct the chronological order
	var start_idx = _write_pos # This is where the oldest item is
	for i in range(capacity):
		var idx = (start_idx + i) % capacity
		result.push_back(_data[idx])
	return result


## Clears all items from the buffer.
func clear() -> void:
	_data.clear()
	_data.resize(capacity)
	_write_pos = 0
	_size = 0


## Returns a dictionary representation of the buffer with items in chronological order
func to_dict() -> Dictionary:
	var items := []
	# For each LogEntry or FrameLog in the buffer
	for item in get_all():
		# Call to_dict() on the item to convert it to a dictionary
		items.append(item.to_dict())
	return {
		"capacity": capacity,
		"items": items  # Already returns items in chronological order
	}


## Creates a new RingBuffer from dictionary data. [param item_factory] is the item's
## [method from_dict] function or similar. This method should take a dictionary as its
## only argument and return a new item of the expected type.
static func from_dict(data: Dictionary, item_factory: Callable) -> RingBuffer:
	var buffer = RingBuffer.new(data.capacity)
	# For each dictionary in the saved data
	for item_data in data.items:
		# Create new LogEntry or FrameLog based on the stored type
		buffer.push(item_factory.call(item_data))
	return buffer
