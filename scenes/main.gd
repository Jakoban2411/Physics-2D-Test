extends Node2D

@export var num_cubes : int = 500 # (int,25,75000)
@export var side_length : int = 5 # (int,1,100)
@export var impulse : int = 250 # (int,1,1000)

@onready var cube_mm : PackedScene = preload("res://scenes/cube_mm.tscn")
@onready var marble : PackedScene = preload("res://scenes/marble.tscn")
@onready var fpsLabel : Label = $CanvasLayer/ReferenceRect/FPSLabel
@onready var sleepLabel : Label = $CanvasLayer/ReferenceRect/SleepLabel
@onready var cubeContainer : Node2D = $CubeContainer
@onready var mm : MultiMesh = $MultiMeshInstance2D.get_multimesh()
var instanced_marble

var timer : float = 0.0
var marble_launched : bool = false
var camera_anglev : int = -15
@export var TIMER_LIMIT := 0.1	# fps gui refresh rate in seconds # (float,0.01,1.0)
const mouse_sens : float  = 0.2

@onready var fps : int = int(Performance.get_monitor(Performance.TIME_FPS))
var fps_min : int = 9999
var fps_max : int = 0
var fps_sum : int = 0
var fps_average : float = 0.0
var frames : int = -20  # need to wait a bit before starting to track the fps

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	instanced_marble = marble.instantiate()
	add_child(instanced_marble)
	$CanvasLayer/ReferenceRect/HSlider.value = num_cubes
	$CanvasLayer/ReferenceRect/NumLabel.text = "cubes: " + str(num_cubes) + " (" + str(num_cubes) + ")"
	# setup multimesh instances
	mm.set_instance_count(num_cubes)
	spawn_cubes()

func _unhandled_input(event) -> void:
	if event is InputEventKey:
		if Input.is_key_pressed(KEY_SPACE):
			launchMarble()

func _process(delta) -> void:
	timer += delta
	if timer > TIMER_LIMIT:
		frames += 1
		timer = 0.0
		#OS.set_window_title(title + " | fps: " + str(Engine.get_frames_per_second()))
		if frames > 0:
			fps = int(Performance.get_monitor(Performance.TIME_FPS))
			if fps < fps_min:
				fps_min = fps
			if fps > fps_max:
				fps_max = fps
			fps_sum += fps
# warning-ignore:integer_division
			fps_average = fps_sum / frames
			fpsLabel.text = "fps: " + str(fps) + " // " + "min: " + str(fps_min) + " // " + "max: " + str(fps_max) + " // " + "avg: " + str(fps_average)
	
func _physics_process(_delta) -> void:
	# update per-instance multimesh transforms on each physics frame
	for i in range(mm.instance_count):
		mm.set_instance_transform(i,cubeContainer.get_child(i).transform)

func spawn_cubes() -> void:
	PhysicsServer2D.set_active(false)
	
	var a = -side_length / 2.0
	var b = 0
	var c = a
	var d = 0
	
	for i in range(mm.instance_count):
		var instanced_cube = cube_mm.instantiate()
		
		#reset side a,b,c,d to zero on new level
		if (i % (side_length * 4) == 0):
			a = -side_length / 2.0
			b = 0
			c = a
			d = 0
		
		# y height should be (level - 0.5), but set to (level + 0.5) to let the bricks fall and collapse better
		
			instanced_cube.translate(Vector2(0,i + 0.5))
		get_node("CubeContainer").add_child(instanced_cube)
		mm.set_instance_transform(i,instanced_cube.transform)

func resetFPS() -> void:
	fpsLabel.text = "fps: "
	fps_min = 9999
	fps_max = 0
	fps_sum = 0
	fps_average = 0.0
	frames = -20

func launchMarble() -> void:
	if not marble_launched:
		PhysicsServer2D.set_active(true)
		#instanced_marble.translate(Vector2(-side_length/2,0))
		instanced_marble.apply_central_impulse(Vector2(-impulse,0))
		marble_launched = true
		fps_sum = 0
		frames = 1

func deleteCubes() -> void:
	for c in cubeContainer.get_children():
		c.free()

func resetAll() -> void:
	resetFPS()
	# delete marble
	instanced_marble.free()
	
	# delete cubes
	deleteCubes()
	num_cubes = int($CanvasLayer/ReferenceRect/HSlider.value)
	_on_HSlider_value_changed(num_cubes)
	mm.set_instance_count(num_cubes)
	# reinstance marble
	instanced_marble = marble.instantiate()
	marble_launched = false
	add_child(instanced_marble)
	spawn_cubes()


func _on_HSlider_value_changed(value) -> void:
	$CanvasLayer/ReferenceRect/NumLabel.text = "cubes: " + str(value) + " (" + str(num_cubes) + ")"

func _on_Timer_timeout() -> void:
	# Performance monitor does not work for Bullet Physics (we use a workaround) - https://github.com/godotengine/godot/issues/16540
	# sleepLabel.text = "sleeping: " + str(num_cubes - Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS) + 1)
	
	var sleep_count = 0
	for c in cubeContainer.get_children():
		if c.sleeping:
			sleep_count = sleep_count + 1
	sleepLabel.text = "sleeping: " + str(sleep_count)

func _on_CheckBox_toggled(button_pressed) -> void:
	if (button_pressed):
		$Timer.start()
		sleepLabel.text = "sleeping: "
	else:
		$Timer.stop()
		sleepLabel.text = "sleeping: (n/a)"
