--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animation = require(script.Parent.Animation)
local Config = require(script.Parent.Config)

-- authored rig root sits slightly above the collider center
local RIG_ROOT_OFFSET = CFrame.new(0, 0.36, 0)

type PresentationRecord = {
	Rig: Model,
	Animation: Animation.Record,
	IsLocal: boolean,
}

local Presentation = {}
local records: { [Attachment]: PresentationRecord } = {}
local started = false

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if folder then
		assert(folder:IsA("Folder"), name .. " must be a Folder")
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function actorUserId(actor: Attachment): number?
	local userId = actor:GetAttribute(Config.Attributes.UserId)
	return if typeof(userId) == "number" then userId else nil
end

local function configureRig(rig: Model)
	local root = rig.PrimaryPart
	assert(root, "PresentationRig must have a BasePart PrimaryPart")

	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = descendant ~= root
		end
	end
end

local function configureVisual(asset: Instance)
	local function configure(instance: Instance)
		if instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = false
		end
	end

	configure(asset)

	for _, descendant in asset:GetDescendants() do
		configure(descendant)
	end
end

local function presentationCFrame(
	actor: Attachment,
	record: PresentationRecord,
	position: Vector3
): CFrame
	-- remote rigs use the facing synchronized on Actor
	if not record.IsLocal then
		return CFrame.new(position)
			* actor.WorldCFrame.Rotation
			* RIG_ROOT_OFFSET
	end

	-- local rig follows render-rate camera yaw
	local camera = workspace.CurrentCamera
	if not camera then
		return actor.WorldCFrame * RIG_ROOT_OFFSET
	end

	local look =
		camera.CFrame.LookVector * Vector3.new(1, 0, 1)

	if look.Magnitude == 0 then
		look =
			actor.WorldCFrame.LookVector
			* Vector3.new(1, 0, 1)

		if look.Magnitude == 0 then
			look = Vector3.new(0, 0, -1)
		end
	end

	return CFrame.new(position)
		* CFrame.lookAt(
			Vector3.zero,
			look.Unit,
			Vector3.yAxis
		)
		* RIG_ROOT_OFFSET
end

local function createRig(
	actor: Attachment,
	presentationFolder: Folder
)
	if records[actor] then
		return
	end

	local template =
		ReplicatedStorage:FindFirstChild(
			Config.Presentation.RigAssetName
		)

	assert(
		template and template:IsA("Model"),
		"PresentationRig must be a Model"
	)

	local userId = actorUserId(actor)
	assert(userId, "Actor must have a UserId")

	local rig = template:Clone()
	rig.Name = "Rig_" .. userId

	configureRig(rig)
	rig.Parent = presentationFolder

	local record: PresentationRecord = {
		Rig = rig,
		Animation = Animation.Create(rig),
		IsLocal = userId == Players.LocalPlayer.UserId,
	}

	rig:PivotTo(
		presentationCFrame(actor, record, actor.WorldPosition)
	)
	records[actor] = record
end

local function removeRig(actor: Attachment)
	local record = records[actor]
	if record then
		Animation.Destroy(record.Animation)
		record.Rig:Destroy()
		records[actor] = nil
	end
end

function Presentation.Setup(playerFolder: Folder)
	if started then
		return
	end
	started = true

	local presentationFolder = getOrCreateFolder(
		playerFolder,
		Config.Presentation.FolderName
	)

	local renderVisuals =
		getOrCreateFolder(workspace, "RenderVisuals")

	local map =
		getOrCreateFolder(renderVisuals, "Map")

	local oldBaseplate =
		map:FindFirstChild(Config.BaseplateAssetName)

	if oldBaseplate then
		oldBaseplate:Destroy()
	end

	local baseplate =
		ReplicatedStorage
			:WaitForChild(Config.BaseplateAssetName)
			:Clone()

	-- client map is visual only; the server keeps collision
	configureVisual(baseplate)
	baseplate.Parent = map

	local function addCollider(collider: Instance)
		if not collider:IsA("Part") then
			return
		end

		local actor =
			collider:FindFirstChild(Config.ActorName)

		if actor and actor:IsA("Attachment") then
			createRig(actor, presentationFolder)
		end
	end

	for _, collider in playerFolder:GetChildren() do
		addCollider(collider)
	end

	playerFolder.ChildAdded:Connect(addCollider)

	playerFolder.ChildRemoved:Connect(function(collider)
		if not collider:IsA("Part") then
			return
		end

		local actor =
			collider:FindFirstChild(Config.ActorName)

		if actor and actor:IsA("Attachment") then
			removeRig(actor)
		end
	end)

	RunService:BindToRenderStep(
		"ActorLabPresentation",
		Enum.RenderPriority.Last.Value,
		function()
			for actor, record in records do
				if not actor:IsDescendantOf(playerFolder) then
					removeRig(actor)
					continue
				end

				local collider = actor.Parent
				if not collider or not collider:IsA("BasePart") then
					continue
				end

				local position = actor.WorldPosition
				record.Rig:PivotTo(
					presentationCFrame(actor, record, position)
				)

				Animation.Update(record.Animation, actor, collider)
			end
		end
	)
end

return table.freeze(Presentation)
