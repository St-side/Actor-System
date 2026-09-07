--!strict

local Config = require(script.Parent.Config)

local MOVING_THRESHOLD = 0.01
local FADE_TIME = 0.1

local ASSET_IDS = table.freeze({
	Idle = "rbxassetid://507766388",
	Run = "rbxassetid://507767714",
	Jump = "rbxassetid://507765000",
	Fall = "rbxassetid://507767968",
})

export type Record = {
	Idle: AnimationTrack,
	Run: AnimationTrack,
	Jump: AnimationTrack,
	Fall: AnimationTrack,
	Current: AnimationTrack?,
}

local Animation = {}

local function loadTrack(
	animator: Animator,
	animationId: string,
	priority: Enum.AnimationPriority,
	looped: boolean
): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local track = animator:LoadAnimation(animation)
	track.Looped = looped
	track.Priority = priority

	animation:Destroy()

	return track
end

function Animation.Create(rig: Model): Record
	local controller = rig:FindFirstChildOfClass("AnimationController")
	assert(controller, "PresentationRig must have an AnimationController")

	local animator = controller:FindFirstChildOfClass("Animator")
	assert(animator, "PresentationRig AnimationController must have an Animator")

	return {
		Idle = loadTrack(
			animator,
			ASSET_IDS.Idle,
			Enum.AnimationPriority.Idle,
			true
		),
		Run = loadTrack(
			animator,
			ASSET_IDS.Run,
			Enum.AnimationPriority.Movement,
			true
		),
		Jump = loadTrack(
			animator,
			ASSET_IDS.Jump,
			Enum.AnimationPriority.Movement,
			false
		),
		Fall = loadTrack(
			animator,
			ASSET_IDS.Fall,
			Enum.AnimationPriority.Movement,
			true
		),
		Current = nil,
	}
end

function Animation.Update(
	record: Record,
	actor: Attachment
)
	local value = actor:GetAttribute(Config.Attributes.MoveVector)
	local moveVector = if typeof(value) == "Vector3"
		then value
		else Vector3.zero

	local velocity = actor:GetAttribute(Config.Attributes.Velocity)
	if typeof(velocity) ~= "Vector3" then
		return
	end

	local moving = moveVector.Magnitude > MOVING_THRESHOLD
	local grounded =
		actor:GetAttribute(Config.Attributes.IsGrounded) == true

	local nextTrack: AnimationTrack

	if grounded then
		nextTrack = if moving then record.Run else record.Idle
	elseif velocity.Y > 0 then
		nextTrack = record.Jump
	else
		nextTrack = record.Fall
	end

	if record.Current == nextTrack and nextTrack.IsPlaying then
		return
	end

	if record.Current and record.Current ~= nextTrack then
		record.Current:Stop(FADE_TIME)
	end

	nextTrack:Play(FADE_TIME)
	record.Current = nextTrack
end

function Animation.Destroy(record: Record)
	for _, track in {
		record.Idle,
		record.Run,
		record.Jump,
		record.Fall,
	} do
		track:Stop(0)
		track:Destroy()
	end

	record.Current = nil
end

return table.freeze(Animation)