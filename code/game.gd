class_name Game

extends Node

enum GameState { PLAYER_TURN, ENEMY_TURN, PLAYER_DEAD, }

export(Vector2) var character_tileset_pos = Vector2(0, 13)
export(Vector2) var dead_character_tileset_pos = Vector2(5, 13)
export(Vector2) var npc_tileset_pos = Vector2(4, 13)
export(Vector2) var troll_tileset_pos = Vector2(5, 13)
export(int) var tile_size_in_pixels = 16
export(int) var max_monsters_per_room = 5

# TODO(rivten): @architecture. 
# On the one hand, it is nice to have an entity not know about the absolute screen position or the sprite it bears.
# On the other hand, it would be nice to have an entity be a node so that it could be treated same as other nodes...

# TODO(rivten): color palette

# TODO(rivten): make sure render order is correct (from the tutorial: first actors, then item, then corpses)

# TODO(rivten)

var player: Entity
var game_state: int

var entities: Array
var entities_to_sprite: Dictionary

var tilemap = preload("res://data/bitmaps/roguelike_tileset.png")

# NOTE(rivten): only called when the children are ready...
func _ready() -> void:
	game_state = GameState.PLAYER_TURN
	entities = []
	entities_to_sprite = {}

	player = add_entity("player", character_tileset_pos, Vector2(0, 0))
	player.fighter = FighterState.new()
	player.fighter.max_hp = 30
	player.fighter.hp = 30
	player.fighter.defense = 2
	player.fighter.power = 5
	player.fighter.get_owner = funcref(player, "get_self")

	$map.tile_size_in_pixels = tile_size_in_pixels
	GameMap.gen_map($map)

	# TODO(rivten): either we place all entities after the map is generated
	# this requires to store all the rooms for the map
	# OR
	# each time the map generates a room : the map emits a signal "room_created"

	var first_room = $map.rooms[0]
	var player_start_pos_x = int(first_room.position.x + 0.5 * first_room.size.x)
	var player_start_pos_y = int(first_room.position.y + 0.5 * first_room.size.y)
	player.pos = Vector2(player_start_pos_x, player_start_pos_y)
	get_sprite_from_entity(player, entities_to_sprite).position = get_position_from_game_map_pos(player.pos, tile_size_in_pixels)

	place_entities($map.rooms.slice(1, $map.rooms.size() - 1))

	update_fov()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var dx: int = 0
		var dy: int = 0
		if event.scancode == KEY_LEFT or event.scancode == KEY_H or event.scancode == KEY_KP_4:
			dx = -1
		if event.scancode == KEY_RIGHT or event.scancode == KEY_L or event.scancode == KEY_KP_6:
			dx = 1
		if event.scancode == KEY_UP or event.scancode == KEY_K or event.scancode == KEY_KP_8:
			dy = -1
		if event.scancode == KEY_DOWN or event.scancode == KEY_J or event.scancode == KEY_KP_2:
			dy = 1
		if event.scancode == KEY_U or event.scancode == KEY_KP_9:
			dx = 1
			dy = -1
		if event.scancode == KEY_Y or event.scancode == KEY_KP_7:
			dx = -1
			dy = -1
		if event.scancode == KEY_B or event.scancode == KEY_KP_1:
			dx = -1
			dy = 1
		if event.scancode == KEY_N or event.scancode == KEY_KP_3:
			dx = 1
			dy = 1

		# TODO(rivten): right now at each input that does something,
		# we do the player turn and then immediatly the monster's turn
		# but in a kind of convoluted way. We could just simply put all the
		# monster's code instead of setting some enum, but maybe in the future we
		# could launch a thread or something ?
		# Or maybe just make this code simpler.
		if game_state == GameState.PLAYER_TURN:
			var commands = []
			if dx != 0 or dy != 0:
				var dest_x = player.pos.x + dx
				var dest_y = player.pos.y + dy
				if not $map.is_blocked(dest_x, dest_y):
					var target = get_blocking_entity_at_location(entities, dest_x, dest_y)
					if target:
						commands = commands + FighterState.attack(player.fighter, target.fighter)
					else:
						Entity.move(player, dx, dy)
						update_fov()
					game_state = GameState.ENEMY_TURN

			for command in commands:
				if command.has("dead_entity"):
					var dead_entity = command.dead_entity
					var message = ""
					if dead_entity == player:
						var player_killed_data = kill_player(dead_entity)
						game_state = player_killed_data.game_state
						message = player_killed_data.message
					else:
						message = kill_monster(dead_entity)
					print(message)

				if command.has("message"):
					print(command.message)

		if game_state == GameState.ENEMY_TURN:
			for entity in entities:
				if entity != player:
					if entity.take_turn:
						var commands = entity.take_turn.call_func(entity, player, $map, funcref(self, "is_position_free"))

						for command in commands:
							if command.has("dead_entity"):
								var dead_entity = command.dead_entity
								var message = ""
								if dead_entity == player:
									var player_killed_data = kill_player(dead_entity)
									message = player_killed_data.message
									game_state = player_killed_data.game_state
								else:
									message = kill_monster(dead_entity)
								print(message)

								if game_state == GameState.PLAYER_DEAD:
									break

							if command.has("message"):
								print(command.message)

				if game_state == GameState.PLAYER_DEAD:
					break

			if game_state == GameState.ENEMY_TURN:
				game_state = GameState.PLAYER_TURN

static func tileset_pos_to_sprite_rect(_tileset_pos: Vector2, _tile_size_in_pixels: int) -> Rect2:
	return Rect2(_tile_size_in_pixels * _tileset_pos, Vector2(_tile_size_in_pixels, _tile_size_in_pixels))

func add_entity(_name: String, _tileset_pos: Vector2, _pos: Vector2) -> Entity:
	var entity = Entity.new()
	entity.blocks = true
	entity.name = _name
	entity.pos = _pos
	entities.push_back(entity)

	entity.connect("moved", self, "update_entity_sprite")

	var entity_sprite = Sprite.new()
	entity_sprite.texture = tilemap
	entity_sprite.region_enabled = true
	entity_sprite.region_rect = tileset_pos_to_sprite_rect(_tileset_pos, tile_size_in_pixels)
	entity_sprite.position = get_position_from_game_map_pos(entity.pos, tile_size_in_pixels)
	entity_sprite.centered = false

	add_child(entity_sprite)
	entities_to_sprite[entity.to_string()] = entity_sprite

	return entity

func update_fov() -> void:
	GameMap.recompute_fov_tiles($map, player.pos, 8)

	# NOTE(rivten): Change enemy visibility
	# TODO(rivten): this iterate over the player too (even if the player should always be in the visible tiles...)
	for entity in entities:
		get_sprite_from_entity(entity, entities_to_sprite).visible = GameMap.is_position_visible($map, entity.pos)

func place_entities(rooms: Array) -> void:
	for room in rooms:
		var monster_count = randi() % (max_monsters_per_room + 1)
		for _i in range(monster_count):
			var x = (randi() % int(room.size.x)) + room.position.x
			var y = (randi() % int(room.size.y)) + room.position.y
			var can_spawn_here = true
			for entity in entities:
				if entity.pos.x == x and entity.pos.y == y:
					can_spawn_here = false
					break
			if can_spawn_here:
				if (randi() % 100) < 80:
					var thieve = add_entity("thieve", npc_tileset_pos, Vector2(x, y))
					thieve.fighter = FighterState.new()
					thieve.fighter.max_hp = 30
					thieve.fighter.hp = 2
					thieve.fighter.defense = 3
					thieve.fighter.power = 10
					thieve.fighter.get_owner = funcref(thieve, "get_self")
					thieve.take_turn = funcref(Ai, "basic_monster_take_turn")
				else:
					var orc = add_entity("orc", troll_tileset_pos, Vector2(x, y))
					orc.fighter = FighterState.new()
					orc.fighter.max_hp = 30
					orc.fighter.hp = 10
					orc.fighter.defense = 7
					orc.fighter.power = 10
					orc.fighter.get_owner = funcref(orc, "get_self")
					orc.take_turn = funcref(Ai, "basic_monster_take_turn")

static func get_blocking_entity_at_location(_entities: Array, _dest_x: int, _dest_y: int) -> Entity:
	# TODO(rivten): @optim
	for entity in _entities:
		if (entity.blocks) and (entity.pos.x == _dest_x) and (entity.pos.y == _dest_y):
			return entity
	return null

static func get_position_from_game_map_pos(_map_pos: Vector2, _tile_size_in_pixels: int) -> Vector2:
	return _tile_size_in_pixels * _map_pos

func update_entity_sprite(_entity: Entity) -> void:
	get_sprite_from_entity(_entity, entities_to_sprite).position = get_position_from_game_map_pos(_entity.pos, tile_size_in_pixels)


func is_position_free(_x: int, _y: int) -> bool:
	return (not $map.is_blocked(_x, _y)) and (not get_blocking_entity_at_location(entities, _x, _y))

static func get_sprite_from_entity(_entity: Entity, _entities_to_sprite: Dictionary) -> Sprite:
	return _entities_to_sprite[_entity.to_string()]

# TODO(rivten): do we really need a function for this ?? can't this be done inline ?
func kill_player(_player: Entity) -> Dictionary:
	var sprite = get_sprite_from_entity(_player, entities_to_sprite)
	sprite.region_rect = tileset_pos_to_sprite_rect(dead_character_tileset_pos, tile_size_in_pixels)
	sprite.modulate = Color.red

	var player_killed_data = {}
	player_killed_data.message = "You died!"
	player_killed_data.game_state = GameState.PLAYER_DEAD

	return player_killed_data

func kill_monster(_entity: Entity) -> String:
	var death_message = _entity.name + " is dead!"

	# TODO(rivten): change stuff about the enemy here
	get_sprite_from_entity(_entity, entities_to_sprite).modulate = Color.red
	_entity.blocks = false
	_entity.name = "remains of " + _entity.name
	_entity.take_turn = null
	_entity.fighter = null

	return death_message

