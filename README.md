# Actor-System

A small Roblox character-system experiment built around deterministic movement, Server Authority, local prediction, and replicated Actor state.

The project explores a simple architecture for competitive multiplayer games such as fighting games and action games. Character simulation runs through `BindToSimulation`, the server remains authoritative, the owning client predicts its own character, and remote visual rigs are presented separately from gameplay state.

Actors use lightweight Attachments and Attributes to represent gameplay information such as movement intent, health, states, abilities, or other character data.

This repository is primarily a reference implementation and testbed rather than a complete drop-in character framework.

## References

Some ideas explored in this project were informed by Roblox Server Authority documentation, community experiments, and talks.

* **Server Authoritative API testing: Fighting Game Framework** — CasuallyCritical
  Related community experimentation with predicted Actors, Attachments/Attributes, and remote character presentation using Roblox Server Authority.

* **Server Authority: Powering Competitive Gameplay (feat. ev1) | Inspire 2026** — Roblox Learn
  Official Roblox talk covering Server Authority, prediction, and architecture for responsive competitive gameplay.
