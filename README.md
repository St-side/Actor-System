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

