class_name Item

extends Reference

var use_function: FuncRef
var params: Dictionary

var targeting: bool = false
var targeting_message: LogMessage

func use(_d: Dictionary) -> Array:
	# NOTE(rivten): inject the static item data with the passed parameters
	for k in params.keys():
		assert(not _d.has(k))
		_d[k] = params[k]
	return use_function.call_func(_d)
