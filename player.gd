extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBarCanvas/HealthBar

const SPEED = 250.0
const JUMP_VELOCITY = -400.0

const PRAY_DURATION := 1.0
const HURT_DURATION := 0.4
const MAX_HEALTH := 100
const PRAY_HEAL := 25

const ATTACK_DURATIONS := [0.6, 0.6, 0.6, 0.3]
const COMBO_GRACE := 0.25

enum PlayerState {
	IDLE,
	MOVE,
	ATTACK,
	PRAY,
	HURT,
	DEAD
}

var state := PlayerState.IDLE

var health := MAX_HEALTH
var _action_end_time := 0.0
var _attack_combo := 0
var _hurt_end_time := 0.0
var _is_dead := false


func _ready() -> void:
	health_bar.max_value = MAX_HEALTH
	health_bar.value = health


# -----------------------------
# DAMAGE SYSTEM
# -----------------------------
func take_damage(amount: int) -> void:
	if _is_dead:
		return

	health = max(0, health - amount)
	health_bar.value = health

	if health <= 0:
		_die()
	else:
		state = PlayerState.HURT
		_hurt_end_time = Time.get_ticks_msec() / 1000.0 + HURT_DURATION
		animated_sprite.play("hurt")


func _die() -> void:
	_is_dead = true
	state = PlayerState.DEAD
	animated_sprite.play("death")
	set_physics_process(false)


# -----------------------------
# MAIN LOOP
# -----------------------------
func _physics_process(delta):

	if _is_dead:
		return

	var t = Time.get_ticks_msec() / 1000.0

	_apply_gravity(delta)

	# HURT STATE
	if state == PlayerState.HURT:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()

		if t >= _hurt_end_time:
			state = PlayerState.IDLE

		return


	# ACTION LOCK (attack / pray)
	if t < _action_end_time:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return


	# Reset combo if too slow
	if _attack_combo > 0 and t >= _action_end_time + COMBO_GRACE:
		_attack_combo = 0


	_handle_actions(t)
	_handle_movement(delta)


# -----------------------------
# ACTIONS
# -----------------------------
func _handle_actions(t):

	# ATTACK
	if Input.is_action_just_pressed("Attack"):

		var can_chain = _attack_combo > 0 and t < _action_end_time + COMBO_GRACE
		var can_start = _action_end_time <= t

		if can_start or can_chain:

			state = PlayerState.ATTACK

			_attack_combo = (_attack_combo % 4) + 1

			var anim = "attack_" + str(_attack_combo)
			animated_sprite.play(anim)

			_action_end_time = t + ATTACK_DURATIONS[_attack_combo - 1]
			return


	# PRAY
	if Input.is_action_just_pressed("Pray"):

		state = PlayerState.PRAY
		_attack_combo = 0

		animated_sprite.play("pray")

		health = min(MAX_HEALTH, health + PRAY_HEAL)
		health_bar.value = health

		_action_end_time = t + PRAY_DURATION
		return


# -----------------------------
# MOVEMENT
# -----------------------------
func _handle_movement(delta):

	if is_on_floor():

		if Input.is_action_just_pressed("Jump") \
		or Input.is_action_just_pressed("Up") \
		or Input.is_action_just_pressed("ui_accept"):

			velocity.y = JUMP_VELOCITY


	var direction = Input.get_axis("Left", "Right")

	if direction == 0:
		direction = Input.get_axis("ui_left", "ui_right")


	if direction:

		velocity.x = direction * SPEED
		state = PlayerState.MOVE

	else:

		velocity.x = move_toward(velocity.x, 0, SPEED)
		state = PlayerState.IDLE


	move_and_slide()
	_update_animation(direction)


# -----------------------------
# GRAVITY
# -----------------------------
func _apply_gravity(delta):

	if not is_on_floor():
		velocity += get_gravity() * delta


# -----------------------------
# ANIMATION
# -----------------------------
func _update_animation(direction):

	# Do not override action animations
	if state in [PlayerState.ATTACK, PlayerState.PRAY, PlayerState.HURT, PlayerState.DEAD]:
		return

	if direction != 0:
		animated_sprite.flip_h = direction < 0

	if not is_on_floor():
		animated_sprite.play("jump")

	elif abs(velocity.x) > 1.0:
		animated_sprite.play("run")

	else:
		animated_sprite.play("idle")
