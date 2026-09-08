--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(script.Parent.Config)
local Animation = require(script.Parent.Animation)

-- Large discontinuities should snap instead of being visually smoothed.
local REMOTE_SNAP_DISTANCE = 36

type Record = {
	Rig: Model,
	Animation: Animation.Record,

	-- Remote Presentation-only state.
	RenderPosition: Vector3?,
	RenderVelocity: Vector3?,
}

local Presentation = {}

function Presentation.Setup(actors: Folder)
	local visuals = Instance.new("Folder")
	visuals.Name = Config.Presentation.FolderName
	visuals.Parent = workspace

	local template = ReplicatedStorage:WaitForChild(Config.Presentation.RigAssetName)
	assert(template:IsA("Model"))

	local records: { [Attachment]: Record } = {}

	local camera = workspace.CurrentCamera
	assert(camera)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.Camera.FieldOfView

	local view = Vector2.zero

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			view -= Vector2.new(input.Delta.X, input.Delta.Y) * Config.Camera.MouseSensitivity

			view = Vector2.new(
				view.X,
				math.clamp(
					view.Y,
					Config.Camera.MinimumPitch,
					Config.Camera.MaximumPitch
				)
			)
		end
	end)

	RunService:BindToRenderStep(
		"CameraMove",
		Enum.RenderPriority.Camera.Value - 1,
		function()
			local actor = actors:FindFirstChild(
				Config.ActorPrefix .. Players.LocalPlayer.UserId
			)

			if actor and actor:IsA("Attachment") then
				camera.CFrame =
					CFrame.new(actor.WorldPosition)
					* CFrame.fromEulerAngles(
						view.Y,
						view.X,
						0,
						Enum.RotationOrder.YXZ
					)
					* CFrame.new(Config.Camera.Offset)
			end
		end
	)

	RunService:BindToRenderStep(
		"ActorLabPresentation",
		Enum.RenderPriority.Last.Value,
		function(deltaTime: number)
			-- Retry incomplete streamed attributes; no gameplay state is
			-- written here.
			for _, instance in actors:GetChildren() do
				if not instance:IsA("Attachment") then
					continue
				end

				local userId = instance:GetAttribute(Config.Attributes.UserId)
				if typeof(userId) ~= "number" then
					continue
				end

				local record = records[instance]

				if not record then
					local rig = template:Clone()
					rig.Name = "Rig_" .. userId

					assert(rig.PrimaryPart)

					for _, part in rig:GetDescendants() do
						if part:IsA("BasePart") then
							part.Anchored = part == rig.PrimaryPart
							part.Massless = true
							part.CanCollide = false
							part.CanQuery = false
							part.CanTouch = false
						end
					end

					rig.Parent = visuals

					record = {
						Rig = rig,
						Animation = Animation.Create(rig),
					}

					records[instance] = record
				end

				local position = instance.WorldPosition
				local rotation = instance.WorldCFrame.Rotation

				if userId == Players.LocalPlayer.UserId then
					-- Owner remains completely direct/predicted.
					rotation = CFrame.fromEulerAngles(
						0,
						view.X,
						0,
						Enum.RotationOrder.YXZ
					)
				else
					local renderPosition = record.RenderPosition
					local renderVelocity =
						record.RenderVelocity or Vector3.zero

					if
						not renderPosition
						or (position - renderPosition).Magnitude
							>= REMOTE_SNAP_DISTANCE
					then
						renderPosition = position
						renderVelocity = Vector3.zero
					else
						renderPosition, renderVelocity =
							TweenService:SmoothDamp(
								renderPosition,
								position,
								renderVelocity,
								Config.Presentation.RemotePositionSmoothTime,
								math.huge,
								deltaTime
							)
					end

					record.RenderPosition = renderPosition
					record.RenderVelocity = renderVelocity

					position = renderPosition
				end

				record.Rig:PivotTo(
					CFrame.new(position)
					* rotation
					* CFrame.new(0, 0.36, 0)
				)

				Animation.Update(record.Animation, instance)
			end

			for actor, record in records do
				if actor.Parent ~= actors then
					Animation.Destroy(record.Animation)
					record.Rig:Destroy()
					records[actor] = nil
				end
			end
		end
	)
end

return table.freeze(Presentation)