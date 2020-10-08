class_name GameMap

extends Node2D

export(Color) var dark_wall = Color(0, 0, 100.0 / 255.0)
export(Color) var dark_ground = Color(50.0 / 255.0, 50.0 / 255.0, 150.0 / 255.0)
export(Color) var light_wall = Color(130.0 / 255.0, 110.0 / 255.0, 50.0 / 255.0)
export(Color) var light_ground = Color(200.0 / 255.0, 180.0 / 255.0, 50.0 / 255.0)

export(int) var width = 80
export(int) var height = 45

# NOTE(rivten): map generation
export(int) var room_min_size = 6
export(int) var room_max_size = 12
export(int) var max_rooms = 100

var tiles: Array = []
var tile_size_in_pixels: int # TODO(rivten): Not thrilled about this variable here...
var rooms: Array = []
var visible_tiles: Array = []

var a_star: AStar2D

# TODO(rivten): @optim use a tilemap node ? this should improve draw calls

func _init() -> void:
	tiles = initialize_tiles(width, height)
	a_star = AStar2D.new()

func _draw() -> void:
	for row in range(height):
		for col in range(width):
			var rect = Rect2(tile_size_in_pixels * Vector2(col, row), tile_size_in_pixels * Vector2(1, 1))
			var tile = tiles[row][col]
			var is_wall = tile.block_sight
			var is_explored = tile.explored
			var is_visible = is_tile_visible(self, tiles[row][col])
			if is_visible:
				if is_wall:
					draw_rect(rect, light_wall)
				else:
					draw_rect(rect, light_ground)
			elif is_explored:
				if is_wall:
					draw_rect(rect, dark_wall)
				else:
					draw_rect(rect, dark_ground)

static func create_room(_game_map: GameMap, room: Rect2) -> void:
	for row in range(room.position.y, room.end.y):
		for col in range(room.position.x, room.end.x):
			_game_map.tiles[row][col].blocked = false
			_game_map.tiles[row][col].block_sight = false

static func create_h_tunnel(_game_map: GameMap, x_start: int, x_end: int, y: int) -> void:
	var start = x_start
	var end = x_end
	if x_start > x_end:
		start = x_end
		end = x_start
	for col in range(start, end + 1):
		_game_map.tiles[y][col].blocked = false
		_game_map.tiles[y][col].block_sight = false

static func create_v_tunnel(_game_map: GameMap, y_start: int, y_end: int, x: int) -> void:
	var start = y_start
	var end = y_end
	if y_start > y_end:
		start = y_end
		end = y_start
	for row in range(start, end + 1):
		_game_map.tiles[row][x].blocked = false
		_game_map.tiles[row][x].block_sight = false

static func gen_map(_game_map: GameMap) -> void:
	# TODO(rivten): better map gen algorithm
	for _r in range(_game_map.max_rooms):
		var room_width = randi() % (_game_map.room_max_size - _game_map.room_min_size) + _game_map.room_min_size
		var room_height = randi() % (_game_map.room_max_size - _game_map.room_min_size) + _game_map.room_min_size
		var room_x = randi() % (_game_map.width - room_width - 1)
		var room_y = randi() % (_game_map.height - room_height - 1)

		var new_room = Rect2(room_x, room_y, room_width, room_height)
		var need_to_add = true
		for other_room in _game_map.rooms:
			if new_room.intersects(other_room):
				need_to_add = false
				break
		if need_to_add:
			create_room(_game_map, new_room)
			if _game_map.rooms.size() != 0:
				var prev_room = _game_map.rooms[_game_map.rooms.size() - 1]
				var prev_room_center = prev_room.position + 0.5 * prev_room.size
				var prev_room_center_x = int(prev_room_center.x)
				var prev_room_center_y = int(prev_room_center.y)
				var room_center_x = int(room_x + 0.5 * room_width)
				var room_center_y = int(room_y + 0.5 * room_height)
				if randi() % 2 == 0:
					create_h_tunnel(_game_map, prev_room_center_x, room_center_x, prev_room_center_y)
					create_v_tunnel(_game_map, prev_room_center_y, room_center_y, room_center_x)
				else:
					create_v_tunnel(_game_map, prev_room_center_y, room_center_y, prev_room_center_x)
					create_h_tunnel(_game_map, prev_room_center_x, room_center_x, room_center_y)

			_game_map.rooms.push_back(new_room)
	gen_a_star(_game_map)

static func gen_a_star(_game_map: GameMap) -> void:
	# NOTE(rivten): First pass : adding the points
	for row in range(_game_map.height):
		for col in range(_game_map.width):
			var tile = _game_map.tiles[row][col]
			if not tile.blocked:
				var tile_id = row * _game_map.width + col
				_game_map.a_star.add_point(tile_id, Vector2(col, row))

	# NOTE(rivten): Second pass : checking tile neighborhood
	for row in range(_game_map.height):
		for col in range(_game_map.width):
			var tile = _game_map.tiles[row][col]
			if not tile.blocked:
				var tile_id = row * _game_map.width + col
				var offset_list = [
						Vector2(-1, -1),
						Vector2(-1,  0),
						Vector2(-1,  1),
						Vector2( 0, -1),
						Vector2( 0,  1),
						Vector2( 1, -1),
						Vector2( 1,  0),
						Vector2( 1,  1),
					]
				for offset in offset_list:
					if are_tiles_connected(_game_map, Vector2(col, row), offset):
						var other_tile_id = (row + offset.y) * _game_map.width + (col + offset.x)
						_game_map.a_star.connect_points(tile_id, other_tile_id)

static func are_tiles_connected(_game_map: GameMap, _tile: Vector2, _offset: Vector2) -> bool:
	var other_tile = _tile + _offset
	if other_tile.x < 0:
		return false
	if other_tile.y < 0:
		return false
	if other_tile.x >= _game_map.width:
		return false
	if other_tile.y >= _game_map.height:
		return false

	assert(not _game_map.is_blocked(int(_tile.x), int(_tile.y)))

	return not _game_map.is_blocked(other_tile.x, other_tile.y)

static func initialize_tiles(_width: int, _height: int) -> Array:
	var _tiles = []
	for row in range(_height):
		_tiles.push_back([])
		for _col in range(_width):
			var tile = Tile.new()
			tile.blocked = true
			tile.block_sight = true
			_tiles[row].push_back(tile)

	return _tiles

static func is_position_visible(_game_map: GameMap, pos: Vector2) -> bool:
	return is_tile_visible(_game_map, _game_map.tiles[pos.y][pos.x])

static func is_tile_visible(_game_map: GameMap, _tile: Tile) -> bool:
	return _tile in _game_map.visible_tiles

static func recompute_fov_tiles(_game_map: GameMap, pos: Vector2, max_visibility_steps: int) -> void:
	# NOTE(rivten): current player position is always visible
	# TODO(rivten): optimization ! is this slow ?
	_game_map.visible_tiles = [_game_map.tiles[pos.y][pos.x]]
	for row in range(_game_map.height):
		for col in range(_game_map.width):
			# https://en.wikipedia.org/wiki/Digital_differential_analyzer_(graphics_algorithm) (<= the one implemented here)
			# Another possible algorithm here :
			# https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
			var is_visible = true
			var dx = col - pos.x
			var dy = row - pos.y
			var step = max(abs(dx), abs(dy))
			if step == 0:
				# NOTE(rivten): player position, we already added it
				continue
			if step > max_visibility_steps:
				continue
			dx = dx / step
			dy = dy / step
			var x = pos.x
			var y = pos.y
			var i = 1
			while i <= step:
				if is_tile_at_pos_blocking_sight(_game_map, Vector2(x, y)):
					is_visible = false
					break
				x = x + dx
				y = y + dy
				i = i + 1
			if is_visible:
				var t = _game_map.tiles[row][col]
				t.explored = true
				_game_map.visible_tiles.push_back(t)
	# NOTE(rivten): redraw the map
	_game_map.update()

func is_blocked(x: int, y: int) -> bool:
	return tiles[y][x].blocked

static func is_tile_at_pos_blocking_sight(_game_map: GameMap, pos: Vector2) -> bool:
	return _game_map.tiles[pos.y][pos.x].block_sight
