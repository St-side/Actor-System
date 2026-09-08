# Actor-System

A small Roblox character-system experiment built around fixed-step movement, Server Authority, local prediction, and replicated Actor state.

The project explores a simple architecture for competitive multiplayer games such as fighting games and action games. Character simulation runs through `BindToSimulation`, the server remains authoritative, the owning client predicts its own character, and remote visual rigs are presented separately from gameplay state.

Actors use lightweight Attachments and Attributes to represent gameplay information such as movement intent, health, states, abilities, or other character data.

This repository is primarily a reference implementation and testbed rather than a complete drop-in character framework.

## Gameplay

Actor-System currently demonstrates a minimal third-person character controller built around Roblox Server Authority.

* Camera-relative WASD / gamepad movement
* Camera-driven character facing
* Jumping and gravity
* Player collision
* Idle, run, jump, and fall animations
* Client-side character presentation
* Predicted local movement with server-authoritative simulation

The gameplay is intentionally simple—the project is focused on experimenting with the underlying character simulation and presentation architecture rather than building a complete game.

## Networking and Rollback

Actor-System uses Roblox Server Authority rather than a custom character snapshot or reconciliation layer.

The owning client predicts its own character locally for immediate response, while the server runs the authoritative simulation for every player.

Conceptually:

```text
Local InputAction
        ↓
owner predicts movement
        ↓
server simulates authoritative movement
        ↓
Roblox verifies predicted state
        ↓
restore + re-simulate when needed
```

The client is therefore responsive without becoming authoritative.

### Predicted character state

Rollback is one of the main reasons the character is represented by explicit predicted state.

The Actor currently stores values such as:

```text
Actor.CFrame
Velocity
MoveVector
IsGrounded
```

These values describe the state needed to continue character simulation.

For example:

```text
CFrame
= current character transform

Velocity
= current controller velocity, including vertical movement

MoveVector
= current world-space movement intent

IsGrounded
= current support state
```

Position alone is not always enough to reproduce the next simulation step.

For example, two characters could be standing at the same position while having different vertical velocities:

```text
Character A
Position = same
Velocity.Y = 0

Character B
Position = same
Velocity.Y = 30
```

Their next simulation step should produce different results.

If a rollback restored the position but left velocity from a newer simulation state, re-simulation could begin from an inconsistent state.

Keeping important simulation state on the predicted Actor allows Roblox to restore the character to an earlier state before replaying simulation.


### Re-simulation

Movement runs through `BindToSimulation`, so the same simulation code can run during normal prediction and during Server Authority re-simulation.

The intended flow is:

```text
authoritative state
        ↓
restore predicted Actor state
        ↓
restore synchronized input
        ↓
BindToSimulation runs again
        ↓
movement / collision / gravity
        ↓
new Actor state
```

This is why Actor-System tries to keep movement logic deterministic from its current Actor state and synchronized inputs rather than depending on unrelated client-only state.

### Input ownership

The server evaluates movement for every player.

Each client only executes the movement controller for its own player:

```lua
if RunService:IsServer() or body.Player == Players.LocalPlayer then
	computeMovement(body, deltaTime)
end
```

Remote clients do not run another player's WASD controller.

This keeps input ownership simple:

```text
Server
→ simulates everyone

Owning client
→ predicts itself

Other clients
→ consume replicated/predicted remote state
```

Movement input comes from Roblox `InputAction` state rather than custom movement RemoteEvents.

## Presentation Smoothing

The Actor remains the gameplay and collision truth. The visible R15 rig is client-only Presentation.

```text
Local:
Predicted Actor → Visual Rig

Remote:
Predicted / synchronized Actor
→ small XYZ SmoothDamp
→ Visual Rig
```

Local characters follow predicted state directly for immediate responsiveness. Remote rigs use a small positional `SmoothDamp` to hide visual stepping between simulation/network updates and rendered frames.

Rotation remains direct, and smoothing never feeds back into simulation or collision.

The current remote smoothing time is `0.04`.


### Why some state should not be local Lua state

Temporary values are fine when they do not affect future simulation.

However, if a value changes the result of a later simulation step, it may need to participate in rollback state.

For example, future systems could require state such as:

```text
PreviousJumpInput
DashTimeRemaining
MovementLocked
AbilityState
```

If those values were stored only in ordinary local variables, a rollback could restore the Actor to an earlier position while leaving those variables at their newer values.

That would cause replay to begin from mismatched state.

A useful rule is:

> If restoring this value differently would change the result of the next simulation step, it should be considered part of rollback-aware simulation state.

This does **not** mean every variable should become an Attribute. Only state necessary to correctly reproduce the simulation needs to be rollback-aware.

### Presentation is separate

The client-side R15 rig is not part of authoritative character simulation.

```text
Predicted Actor
= networking / movement / collision truth

Visual Rig
= animation / appearance / presentation
```

Presentation reads Actor state but does not determine gameplay state.

This separation keeps visual behavior from interfering with rollback or authoritative movement corrections.


## References & Influences

Actor-System was informed by Roblox Server Authority documentation, community experiments, and existing approaches to server-authoritative character networking. These projects and resources were used as architectural references rather than as drop-in implementations.

* **Server Authority: Powering Competitive Gameplay (feat. ev1) | Inspire 2026 — Roblox Learn**
  Official Roblox discussion of Server Authority, prediction, reconciliation, and responsive competitive gameplay.

* **Server Authoritative API testing: Fighting Game Framework — CasuallyCritical**
  Community experimentation with Roblox Server Authority, predicted state, Attachments/Attributes, and custom character simulation.

* **Chickynoid — MrChickenRocket / easy-games**
  An open-source server-authoritative Roblox character controller. Its approaches to fixed-step character simulation, client prediction, rollback, collision, and separation of simulation from presentation were useful references while exploring Actor-System.

* **The TRIBES Engine Networking Model — Mark Frohnmayer and Tim Gift**
  A classic description of fixed-timestep multiplayer simulation, client-side prediction, networked object state, and visual interpolation between simulation updates.

