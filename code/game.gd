class_name Game

extends Node

enum GameState { PLAYER_TURN, ENEMY_TURN, PLAYER_DEAD, SHOW_INVENTORY, DROP_INVENTORY, TARGETING, }

# NOTE(rivten): Tileset data
export(Vector2) var character_tileset_pos = Vector2(0, 13)
export(Vector2) var dead_character_tileset_pos = Vector2(5, 13)
export(Vector2) var npc_tileset_pos = Vector2(4, 13)
export(Vector2) var troll_tileset_pos = Vector2(5, 13)
export(Vector2) var potion_tileset_pos = Vector2(4, 16)
export(Vector2) var scroll_tileset_pos = Vector2(8, 17)
export(int) var tile_size_in_pixels = 16

# NOTE(rivten): Entity generation data
export(int) var max_monsters_per_room = 5
export(int) var max_items_per_room = 2

# NOTE(rivten): UI data
export(int) var max_log_text_count = 4
export(int) var max_hover_name_count = 3
export(Vector2) var hover_margin_name = Vector2(5, 5)
export(Vector2) var hover_rect_mouse_offset = Vector2(10, 10)

# TODO(rivten): @architecture. 
# On the one hand, it is nice to have an entity not know about the absolute screen position or the sprite it bears.
# On the other hand, it would be nice to have an entity be a node so that it could be treated same as other nodes...

# TODO(rivten): color palette

# TODO(rivten): make sure render order is correct (from the tutorial: first actors, then item, then corpses)

# TODO(rivten): find out a better way to handle the long node path. Or maybe it's good if I don't want a script in every node.
# What do we want ?

var player: Entity
var game_state: int
var prev_game_state: int

var entities: Array
# TODO(rivten): so this is a hack for now.
# Because of cyclic dependencies, I cannot store directly the Entity reference into the list
# of items in the inventory of an Entity... But since Entities are References (maybe I could change that ?)
# when they go in the inventory, I delete them from the entities array (I store the weak ref in the inventory)
# and so the Entity is deleted.
# So I just decided to have another array of entities that are not in the map, but in some inventory
# so that they are not destroyed.
# Another possibility could be to make an Entity be simply an object, but then I would have
# to manage its memory myself
# A third possibility could be to not say in the Inventory script that it is a list of array
# Therefore, Godot would not know that it's entities and would not load the entity script.
var entities_in_inventory: Array
var entities_to_sprite: Dictionary

var tilemap = preload("res://data/bitmaps/roguelike_tileset.png")

# NOTE(rivten): Current item when chosing a target when game_state is TARGETING
var targeting_item_index: int

# NOTE(rivten): only called when the children are ready...
func _ready() -> void:
	game_state = GameState.PLAYER_TURN
	entities = []
	entities_to_sprite = {}

	player = add_entity("player", character_tileset_pos, Vector2(0, 0), false, Color.white)
	player.fighter = FighterState.new()
	player.fighter.max_hp = 30
	player.fighter.hp = 30
	player.fighter.defense = 2
	player.fighter.power = 5
	player.fighter.get_owner = funcref(player, "get_self")

	player.inventory = Inventory.new()
	player.inventory.capacity = 26

	$viewport_container/viewport/map.tile_size_in_pixels = tile_size_in_pixels
	GameMap.gen_map($viewport_container/viewport/map)

	# TODO(rivten): either we place all entities after the map is generated
	# this requires to store all the rooms for the map
	# OR
	# each time the map generates a room : the map emits a signal "room_created"

	var first_room = $viewport_container/viewport/map.rooms[0]
	var player_start_pos_x = int(first_room.position.x + 0.5 * first_room.size.x)
	var player_start_pos_y = int(first_room.position.y + 0.5 * first_room.size.y)
	player.pos = Vector2(player_start_pos_x, player_start_pos_y)
	get_sprite_from_entity(player, entities_to_sprite).position = get_position_from_game_map_pos(player.pos, tile_size_in_pixels)
	$viewport_container/viewport/camera.position = tile_size_in_pixels * player.pos

	place_entities($viewport_container/viewport/map.rooms.slice(1, $viewport_container/viewport/map.rooms.size() - 1))

	update_fov()
	update_entities_sprite_visibility()
	update_hp_label()

	for _i in range(max_hover_name_count):
		var name_label = Label.new()
		name_label.visible = false
		$hover_names.add_child(name_label)

func get_action_key(scancode: int) -> Dictionary:
	if game_state == GameState.PLAYER_TURN:
		return get_action_player_turn(scancode)
	elif game_state == GameState.PLAYER_DEAD:
		return get_action_player_dead(scancode)
	elif game_state == GameState.SHOW_INVENTORY or game_state == GameState.DROP_INVENTORY:
		return get_action_inventory(scancode)
	elif game_state == GameState.TARGETING:
		return get_action_targeting(scancode)

	return {}

func get_action_mouse(button: int) -> Dictionary:
	var map_pos = get_mouse_in_map_space()
	if button == BUTTON_LEFT:
		return {'left_click': map_pos}
	elif button == BUTTON_RIGHT:
		return {'right_click': map_pos}
	return {}

func _input(event: InputEvent) -> void:
	var action = {}
	if event is InputEventKey and event.pressed:
		action = get_action_key(event.scancode)
	if event is InputEventMouseButton and event.pressed:
		action = get_action_mouse(event.button_mask)

	if event is InputEventMouseMotion:
		update_mouse_hover_ui()

	if not action.empty():
		process_action(action)


func get_mouse_in_map_space() -> Vector2:
	var mouse_pos = $viewport_container/viewport.get_mouse_position()
	var map_pos = (1.0 / tile_size_in_pixels) * $viewport_container/viewport.get_canvas_transform().xform_inv(mouse_pos)
	var tile_x = int(map_pos.x)
	var tile_y = int(map_pos.y)
	return Vector2(tile_x, tile_y)

func update_mouse_hover_ui() -> void:
	var map_pos = get_mouse_in_map_space()
	var tile_x = map_pos.x
	var tile_y = map_pos.y

	# TODO(rivten): At first this was only done in the _input function
	# But there was issues with switching hover between two
	# Connected entities with different name size. It seemed that
	# the hover names rect_size was not reacting directly (this
	# seems to be fixed with the two lines below), and the label
	# rect size also do not change properly directly.
	# Not sure why...
	$hover_names.rect_size = Vector2(0, 0)
	$hover_names.rect_min_size = Vector2(0, 0)

	var names_under_cursor = get_names_on_tile(tile_x, tile_y)
	if names_under_cursor.size() == 0:
		$hover_names_background.visible = false
		$hover_names.visible = false
	else:
		$hover_names_background.visible = true
		$hover_names.visible = true

		assert(names_under_cursor.size() <= max_hover_name_count)
		var label_index = 0
		for label in $hover_names.get_children():
			if label_index < names_under_cursor.size():
				label.rect_size = Vector2(0, 0)
				label.rect_min_size = Vector2(0, 0)
				label.text = names_under_cursor[label_index]
				label.visible = true
			else:
				label.rect_size = Vector2(0, 0)
				label.rect_min_size = Vector2(0, 0)
				label.text = ""
				label.visible = false
			label_index += 1

	# TODO(rivten): recomputing the mouse pos... meh...
	var mouse_pos = $viewport_container/viewport.get_mouse_position()
	$hover_names_background.rect_position = mouse_pos + hover_rect_mouse_offset
	$hover_names.rect_position = mouse_pos + hover_rect_mouse_offset + hover_margin_name
	$hover_names_background.rect_size = $hover_names.rect_size + 2.0 * hover_margin_name


func get_names_on_tile(_x: int, _y: int) -> Array:
	var names = []
	for entity in entities:
		if (entity.pos.x == _x) and (entity.pos.y == _y) and (GameMap.is_position_visible($viewport_container/viewport/map, Vector2(_x, _y))):
			names.push_back(entity.name)
	return names

static func get_action_player_turn(scancode: int) -> Dictionary:
	if scancode == KEY_LEFT or scancode == KEY_H or scancode == KEY_KP_4:
		return {'move': Vector2(-1, 0)}

	if scancode == KEY_RIGHT or scancode == KEY_L or scancode == KEY_KP_6:
		return {'move': Vector2(1, 0)}

	if scancode == KEY_UP or scancode == KEY_K or scancode == KEY_KP_8:
		return {'move': Vector2(0, -1)}

	if scancode == KEY_DOWN or scancode == KEY_J or scancode == KEY_KP_2:
		return {'move': Vector2(0, 1)}

	if scancode == KEY_U or scancode == KEY_KP_9:
		return {'move': Vector2(1, -1)}

	if scancode == KEY_Y or scancode == KEY_KP_7:
		return {'move': Vector2(-1, -1)}

	if scancode == KEY_B or scancode == KEY_KP_1:
		return {'move': Vector2(-1, 1)}

	if scancode == KEY_N or scancode == KEY_KP_3:
		return {'move': Vector2(1, 1)}

	if scancode == KEY_G:
		return {'pickup': true}

	if scancode == KEY_I:
		return {'show_inventory': true}

	if scancode == KEY_D:
		return {'drop_inventory': true}

	if scancode == KEY_ESCAPE:
		return {'exit': true}

	return {}

static func get_action_player_dead(scancode: int) -> Dictionary:
	if scancode == KEY_I:
		return {'show_inventory': true}

	if scancode == KEY_ESCAPE:
		return {'exit': true}

	return {}

static func get_action_inventory(scancode: int) -> Dictionary:
	if scancode == KEY_ESCAPE:
		return {'exit': true}

	if scancode >= KEY_A and scancode <= KEY_Z:
		var item_index = scancode - KEY_A
		return {'use_inventory_index': item_index}

	return {}

static func get_action_targeting(scancode: int) -> Dictionary:
	if scancode == KEY_ESCAPE:
		return {'exit': true}
	return {}

func process_action(_action: Dictionary) -> void:

	# TODO(rivten): right now at each input that does something,
	# we do the player turn and then immediatly the monster's turn
	# but in a kind of convoluted way. We could just simply put all the
	# monster's code instead of setting some enum, but maybe in the future we
	# could launch a thread or something ?
	# Or maybe just make this code simpler.
	var commands = []
	if _action.has('move') and game_state == GameState.PLAYER_TURN:
		var dx = _action.move.x
		var dy = _action.move.y
		# NOTE(rivten): assert ? can we have (0, 0) ?
		if dx != 0 or dy != 0:
			var dest_x = player.pos.x + dx
			var dest_y = player.pos.y + dy
			if not $viewport_container/viewport/map.is_blocked(dest_x, dest_y):
				var target = get_blocking_entity_at_location(entities, dest_x, dest_y)
				if target:
					commands += FighterState.attack(player.fighter, target.fighter)
				else:
					Entity.move(player, dx, dy)
					$viewport_container/viewport/camera.position = tile_size_in_pixels * player.pos
				update_fov()
				game_state = GameState.ENEMY_TURN

	if _action.has('pickup') and game_state == GameState.PLAYER_TURN:
		var entity_found = null
		for entity in entities:
			if entity.item and entity.pos.x == player.pos.x and entity.pos.y == player.pos.y:
				entity_found = entity
				break

		if entity_found:
			commands += Inventory.add_item(player.inventory, weakref(entity_found))
		else:
			var msg = LogMessage.new()
			msg.text = "There is nothing here to pickup"
			msg.color = Color.yellow
			push_log_message(msg)

	if _action.has('show_inventory') and _action.show_inventory:
		prev_game_state = game_state
		game_state = GameState.SHOW_INVENTORY
		update_inventory_ui()
		$inventory_container.visible = true

	if _action.has('drop_inventory') and _action.drop_inventory:
		prev_game_state = game_state
		game_state = GameState.DROP_INVENTORY
		update_inventory_ui()
		$inventory_container.visible = true

	if _action.has('use_inventory_index') and prev_game_state != GameState.PLAYER_DEAD:
		if _action.use_inventory_index < player.inventory.items.size():
			if game_state == GameState.SHOW_INVENTORY:
				# TODO(rivten): ABSOLUTELY NOT fan of passing everything every time !!
				# (but maybe it's not that costly performance-wise. It's just bad
				# architecturally-wise)
				commands += Inventory.use_item(player.inventory, _action.use_inventory_index,
						{
							'entity': player,
							'caster': player,
							'entities': entities,
							'map': $viewport_container/viewport/map
						})
			elif game_state == GameState.DROP_INVENTORY:
				commands += Inventory.drop_item(player.inventory, _action.use_inventory_index, player.pos)

	if game_state == GameState.TARGETING:
		if _action.has('left_click'):
			commands += Inventory.use_item(player.inventory, targeting_item_index,
					{
						'target_pos': _action.left_click,
						'entities': entities,
						'map': $viewport_container/viewport/map
					})
		elif _action.has('right_click'):
			commands.push_back({'targeting_cancelled': true})

	if _action.has('exit'):
		if game_state == GameState.SHOW_INVENTORY or game_state == GameState.DROP_INVENTORY:
			$inventory_container.visible = false
			game_state = prev_game_state
		elif game_state == GameState.TARGETING:
			commands.push_back({'targeting_cancelled': true})
		else:
			get_tree().quit()

	# NOTE(rivten): dealing with the received commands for the turn
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
			push_log_message(message)

		if command.has('item_added'):
			var item = command.item_added.get_ref()
			entities_in_inventory.push_back(item)
			entities.erase(item)
			get_sprite_from_entity(item, entities_to_sprite).visible = false
			game_state = GameState.ENEMY_TURN

		if command.has("message"):
			push_log_message(command.message)

		if command.has("consumed") and command.consumed:
			# NOTE(rivte): Two possibilities:
			# Either we allow several item consumption during a turn => we need to update the UI
			# Either we don't => we say it's enemy turn and hid the inventory

			#update_inventory_ui()

			game_state = GameState.ENEMY_TURN
			$inventory_container.visible = false

		if command.has("item_dropped"):
			var item_entity = command.item_dropped
			entities.push_back(item_entity)
			entities_in_inventory.erase(item_entity)
			game_state = GameState.ENEMY_TURN
			$inventory_container.visible = false

		if command.has("targeting_item"):
			prev_game_state = GameState.PLAYER_TURN # TODO(rivten): this is a hack since we don't _really_ set the _real_ prev game state here
			game_state = GameState.TARGETING
			$inventory_container.visible = false

			var targeting_item = command.targeting_item
			targeting_item_index = command.targeting_item_index
			push_log_message(targeting_item.item.targeting_message)

		if command.has("targeting_cancelled"):
			assert(game_state == GameState.TARGETING)
			game_state = prev_game_state
			var msg = LogMessage.new()
			msg.text = "Targeting canceled"
			msg.color = Color.white
			push_log_message(msg)

	if game_state == GameState.ENEMY_TURN:
		for entity in entities:
			if entity != player:
				if entity.take_turn:
					var enemy_commands = entity.take_turn.call_func(entity, player, $viewport_container/viewport/map, funcref(self, "is_position_free"), entity.ai_state)

					for command in enemy_commands:
						if command.has("dead_entity"):
							var dead_entity = command.dead_entity
							var message = ""
							if dead_entity == player:
								var player_killed_data = kill_player(dead_entity)
								message = player_killed_data.message
								game_state = player_killed_data.game_state
							else:
								message = kill_monster(dead_entity)
							push_log_message(message)

							if game_state == GameState.PLAYER_DEAD:
								break

						if command.has("message"):
							push_log_message(command.message)

			if game_state == GameState.PLAYER_DEAD:
				break

		if game_state == GameState.ENEMY_TURN:
			game_state = GameState.PLAYER_TURN

	update_entities_sprite_visibility()

	update_hp_label()

	# TODO(rivten): this does not work properly
	# Maybe because the canvas_transform of the viewport/camera
	# does not update instantly and therefore I need to update the hover
	# only after the correct redraw has happened ?
	# Several solutions to this :
	# 1. I just do this stuff in _process, each frame. That gets the jobs done but consumes CPU
	# 2. I split the camera into a discrete camera (that knows about the map discrete
	#		positioning only, and that discrete camera controls the rendering camera
	#		just like we do for the entities and their sprite).
	# 3. I understand properly what is going on...
	update_mouse_hover_ui()

static func tileset_pos_to_sprite_rect(_tileset_pos: Vector2, _tile_size_in_pixels: int) -> Rect2:
	return Rect2(_tile_size_in_pixels * _tileset_pos, Vector2(_tile_size_in_pixels, _tile_size_in_pixels))

func add_entity(_name: String, _tileset_pos: Vector2, _pos: Vector2, _blocks: bool, _color: Color) -> Entity:
	var entity = Entity.new()
	entity.blocks = _blocks
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
	entity_sprite.modulate = _color

	$viewport_container/viewport.add_child(entity_sprite)
	entities_to_sprite[entity.to_string()] = entity_sprite

	return entity


func update_entities_sprite_visibility() -> void:
	for entity in entities:
		get_sprite_from_entity(entity, entities_to_sprite).visible = GameMap.is_position_visible($viewport_container/viewport/map, entity.pos)

func update_fov() -> void:
	GameMap.recompute_fov_tiles($viewport_container/viewport/map, player.pos, 8)

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
					var thieve = add_entity("thieve", npc_tileset_pos, Vector2(x, y), true, Color.green)
					thieve.fighter = FighterState.new()
					thieve.fighter.max_hp = 30
					thieve.fighter.hp = 2
					thieve.fighter.defense = 3
					thieve.fighter.power = 3
					thieve.fighter.get_owner = funcref(thieve, "get_self")
					thieve.take_turn = funcref(Ai, "basic_monster_take_turn")
				else:
					var orc = add_entity("orc", troll_tileset_pos, Vector2(x, y), true, Color.magenta)
					orc.fighter = FighterState.new()
					orc.fighter.max_hp = 10
					orc.fighter.hp = 10
					orc.fighter.defense = 1
					orc.fighter.power = 7
					orc.fighter.get_owner = funcref(orc, "get_self")
					orc.take_turn = funcref(Ai, "basic_monster_take_turn")

		var item_count = randi() % (max_items_per_room + 1)
		for _i in range(item_count):
			var x = (randi() % int(room.size.x)) + room.position.x
			var y = (randi() % int(room.size.y)) + room.position.y
			var can_spawn_here = true
			for entity in entities:
				if entity.pos.x == x and entity.pos.y == y:
					can_spawn_here = false
					break
			if can_spawn_here:
				var spawn_rand = (randi() % 100)
				if  spawn_rand < 70:
					var potion = add_entity("healing potion", potion_tileset_pos, Vector2(x, y), false, Color.purple)
					potion.item = Item.new()
					potion.item.use_function = funcref(ItemFunctions, "heal")
					potion.item.params.amount = 4
				elif spawn_rand < 85:
					var scroll = add_entity("lightning scroll", scroll_tileset_pos, Vector2(x, y), false, Color.black)
					scroll.item = Item.new()
					scroll.item.use_function = funcref(ItemFunctions, "cast_lightning")
					scroll.item.params.damage = 8
					scroll.item.params.max_range = 6
				elif spawn_rand < 90:
					var scroll = add_entity("fireball scroll", scroll_tileset_pos, Vector2(x, y), false, Color.red)
					scroll.item = Item.new()
					scroll.item.use_function = funcref(ItemFunctions, "cast_fireball")
					scroll.item.params.damage = 20
					scroll.item.params.radius = 3
					scroll.item.targeting = true
					scroll.item.targeting_message = LogMessage.new()
					scroll.item.targeting_message.text = "Click to target the fireball"
					scroll.item.targeting_message.color = Color.cyan
				else:
					var scroll = add_entity("confusion scroll", scroll_tileset_pos, Vector2(x, y), false, Color.pink)
					scroll.item = Item.new()
					scroll.item.use_function = funcref(ItemFunctions, "cast_confuse")
					scroll.item.targeting = true
					scroll.item.targeting_message = LogMessage.new()
					scroll.item.targeting_message.text = "Click to target the confusion spell"
					scroll.item.targeting_message.color = Color.cyan


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
	return (not $viewport_container/viewport/map.is_blocked(_x, _y)) and (not get_blocking_entity_at_location(entities, _x, _y))

static func get_sprite_from_entity(_entity: Entity, _entities_to_sprite: Dictionary) -> Sprite:
	return _entities_to_sprite[_entity.to_string()]

# TODO(rivten): do we really need a function for this ?? can't this be done inline ?
func kill_player(_player: Entity) -> Dictionary:
	var sprite = get_sprite_from_entity(_player, entities_to_sprite)
	sprite.region_rect = tileset_pos_to_sprite_rect(dead_character_tileset_pos, tile_size_in_pixels)
	sprite.modulate = Color.red

	var player_killed_data = {}
	var msg = LogMessage.new()
	msg.color = Color.red
	msg.text = "You died!"

	player_killed_data.message = msg
	player_killed_data.game_state = GameState.PLAYER_DEAD

	return player_killed_data

func kill_monster(_entity: Entity) -> LogMessage:
	var msg = LogMessage.new()
	msg.text = _entity.name + " is dead!"
	msg.color = Color.orange

	# TODO(rivten): change stuff about the enemy here
	get_sprite_from_entity(_entity, entities_to_sprite).modulate = Color.red
	_entity.blocks = false
	_entity.name = "remains of " + _entity.name
	_entity.take_turn = null
	_entity.fighter = null

	return msg

func update_hp_label() -> void:
	$text_background/vbox/health_label.text = "HP: " + str(player.fighter.hp) + "/" + str(player.fighter.max_hp)

func push_log_message(msg: LogMessage) -> void:
	var label = null
	if $text_background/vbox/message_log.get_child_count() >= max_log_text_count:
		var to_reuse_label = $text_background/vbox/message_log.get_child(0)
		$text_background/vbox/message_log.remove_child(to_reuse_label)
		label = to_reuse_label
	else:
		label = Label.new()

	label.text = msg.text
	label.modulate = msg.color
	$text_background/vbox/message_log.add_child(label)

func update_inventory_ui() -> void:
	for label in $inventory_container/background/items.get_children():
		label.visible = false
	var item_index = 0
	for item_weak_ref in player.inventory.items:
		var item_label = null

		if item_index < $inventory_container/background/items.get_child_count():
			item_label = $inventory_container/background/items.get_child(item_index)
		else:
			item_label = Label.new()
			$inventory_container/background/items.add_child(item_label)

		item_label.visible = true
		item_label.text = char(item_index + ord('a')) + " - " + item_weak_ref.get_ref().name
		item_index += 1

