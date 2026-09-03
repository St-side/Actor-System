--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(script.Parent.Config)
local Input = require(script.Parent.Input)

local Simulation = {}
local IS_SERVER = RunService:IsServer()
local playerFolder: Folder
local nextSpawnSlot = 0

function Simulation.GroundCast(collider: BasePart): RaycastResult?
	local rayParams = RaycastParams.new()
	rayParams.ExcludeInstances = { collider }
	rayParams.RespectCanCollide = true
	local sphereRadius = 1.9
	local castDistance = collider.Size.Y * 0.5 - sphereRadius

	return workspace:Spherecast(
		collider.Position,
		sphereRadius,
		-Vector3.yAxis * castDistance,
		rayParams
	)
end

function Simulation.CreateCharacter(player: Player)
	-- the server owns the physical character lifecycle
	if not IS_SERVER then
		return
	end

	local groundPosition = Vector3.new(
		nextSpawnSlot * Config.SpawnSpacing,
		0,
		0
	)
	nextSpawnSlot += 1
	local colliderPosition = groundPosition
		+ Vector3.yAxis * (Config.Collider.Size.Y * 0.5)

	local collider = Instance.new("Part")
	collider.Name = Config.Collider.Prefix .. tostring(player.UserId)
	collider.Size = Config.Collider.Size
	collider.Transparency = Config.Collider.Transparency
	collider.Anchored = false
	collider.CanCollide = true
	collider.CanQuery = true
	collider.CanTouch = true
	collider.CustomPhysicalProperties = PhysicalProperties.new(
		0.7,
		0.3,
		0,
		1,
		100
	)
	collider.CFrame = CFrame.new(colliderPosition)

	-- Actor stays at the collider center as the shared gameplay origin
	local actor = Instance.new("Attachment")
	actor.Name = Config.ActorName
	actor:SetAttribute(Config.Attributes.UserId, player.UserId)
	actor:SetAttribute(Config.Attributes.MoveVector, Vector3.zero)
	actor:SetAttribute(Config.Attributes.IsGrounded, false)
	actor.Parent = collider

	collider.Parent = playerFolder

	player.ReplicationFocus = collider
end

function Simulation.DestroyCharacter(player: Player)
	local _, collider = Simulation.GetCharacter(player)
	if collider then
		collider:Destroy()
	end
end

function Simulation.GetCharacter(player: Player): (Attachment?, Part?)
	local collider = playerFolder:FindFirstChild(
		Config.Collider.Prefix .. tostring(player.UserId)
	)
	if not collider or not collider:IsA("Part") then
		return nil, nil
	end

	local actor = collider:FindFirstChild(Config.ActorName)
	return if actor and actor:IsA("Attachment") then actor else nil, collider
end

local function enableCharacterPrediction(collider: Part)
	RunService:SetPredictionMode(collider, Enum.PredictionMode.On)

	local actor = collider:WaitForChild(Config.ActorName)
	assert(actor:IsA("Attachment"), "Actor must be an Attachment")
	RunService:SetPredictionMode(actor, Enum.PredictionMode.On)
end

function Simulation.Client()
	local player = Players.LocalPlayer
	local localCollider = playerFolder:WaitForChild(
		Config.Collider.Prefix .. tostring(player.UserId)
	)
	assert(localCollider:IsA("Part"), "Local Collider must be a Part")

	-- only the owner predicts this collider assembly
	enableCharacterPrediction(localCollider)

	local camera = workspace.CurrentCamera
	assert(camera, "Workspace.CurrentCamera must exist")
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.Camera.FieldOfView

	local viewVector = Vector2.new()
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			viewVector -= Vector2.new(input.Delta.X, input.Delta.Y)
				* Config.Camera.MouseSensitivity
			viewVector = Vector2.new(
				viewVector.X,
				math.clamp(
					viewVector.Y,
					Config.Camera.MinimumPitch,
					Config.Camera.MaximumPitch
				)
			)
		end
	end)

	-- camera follows at render rate without moving gameplay state
	RunService:BindToRenderStep(
		"CameraMove",
		Enum.RenderPriority.Camera.Value - 1,
		function()
			camera.CFrame = CFrame.new(localCollider.Position)
				* CFrame.fromEulerAngles(
					viewVector.Y,
					viewVector.X,
					0,
					Enum.RotationOrder.YXZ
				)
				* CFrame.new(Config.Camera.Offset)
		end
	)
end

function Simulation.Step(deltaTime: number)
	for _, player in Players:GetPlayers() do
		if not IS_SERVER and player ~= Players.LocalPlayer then
			continue
		end

		local inputs = Input.GetInputs(player)
		local actor, collider = Simulation.GetCharacter(player)
		if not inputs or not actor or not collider then
			continue
		end

		local rawInputDirection =
			inputs.Movement:GetState() :: Vector2

		-- camera state is synced through server authority
		local cameraLook = player:GetCameraState().CFrame.LookVector
			* Vector3.new(1, 0, 1)
		cameraLook = if cameraLook.Magnitude > 0
			then cameraLook.Unit
			else Vector3.new(0, 0, -1)

		local cameraDirection = CFrame.lookAt(
			Vector3.zero,
			cameraLook,
			Vector3.yAxis
		)
		local moveVector = cameraDirection:VectorToWorldSpace(
			Vector3.new(
				rawInputDirection.X,
				0,
				-rawInputDirection.Y
			)
		)
		actor:SetAttribute(
			Config.Attributes.MoveVector,
			moveVector
		)

		collider.CFrame = CFrame.new(
			collider.Position
				+ moveVector
					* Config.MoveSpeed
					* deltaTime
		) * cameraDirection.Rotation

		-- held jump can fire again once the collider is grounded
		local groundCast = Simulation.GroundCast(collider)
		local grounded = groundCast ~= nil
		actor:SetAttribute(Config.Attributes.IsGrounded, grounded)

		local jumpPressed = inputs.Jump:GetState() :: boolean
		if grounded and jumpPressed then
			local velocity = collider.AssemblyLinearVelocity
			collider.AssemblyLinearVelocity = Vector3.new(
				velocity.X,
				Config.JumpVelocity,
				velocity.Z
			)
		end
	end
end

function Simulation.Setup()
	if IS_SERVER then
		Players.CharacterAutoLoads = false

		-- invisible server copy still provides physical collision
		local physicalBaseplate = workspace:FindFirstChild(Config.BaseplateAssetName)
		if not physicalBaseplate then
			physicalBaseplate = ReplicatedStorage
				:WaitForChild(Config.BaseplateAssetName)
				:Clone()
			physicalBaseplate.Parent = workspace
		end
		if physicalBaseplate:IsA("BasePart") then
			physicalBaseplate.Transparency = 1
		end
		for _, descendant in physicalBaseplate:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Transparency = 1
			end
		end

		local players = workspace:FindFirstChild(Config.PlayersFolderName)
		if not players then
			players = Instance.new("Folder")
			players.Name = Config.PlayersFolderName
			players.Parent = workspace
		end
		assert(players:IsA("Folder"), "Workspace.Players must be a Folder")
		playerFolder = players

		Players.PlayerAdded:Connect(Simulation.CreateCharacter)
		Players.PlayerRemoving:Connect(Simulation.DestroyCharacter)
		for _, player in Players:GetPlayers() do
			Simulation.CreateCharacter(player)
		end
	else
		local players = workspace:WaitForChild(Config.PlayersFolderName)
		assert(players:IsA("Folder"), "Workspace.Players must be a Folder")
		playerFolder = players

		Simulation.Client()
		local Presentation = require(script.Parent.Presentation)
		Presentation.Setup(playerFolder)
	end

	RunService:BindToSimulation(
		Simulation.Step,
		Config.SimulationFrequency,
		Config.SimulationPriority
	)
end

return table.freeze(Simulation)
