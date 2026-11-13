@icon("../resources/icons/fps_controller_hands.svg")
class_name FPSControllerHands extends Node3D

#region Signals
signal attachment_added(attachment: Node3D)
signal attachment_removed(attachment: Node3D)
#endregion

#region Public Methods
func attach_node(
	attachment: Node3D,
	attachment_transform: Transform3D = Transform3D.IDENTITY,
	) -> bool:
		if not is_instance_valid(attachment) or attachment.is_queued_for_deletion():
			return false
		
		if attachment == self or attachment.is_ancestor_of(self):
			push_error("A Hands attachment cannot be Hands itself or one of its ancestors.")
			return false
		
		if attachment.get_parent() == self:
			attachment.transform = attachment_transform
			return true
		
		if attachment.get_parent() != null:
			attachment.get_parent().remove_child(attachment)
		
		attachment.transform = attachment_transform
		add_child(attachment)
		attachment_added.emit(attachment)
		
		return true


func instantiate_attachment(
	attachment_scene: PackedScene,
	attachment_transform: Transform3D = Transform3D.IDENTITY,
	) -> Node3D:
		if attachment_scene == null or not attachment_scene.can_instantiate():
			push_error("Hands requires an instantiable PackedScene.")
			return null
		
		var attachment_root: Node = attachment_scene.instantiate()
		
		if not attachment_root is Node3D:
			push_error("A Hands attachment scene must have a Node3D root.")
			attachment_root.free()
			return null
		
		var attachment: Node3D = attachment_root as Node3D
		
		if not attach_node(attachment, attachment_transform):
			attachment.free()
			return null
		
		return attachment


func detach_node(attachment: Node3D) -> Node3D:
	if not is_instance_valid(attachment) or attachment.get_parent() != self:
		return null
	
	remove_child(attachment)
	attachment_removed.emit(attachment)
	return attachment


func get_attachments() -> Array[Node3D]:
	var attachments: Array[Node3D] = []
	
	for child: Node in get_children():
		if child is Node3D and not child.is_queued_for_deletion():
			attachments.append(child as Node3D)
	
	return attachments


func clear_attachments() -> void:
	for attachment: Node3D in get_attachments():
		detach_node(attachment)
		attachment.queue_free()
#endregion
