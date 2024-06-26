extends Node2D

@export var spawn_rate : int = 45 # (int,5,250)
const MAX_MESHES : int = 2950

@onready var fpsLabel : Label = $CanvasLayer/ReferenceRect/FPSLabel
@onready var sleepLabel : Label = $CanvasLayer/ReferenceRect/SleepLabel
@onready var mm : MultiMesh = $MultiMeshInstance2D.get_multimesh()
@onready var cubeContainer : Node2D = $CubeContainer
@onready var cube_mm : PackedScene = preload("res://cube_mm.tscn")

var timer : float = 0.0
var start : bool = false
@export var TIMER_LIMIT := 0.1	# fps gui refresh rate in seconds # (float,0.01,1.0)

@onready var fps : int = int(Performance.get_monitor(Performance.TIME_FPS))
var fps_min : int = 9999
var fps_max : int = 0
var fps_sum : int = 0
var fps_average : float = 0.0
var frames : int = -20  # need to wait a bit before starting to track the fps
var start_msec : int
var end_msec : int

var spawn_transform : Transform3D = Transform3D()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CanvasLayer/TimeLabel.text = ""
	$CanvasLayer/ReferenceRect/HSlider.value = spawn_rate
	$CanvasLayer/ReferenceRect/NumLabel.text = "rate (ms): " + str(spawn_rate)
	# setup multimesh instances
	mm.set_instance_count(MAX_MESHES)   # max total meshes
	mm.visible_instance_count = 0

	spawn_transform = transform.translated(Vector2(0,35))

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
			# calc fps avg of last 1 second in 1 second intervals (we only do a division once every second)
			if frames <= 10:
				fps_sum += fps
			else:
				# warning-ignore:integer_division
				fps_average = fps_sum / frames
				frames = 0
				fps_sum = fps
				
			fpsLabel.text = "fps: " + str(fps) + " // " + "min: " + str(fps_min) + " // " + "max: " + str(fps_max) + " // " + "avg: " + str(fps_average)

func _physics_process(_delta) -> void:
	# update per-instance multimesh transforms on each physics frame
	for i in range(mm.visible_instance_count):
		mm.set_instance_transform(i,cubeContainer.get_child(i).transform)

func spawn_cubes() -> void:
	# instance cube node
	var instanced_cube = cube_mm.instantiate()
	cubeContainer.add_child(instanced_cube)

	instanced_cube.transform = spawn_transform
	mm.set_instance_transform(mm.visible_instance_count,instanced_cube.transform)
	instanced_cube.apply_central_impulse(Vector3(randf_range(-5,5),-45,randf_range(-5,5)))
	
	mm.visible_instance_count += 1

func resetFPS() -> void:
	fpsLabel.text = "fps: "
	fps_min = 9999
	fps_max = 0
	fps_sum = 0
	fps_average = 0.0
	frames = -20

func deleteCubes() -> void:
	for cube in cubeContainer.get_children():
		cube.free()

func resetAll() -> void:
	resetFPS()
	
	# delete cubes
	deleteCubes()
	spawn_rate = int($CanvasLayer/ReferenceRect/HSlider.value)
	_on_HSlider_value_changed(spawn_rate)
	mm.visible_instance_count = 0

func _on_SleepUITimer_timeout() -> void:
	# Performance monitor does not work for Bullet Physics (we use a workaround) - https://github.com/godotengine/godot/issues/16540
	# sleepLabel.text = "sleeping: " + str(num_cubes - Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS) + 1)
	var sleep_count = 0
	for cube in cubeContainer.get_children():
		if cube.sleeping:
			sleep_count = sleep_count + 1
	sleepLabel.text = "sleeping: " + str(sleep_count)

func _on_CheckBox_toggled(button_pressed) -> void:
	if (button_pressed):
		$SleepUITimer.start()
		sleepLabel.text = "sleeping: "
	else:
		$SleepUITimer.stop()
		sleepLabel.text = "sleeping: (n/a)"

func _on_HSlider_value_changed(value):
	$CanvasLayer/ReferenceRect/NumLabel.text = "rate (ms): " + str(value)
	$CubeSpawnTimer.wait_time = value/1000.0

func _on_CubeSpawnTimer_timeout():
	if mm.visible_instance_count < MAX_MESHES:
		spawn_cubes()
		$CanvasLayer/ReferenceRect/RichTextLabel.text = " " + str(mm.visible_instance_count)
	else:
		$CubeSpawnTimer.stop()
		end_msec = Time.get_ticks_msec()
		print("Elapsed Time: " + str(end_msec - start_msec) + " ms")
		$CanvasLayer/TimeLabel.text = "[center]" + str(end_msec-start_msec) + " ms[/center]"
		
func _on_ResetButton_pressed():
	resetAll()

func _on_CheckButton_toggled(button_pressed):
	if button_pressed:
		$CubeSpawnTimer.start()
		start_msec = Time.get_ticks_msec()
	else:
		$CubeSpawnTimer.stop()
