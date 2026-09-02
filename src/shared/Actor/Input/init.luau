--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

export type Inputs = InputContext & {
	Movement: InputAction,
	Jump: InputAction,
}

local InputTemplate = script.Inputs :: InputContext
local Input = {}

function Input.Server()
	local function onPlayerAdded(player: Player)
		if player:FindFirstChild("Inputs") then
			return
		end

		local clientInputs = InputTemplate:Clone()
		clientInputs.Enabled = true
		clientInputs.Parent = player
	end

	for _, player in Players:GetPlayers() do
		task.defer(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

function Input.Client()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

function Input.GetInputs(player: Player): Inputs?
	return player:FindFirstChild("Inputs") :: Inputs?
end

function Input.Setup()
	if RunService:IsServer() then
		Input.Server()
	else
		Input.Client()
	end
end

return table.freeze(Input)
