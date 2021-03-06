class_name FighterState
# TODO(rivten): find a better name than that...

extends Reference

var max_hp: int
var hp: int
var power: int
var defense: int

var get_owner: FuncRef

static func take_damage(_target: FighterState, _dmg_amount: int) -> Array:
	# TODO(rivten): I'm not fan of the tutorial logic
	# but I'm rolling with it for now. Maybe we could have some GameCommand class
	# or something
	var commands = []

	_target.hp -= _dmg_amount

	if _target.hp < 0:
		commands.push_back({'dead_entity': _target.get_owner.call_func()})

	return commands

static func attack(_attacker: FighterState, _target: FighterState) -> Array:
	var commands = []

	var damage = _attacker.power - _target.defense
	if damage > 0:
		var msg = LogMessage.new()
		msg.text = _attacker.get_owner.call_func().name + ' attacks ' + _target.get_owner.call_func().name +  ' for ' +  str(damage) + ' hit point(s)'
		msg.color = Color.white

		commands.push_back({'message': msg})
		commands = commands + take_damage(_target, damage)
	else:
		var msg = LogMessage.new()
		msg.text = _attacker.get_owner.call_func().name + ' attacks ' + _target.get_owner.call_func().name + ' but does no damage.'
		msg.color = Color.white
		commands.push_back({'message': msg})
	return commands

static func heal(_fighter: FighterState, _amount: int) -> void:
	_fighter.hp += _amount
	if _fighter.hp > _fighter.max_hp:
		_fighter.hp = _fighter.max_hp
