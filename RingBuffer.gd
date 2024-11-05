class_name RingBuffer extends RefCounted
## A fixed-size circular buffer implementation.
##
## RingBuffer maintains a fixed number of elements in a circular fashion.
## When the buffer is full, adding new elements overwrites the oldest ones.
## This is used internally by the [Logger] class to maintain history of logs
## and frame data without unbounded memory growth.

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
