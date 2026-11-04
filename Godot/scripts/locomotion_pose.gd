class_name BlackwebLocomotionPose
extends RefCounted
## Additive, code-native crouch and jump poses for recovered Luke.
## Call after the source walk/idle AnimationPlayer has evaluated, before arm IK.

var skeleton: Skeleton3D
var pelvis := -1
var spine := -1
var thigh_l := -1
var calf_l := -1
var foot_l := -1
var thigh_r := -1
var calf_r := -1
var foot_r := -1
var crouch_weight := 0.0
var jump_weight := 0.0

func bind(target: Skeleton3D) -> bool:
	skeleton = target
	if not is_instance_valid(skeleton): return false
	pelvis = skeleton.find_bone("Bip01 Pelvis")
	spine = skeleton.find_bone("Bip01 Spine")
	thigh_l = skeleton.find_bone("Bip01 L Thigh")
	calf_l = skeleton.find_bone("Bip01 L Calf")
	foot_l = skeleton.find_bone("Bip01 L Foot")
	thigh_r = skeleton.find_bone("Bip01 R Thigh")
	calf_r = skeleton.find_bone("Bip01 R Calf")
	foot_r = skeleton.find_bone("Bip01 R Foot")
	return [pelvis, spine, thigh_l, calf_l, foot_l, thigh_r, calf_r, foot_r].all(func(index): return index >= 0)

func apply(delta: float, crouching: bool, airborne: bool, vertical_speed: float, forward_world: Vector3) -> void:
	if not is_instance_valid(skeleton) or pelvis < 0: return
	crouch_weight = move_toward(crouch_weight, 1.0 if crouching else 0.0, delta * 5.0)
	jump_weight = move_toward(jump_weight, 1.0 if airborne and not crouching else 0.0, delta * 7.0)
	_clear_overrides()
	if crouch_weight <= 0.001 and jump_weight <= 0.001: return
	var down_local := skeleton.global_basis.inverse() * Vector3.DOWN
	var up_local := -down_local
	var forward := forward_world.slide(Vector3.UP).normalized()
	if forward.length_squared() < 0.5:
		forward = -skeleton.global_basis.z.normalized()
	var forward_local := (skeleton.global_basis.inverse() * forward).normalized()
	var right_unscaled := forward_local.cross(up_local)
	if right_unscaled.length_squared() < 0.000001: return
	var right_local := right_unscaled.normalized()
	var pelvis_pose := skeleton.get_bone_global_pose(pelvis)
	var lowered := Transform3D(pelvis_pose.basis, pelvis_pose.origin + down_local * (0.43 * crouch_weight))
	skeleton.set_bone_global_pose_override(pelvis, lowered, 1.0, true)
	if crouch_weight > 0.001:
		var spine_pose := skeleton.get_bone_global_pose(spine)
		var lean := Basis(right_local, deg_to_rad(-27.0) * crouch_weight)
		skeleton.set_bone_global_pose_override(spine, Transform3D(lean * spine_pose.basis, spine_pose.origin), 1.0, true)
	_pose_leg(thigh_l, calf_l, foot_l, -1.0, forward_local, right_local, up_local, vertical_speed)
	_pose_leg(thigh_r, calf_r, foot_r, 1.0, forward_local, right_local, up_local, vertical_speed)

func clear() -> void:
	crouch_weight = 0.0
	jump_weight = 0.0
	_clear_overrides()

func _clear_overrides() -> void:
	for index in [pelvis, spine, thigh_l, calf_l, foot_l, thigh_r, calf_r, foot_r]:
		if index >= 0: skeleton.set_bone_global_pose_override(index, Transform3D.IDENTITY, 0.0, false)

func _pose_leg(thigh: int, calf: int, foot: int, side: float, forward: Vector3, right: Vector3, up: Vector3, vertical_speed: float) -> void:
	var hip_pose := skeleton.get_bone_global_pose(thigh)
	var knee_pose := skeleton.get_bone_global_pose(calf)
	var ankle_pose := skeleton.get_bone_global_pose(foot)
	var base_ankle := skeleton.get_bone_global_pose_no_override(foot)
	var upper_length := hip_pose.origin.distance_to(knee_pose.origin)
	var lower_length := knee_pose.origin.distance_to(ankle_pose.origin)
	if upper_length < 0.05 or lower_length < 0.05: return
	# Crouch keeps the source feet planted while the pelvis settles. Jump tucks
	# each foot asymmetrically so the legs visibly leave their walk-cycle pose.
	var tuck := 0.30 if side < 0.0 else 0.24
	var kick := 0.12 if side < 0.0 else -0.09
	var target := base_ankle.origin + up * (tuck * jump_weight) + forward * (kick * jump_weight)
	var to_target := target - hip_pose.origin
	if to_target.length_squared() < 0.000001: return
	var reach := clampf(to_target.length(), absf(upper_length - lower_length) + 0.01, upper_length + lower_length - 0.01)
	var direction := to_target.normalized()
	var along := (upper_length * upper_length - lower_length * lower_length + reach * reach) / (2.0 * reach)
	var height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var guide := (forward + right * side * 0.18).normalized()
	var bend_unscaled := guide - direction * guide.dot(direction)
	if bend_unscaled.length_squared() < 0.000001:
		bend_unscaled = right - direction * right.dot(direction)
	if bend_unscaled.length_squared() < 0.000001:
		bend_unscaled = up - direction * up.dot(direction)
	if bend_unscaled.length_squared() < 0.000001: return
	var bend := bend_unscaled.normalized()
	var knee_target := hip_pose.origin + direction * along + bend * height
	var foot_target := hip_pose.origin + direction * reach
	var thigh_current := (knee_pose.origin - hip_pose.origin).normalized()
	var calf_current := (ankle_pose.origin - knee_pose.origin).normalized()
	var thigh_target := knee_target - hip_pose.origin
	var calf_target := foot_target - knee_target
	if thigh_target.length_squared() < 0.000001 or calf_target.length_squared() < 0.000001: return
	var thigh_rotation := Quaternion(thigh_current, thigh_target.normalized())
	var calf_rotation := Quaternion(calf_current, calf_target.normalized())
	skeleton.set_bone_global_pose_override(thigh, Transform3D(Basis(thigh_rotation) * hip_pose.basis, hip_pose.origin), 1.0, true)
	skeleton.set_bone_global_pose_override(calf, Transform3D(Basis(calf_rotation) * knee_pose.basis, knee_target), 1.0, true)
	skeleton.set_bone_global_pose_override(foot, Transform3D(base_ankle.basis, foot_target), 1.0, true)
