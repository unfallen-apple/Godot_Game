# player.gd
extends CharacterBody2D

# 플레이어의 기본 속도와 점프 높이 (Inspector에서 조절 가능)
@export var speed = 150.0 
@export var jump_velocity = -350.0 

# Godot 프로젝트 설정에서 기본 중력 값을 가져옴
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity") 

# 복사한 블록의 타입을 저장할 변수
var copied_block_type = "" 

# 필요한 노드들을 @onready 변수로 참조 (자동으로 노드를 찾아 연결)
@onready var default_player_rect = $ColorRect # 하얀 상자 (캐릭터 몸통)
@onready var default_border_line = $Line2D # 빨간 실선 테두리

@onready var current_body_collision_shape = $CollisionShape2D # 플레이어의 충돌 영역
@onready var ray_cast = $RayCast2D # 블록 감지용 RayCast2D

# 각 변신 블록에 해당하는 Sprite2D 노드 참조
@onready var water_sprite = $TransformationSprites/WaterSprite
@onready var cloud_sprite = $TransformationSprites/CloudSprite
@onready var stone_sprite = $TransformationSprites/StoneSprite
# 만약 다른 변신 블록이 있다면 여기에 @onready var로 추가하세요.

# 변신 전 캐릭터의 원래 상태를 저장할 딕셔너리
var original_state = {
	"speed": 0.0,
	"gravity": 0.0,
	"collision_shape_size": Vector2.ZERO 
}

func _ready():
	# 게임 시작 시 플레이어의 원래 속성들을 저장합니다.
	original_state.speed = speed
	original_state.gravity = gravity
	original_state.collision_shape_size = (current_body_collision_shape.shape as RectangleShape2D).size

	# 시작할 때 모든 변신 스프라이트를 숨깁니다.
	_hide_all_transformation_sprites()

	# 기본 하얀 상자와 빨간 테두리는 항상 보이게 합니다.
	default_player_rect.visible = true 
	default_border_line.visible = true 

	# RayCast2D 설정 확인 (Inspector에서 설정했어도 코드로 확인)
	if ray_cast: 
		ray_cast.target_position = Vector2(35, 0) # 캐릭터 오른쪽으로 35픽셀
		ray_cast.enabled = true
		# RayCast2D의 충돌 마스크 설정 (TileMap과 오브젝트 레이어와 일치하도록)
		# 프로젝트 설정 -> 레이어 이름에서 실제 레이어 번호 확인 후 설정
		# 예: ray_cast.set_collision_mask_value(2, true) # Layer 2 (월드)
		# 예: ray_cast.set_collision_mask_value(3, true) # Layer 3 (오브젝트)

func _physics_process(delta):
	# 캐릭터의 움직임과 중력 처리
	if not is_on_floor():
		velocity.y += gravity * delta 

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_direction = Input.get_axis("move_left", "move_right") 
	if input_direction:
		velocity.x = input_direction * speed 
		# 캐릭터 방향에 따라 RayCast2D의 방향을 반전 (선택 사항)
		if ray_cast: ray_cast.target_position.x = abs(ray_cast.target_position.x) * input_direction
	else:
		velocity.x = move_toward(velocity.x, 0, speed) 

	move_and_slide()

func _input(event):
	if event is InputEventAction: 
		if event.is_action_just_pressed("copy_block"): 
			copy_block()
		if event.is_action_just_pressed("paste_block"): 
			paste_block()
		if event.is_action_just_pressed("undo_paste"): 
			undo_paste()

# ====== 블록 복사 (Ctrl+C) 기능 ======
func copy_block():
	if ray_cast and ray_cast.is_colliding(): 
		var collider = ray_cast.get_collider() 

		if collider is TileMap:
			var tile_pos = collider.get_coords_for_body_rid(ray_cast.get_collision_rid())
			var tile_data = collider.get_cell_tile_data(0, tile_pos) 
			if tile_data:
				copied_block_type = tile_data.get_custom_data("block_type")
				print("복사한 블록 (TileMap): ", copied_block_type)
				return 
		elif collider.has_method("get_block_type"): 
			copied_block_type = collider.get_block_type()
			print("복사한 오브젝트: ", copied_block_type)
			return 
		else:
			copied_block_type = ""
			print("복사할 수 없는 오브젝트입니다.")
	else:
		copied_block_type = ""
		print("복사할 블록이 없습니다.")

# ====== 블록 변신 (Ctrl+V) 기능 ======
func paste_block():
	if copied_block_type.is_empty(): 
		print("복사된 블록이 없습니다. Ctrl+C를 먼저 사용하세요.")
		return

	# 기본 하얀 상자만 숨깁니다. (빨간 테두리는 계속 보이게)
	default_player_rect.visible = false 
	_hide_all_transformation_sprites() # 다른 모든 변신 스프라이트 숨기기

	# 복사한 블록의 타입에 따라 캐릭터를 변신시킵니다.
	match copied_block_type:
		"water":
			print("물 블록으로 변신!")
			water_sprite.visible = true # 물 스프라이트 보이게 함
			speed = 180.0 
			gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * 0.5 
			_update_collision_shape(Vector2(28, 28)) 

		"cloud":
			print("구름 블록으로 변신!")
			cloud_sprite.visible = true 
			speed = 220.0 
			gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * 0.1 
			_update_collision_shape(Vector2(40, 20)) 

		"stone":
			print("돌 블록으로 변신!")
			stone_sprite.visible = true 
			speed = 80.0 
			gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * 1.5 
			_update_collision_shape(Vector2(32, 32)) 

		"earth": 
			print("흙 블록으로 변신! (기본 상태와 유사)")
			# 흙으로 변신하는 것은 기본 상태로 돌아오는 것과 유사하게 처리
			_undo_transformation_to_default() 
			copied_block_type = "earth" 

		_: # 정의되지 않은 블록 타입
			print("알 수 없는 블록 타입: ", copied_block_type)
			_undo_transformation_to_default() 

# ====== 변신 되돌리기 (Ctrl+Z) 기능 ======
func undo_paste():
	print("Ctrl+Z (되돌리기)!")
	_undo_transformation_to_default()
	copied_block_type = "" # 복사 상태도 초기화

# 캐릭터를 원래 하얀 상자 모습으로 되돌리고 속성을 복원하는 헬퍼 함수
func _undo_transformation_to_default():
	# 모든 변신 스프라이트 숨기기
	_hide_all_transformation_sprites()

	# 기본 하얀 상자 외형 다시 활성화 (빨간 테두리는 계속 보였음)
	default_player_rect.visible = true

	# 물리 속성 원상 복구
	speed = original_state.speed
	gravity = original_state.gravity
	_update_collision_shape(original_state.collision_shape_size) 

# 모든 변신 스프라이트를 숨기는 헬퍼 함수
func _hide_all_transformation_sprites():
	water_sprite.visible = false
	cloud_sprite.visible = false
	stone_sprite.visible = false
	# 여기에 추가된 다른 변신 스프라이트들도 모두 visible = false 로 설정

# 충돌 영역 크기를 업데이트하는 헬퍼 함수
func _update_collision_shape(new_size: Vector2):
	if current_body_collision_shape and current_body_collision_shape.shape is RectangleShape2D:
		(current_body_collision_shape.shape as RectangleShape2D).size = new_size
		# 충돌 영역이 스프라이트의 중앙에 오도록 위치도 조절
		current_body_collision_shape.position = (new_size / 2.0) - (default_player_rect.size / 2.0) 

# ====== 다른 오브젝트와의 충돌 처리 ======
func _on_body_entered(body): 
	# 용암과의 충돌 (용암 기능은 제외했으므로 이 부분은 작동하지 않음)
	# 만약 나중에 다른 방식으로 플레이어에게 해를 끼치는 오브젝트를 추가한다면 여기에 로직을 추가

	# 열쇠 획득 처리 (열쇠 오브젝트가 Area2D를 가진다고 가정)
	if body.name == "Key":
		print("열쇠를 획득했습니다!")
		body.queue_free() # 열쇠 오브젝트를 씬에서 제거합니다.
		# 여기에 열쇠 개수를 증가시키는 로직을 추가할 수 있습니다.
		# 예: var keys_owned = 0; keys_owned += 1

# 열쇠 개수를 반환하는 함수 (나중에 문 로직에서 사용할 수 있음)
func get_key_count():
	return 0
