# Actor-System

A small Roblox character-system experiment built around deterministic movement, Server Authority, local prediction, and replicated Actor state.

The project explores a simple architecture for competitive multiplayer games such as fighting games and action games. Character simulation runs through `BindToSimulation`, the server remains authoritative, the owning client predicts its own character, and remote visual rigs are presented separately from gameplay state.

Actors use lightweight Attachments and Attributes to represent gameplay information such as movement intent, health, states, abilities, or other character data.

This repository is primarily a reference implementation and testbed rather than a complete drop-in character framework.
