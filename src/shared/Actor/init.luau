--!strict

local Environment = require(script.Environment)

local Actor = {}

function Actor.Setup()
	Environment.Setup()
	require(script.Input).Setup()
	require(script.Simulation).Setup()
end

return table.freeze(Actor)
