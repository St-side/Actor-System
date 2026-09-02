--!strict

local Config = {
	PlayersFolderName = "Players",
	ActorName = "Actor",
	BaseplateAssetName = "Baseplate",
	MoveSpeed = 18,
	JumpVelocity = 50,
	SpawnSpacing = 8,
	Collider = table.freeze({
		Prefix = "Collider_",
		Size = Vector3.new(2.5, 5.5, 2.5),
		Transparency = 0.5,
	}),
	SimulationFrequency = Enum.StepFrequency.Hz60,
	SimulationPriority = 2000,

	Attributes = table.freeze({
		UserId = "UserId",
		MoveVector = "MoveVector",
	}),

	Presentation = table.freeze({
		FolderName = "Presentation",
		RigAssetName = "PresentationRig",
		RemotePositionSmoothTime = 0.05,
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
