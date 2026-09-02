--!strict

local Config = require(script.Parent.Config)

local FADE_TIME = 0.1
local MOVING_THRESHOLD = 0.01

local ASSET_IDS = table.freeze({
	Idle1 = "rbxassetid://507766388",
	Idle2 = "rbxassetid://507766951",
	Idle3 = "rbxassetid://507766666",
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

local function isGrounded(collider: BasePart): boolean
	local rayParams = RaycastParams.new()
	rayParams.ExcludeInstances = { collider }
	rayParams.RespectCanCollide = true

	return workspace:Spherecast(
		collider.Position,
		1.9,
		Vector3.new(0, -3, 0),
		rayParams
	) ~= nil
end

function Animation.Create(rig: Model): Record
	local controller = rig:FindFirstChildOfClass("AnimationController")
	assert(controller, "PresentationRig must have an AnimationController")

	local animator = controller:FindFirstChildOfClass("Animator")
	assert(animator, "PresentationRig AnimationController must have an Animator")

	return {
		Idle = loadTrack(
			animator,
			ASSET_IDS.Idle1,
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
	actor: Attachment,
	collider: BasePart
)
	local value = actor:GetAttribute(Config.Attributes.MoveVector)
	local moveVector = if typeof(value) == "Vector3"
		then value
		else Vector3.zero
	local moving = moveVector.Magnitude > MOVING_THRESHOLD
	local velocity = collider.AssemblyLinearVelocity
	local grounded = isGrounded(collider)

	local nextTrack: AnimationTrack

	if not grounded then
		nextTrack = if velocity.Y > 0.5
			then record.Jump
			else record.Fall
	else
		nextTrack = if moving
			then record.Run
			else record.Idle
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
