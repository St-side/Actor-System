--!strict

local Config = {
	PlayersFolderName = "Players",
	ActorPrefix = "Actor_",
	BaseplateAssetName = "Baseplate",
	MoveSpeed = 18,
	JumpVelocity = 50,
	SpawnSpacing = 8,
	SimulationFrequency = Enum.StepFrequency.Hz60,
	SimulationPriority = 2000,

	Attributes = table.freeze({
		UserId = "UserId",
		Velocity = "Velocity",
		MoveVector = "MoveVector",
		IsGrounded = "IsGrounded",
	}),

	Presentation = table.freeze({
		FolderName = "_ActorPresentation",
		RigAssetName = "PresentationRig",
	}),

	Camera = table.freeze({
		FieldOfView = 70,
		MouseSensitivity = 0.003,
		MinimumPitch = math.rad(-80),
		MaximumPitch = math.rad(80),
		Offset = Vector3.new(0, 0, 14),
	}),
}

return table.freeze(Config)
