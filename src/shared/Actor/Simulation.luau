--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = require(script.Parent.Input)
local Config = require(script.Parent.Config)

local IS_SERVER = RunService:IsServer()
local SIZE = Vector3.new(2.5, 5.5, 2.5)
local GRAVITY = 196.2 -- Manual vertical acceleration for the kinematic Actor.
local SKIN = 0.02 -- Clearance from world surfaces after a sweep hit.
local GROUND_DISTANCE = 0.06 -- Downward support-query tolerance.
local BODY_RADIUS = 1.25
local SEPARATION_TOLERANCE = 0.001

type Body = {
	Player: Player,
	Actor: Attachment,
	Position: Vector3,
	Rotation: CFrame,
	Velocity: Vector3,
	MoveVector: Vector3,
}

local Simulation = {}
local actors: Folder
local spawnSlot = 0 -- Server lifecycle only, never movement/rollback state.
local params = RaycastParams.new()
params.RespectCanCollide = true

local function getActor(player: Player): Attachment?
	local actor = actors:FindFirstChild(Config.ActorPrefix .. player.UserId)
	return if actor and actor:IsA("Attachment") then actor else nil
end

local function isGrounded(position: Vector3): boolean
	local hit = workspace:Blockcast(CFrame.new(position), SIZE, -Vector3.yAxis * GROUND_DISTANCE, params)
	return hit ~= nil and hit.Normal.Y > 0.5
end

local function sweep(position: Vector3, displacement: Vector3): (Vector3, boolean)
	local distance = displacement.Magnitude
	if distance == 0 then
		return position, false
	end
	local hit = workspace:Blockcast(CFrame.new(position), SIZE, displacement, params)
	if not hit then
		return position + displacement, false
	end
	local allowedDistance = math.max(0, hit.Distance - SKIN)
	return position + displacement.Unit * allowedDistance, true
end

local function computeMovement(body: Body, deltaTime: number): boolean
	local inputs = Input.GetInputs(body.Player)
	if not inputs then
		return false
	end
	-- Only Y carries integration state forward; WASD does not consume previous X/Z.
	local velocity = body.Velocity
	local movement = inputs.Movement:GetState() :: Vector2
	local jump = inputs.Jump:GetState() :: boolean

	local look = body.Player:GetCameraState().CFrame.LookVector
	local lookXZ = Vector3.new(look.X, 0, look.Z)
	local forward = if lookXZ.Magnitude > 0 then lookXZ.Unit else -Vector3.zAxis
	local facing = CFrame.lookAt(Vector3.zero, forward, Vector3.yAxis)
	local moveVector = facing:VectorToWorldSpace(Vector3.new(movement.X, 0, -movement.Y))
	body.MoveVector = moveVector

	local position = body.Position
	local grounded = velocity.Y <= 0 and isGrounded(position)
	local velocityY = if grounded then 0 else velocity.Y
	if grounded and jump then
		velocityY = Config.JumpVelocity
	else
		velocityY -= GRAVITY * deltaTime
	end

	-- Consume current input immediately in this invocation, without an attribute round-trip.
	local horizontalVelocity = moveVector * Config.MoveSpeed
	local blocked: boolean
	position, blocked = sweep(position, horizontalVelocity * deltaTime)
	if blocked then
		-- Stop the whole horizontal command at a wall; no sliding solver.
		horizontalVelocity = Vector3.zero
	end
	position, blocked = sweep(position, Vector3.yAxis * velocityY * deltaTime)
	if blocked then
		velocityY = 0
	end
	body.Position = position
	body.Rotation = facing.Rotation
	body.Velocity = Vector3.new(horizontalVelocity.X, velocityY, horizontalVelocity.Z)
	return true
end

local function resolvePair(a: Body, b: Body)
	if math.abs(b.Position.Y - a.Position.Y) >= SIZE.Y then
		return
	end
	local offset = Vector3.new(b.Position.X - a.Position.X, 0, b.Position.Z - a.Position.Z)
	local distance = offset.Magnitude
	local penetration = BODY_RADIUS * 2 - distance
	if penetration <= SEPARATION_TOLERANCE then
		return
	end
	-- Pairs are UserId-sorted, so coincident bodies always choose the same sign.
	local normal = if distance > 0.000001 then offset / distance else Vector3.xAxis
	local half = penetration * 0.5
	local oldA, oldB = a.Position, b.Position
	a.Position = sweep(oldA, -normal * half)
	b.Position = sweep(oldB, normal * half)
	local acceptedA = math.clamp((oldA - a.Position):Dot(normal), 0, half)
	local acceptedB = math.clamp((b.Position - oldB):Dot(normal), 0, half)
	-- Let the free body absorb separation rejected by the other body's world sweep.
	a.Position = sweep(a.Position, -normal * (half - acceptedB))
	b.Position = sweep(b.Position, normal * (half - acceptedA))
end

function Simulation.Step(deltaTime: number)
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	local bodies: { Body } = {}
	for _, player in players do
		local actor = getActor(player)
		if not actor then
			continue
		end
		local velocity = actor:GetAttribute(Config.Attributes.Velocity)
		local moveVector = actor:GetAttribute(Config.Attributes.MoveVector)
		if typeof(velocity) ~= "Vector3" or typeof(moveVector) ~= "Vector3" then
			continue -- Wait for initial predicted state to arrive.
		end
		local body: Body = {
			Player = player,
			Actor = actor,
			Position = actor.CFrame.Position,
			Rotation = actor.CFrame.Rotation,
			Velocity = velocity,
			MoveVector = moveVector,
		}
		if IS_SERVER or player == Players.LocalPlayer then
			if not computeMovement(body, deltaTime) then
				continue
			end
		end
		table.insert(bodies, body)
	end

	-- All movement is ready before any unique pair is separated.
	for _ = 1, 2 do
		for i = 1, #bodies - 1 do
			for j = i + 1, #bodies do
				resolvePair(bodies[i], bodies[j])
			end
		end
	end

	for _, body in bodies do
		local actor = body.Actor
		if not IS_SERVER and body.Player ~= Players.LocalPlayer
			and body.Position == actor.CFrame.Position then
			continue -- Do not rewrite untouched remote state.
		end
		local grounded = body.Velocity.Y <= 0 and isGrounded(body.Position)
		if grounded then
			body.Velocity = Vector3.new(body.Velocity.X, 0, body.Velocity.Z)
		end
		if IS_SERVER or body.Player == Players.LocalPlayer then
			actor:SetAttribute(Config.Attributes.MoveVector, body.MoveVector)
		end
		actor:SetAttribute(Config.Attributes.IsGrounded, grounded)
		actor:SetAttribute(Config.Attributes.Velocity, body.Velocity)
		actor.CFrame = CFrame.new(body.Position) * body.Rotation
	end
end

function Simulation.Setup()
	if IS_SERVER then
		Players.CharacterAutoLoads = false
		local folder = workspace:FindFirstChild(Config.PlayersFolderName)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = Config.PlayersFolderName
			folder.Parent = workspace
		end
		assert(folder:IsA("Folder"))
		actors = folder
		local function create(player: Player)
			if getActor(player) then return end
			local actor = Instance.new("Attachment")
			actor.Name = Config.ActorPrefix .. player.UserId
			-- SpawnPart top is Y=1; keep the virtual box clear of initial overlap.
			actor.CFrame = CFrame.new(spawnSlot * Config.SpawnSpacing, 1 + SIZE.Y / 2 + SKIN, 0)
			spawnSlot += 1
			actor:SetAttribute(Config.Attributes.UserId, player.UserId)
			actor:SetAttribute(Config.Attributes.MoveVector, Vector3.zero)
			actor:SetAttribute(Config.Attributes.IsGrounded, false)
			actor:SetAttribute(Config.Attributes.Velocity, Vector3.zero)
			actor.Parent = actors
		end
		Players.PlayerAdded:Connect(create)
		Players.PlayerRemoving:Connect(function(player)
			local actor = getActor(player)
			if actor then actor:Destroy() end
		end)
		for _, player in Players:GetPlayers() do create(player) end
	else
		local folder = workspace:WaitForChild(Config.PlayersFolderName)
		assert(folder:IsA("Folder"))
		actors = folder
		local function predict(instance: Instance)
			if instance:IsA("Attachment") then
				RunService:SetPredictionMode(instance, Enum.PredictionMode.On)
			end
		end
		actors.ChildAdded:Connect(predict)
		for _, actor in actors:GetChildren() do predict(actor) end
		require(script.Parent.Presentation).Setup(actors)
	end
	params.ExcludeInstances = { actors }
	RunService:BindToSimulation(Simulation.Step, Config.SimulationFrequency, Config.SimulationPriority)
end

return table.freeze(Simulation)
