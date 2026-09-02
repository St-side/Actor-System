--!strict

local Input = require(script.Input)
local Simulation = require(script.Simulation)

local Actor = {}

function Actor.Setup()
	Input.Setup()
	Simulation.Setup()
end

return table.freeze(Actor)
