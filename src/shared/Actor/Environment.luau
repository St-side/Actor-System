--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)

local Environment = {}
local ENVIRONMENT_NAME = "ActorLabEnvironment"

function Environment.Setup()
	if RunService:IsServer() then
		local template = ReplicatedStorage:WaitForChild(Config.BaseplateAssetName)
		local baseplate = template:Clone()
		assert(baseplate, "ReplicatedStorage.Baseplate must be Archivable")
		local environment = Instance.new("Model")
		environment.Name = ENVIRONMENT_NAME
		environment.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		baseplate.Parent = environment
		-- Publish the complete environment before character setup.
		environment.Parent = workspace
	else
		local environment = workspace:WaitForChild(ENVIRONMENT_NAME)
		environment:WaitForChild(Config.BaseplateAssetName)
	end
end

return table.freeze(Environment)
