# Operation Eagle Nest — Greybox v0.1

A small, deliberately readable infiltration sandbox for the Commandos-inspired prototype.
# Commandos — State of Play

**Last reviewed:** 2026-11-23
**Repository:** algo-boyz/commandos
**Branch:** main
**Engine/language:** Raylib + Odin
**Stage:** Greybox systems prototype; preparing the first playable mission

## Current baseline

- A data-driven greybox mission with a 100 × 100 top-down coordinate space.
- Mission geometry for buildings, walls/openings and cover objects.
- Shared mission collision queries used by movement and navigation.
- Player movement and guard patrol behaviour.
- Guard vision with range, field-of-view and geometry occlusion.
- Sound events with distance-based intensity and hearing thresholds.
- Guard awareness states: UNAWARE, SUSPICIOUS, ALERTED and RECOVERING.
- Last-known-position tracking with sight taking priority over sound.
- Guard investigation, search pauses/scanning and return-to-patrol behaviour.
- Grid-based A* navigation with obstacle avoidance and diagonal corner-cut prevention.
- Regression coverage for pursuit steering, pursuit around obstacles, patrol/recovery navigation and the recent moving-target jitter issue.

The README's original first-implementation checklist is therefore historical, not a list of work that is still wholly outstanding.

## Test coverage already present

| Test file | Existing coverage |
|---|---|
| guards_test.odin | Patrol and investigation movement, collision avoidance, arrival at last-known position, searching/scanning, recovery and patrol resumption, reacquisition, hearing, sight-over-sound priority, obstacle routing, unreachable targets, direct pursuit, moving-target jitter regression |
| awareness_test.odin | Initial state, suspicion accumulation/decay, alert persistence, sound suspicion, visual override, sound suspicion persistence during investigation |
| perception_test.odin | Vision range, field of view, building occlusion, wall openings |
| sound_test.odin | Noise intensity falloff, radius limits, hearing thresholds and invalid noise |
| navigation_test.odin | Direct paths, building avoidance, diagonal corner rules, blocked goals and out-of-bounds positions |

Do not add duplicate tests for these behaviours without first identifying a specific uncovered case. Prefer strengthening an existing regression test or adding an integration test that covers a real gap.

## Important implementation notes

- mission.odin currently models player spawn, extraction location/radius, buildings, walls, cover and guard patrol definitions.
- The runtime Mission structure does not yet model the README's documents objective or route definitions. Those design concepts should not be mistaken for implemented gameplay systems.
- Extraction is represented as mission data, but a complete objective-to-extraction success loop is not yet established.
- The guard tests exercise AI functions and update behaviour directly. They do not, by themselves, prove the complete player-to-perception-to-awareness-to-guard pipeline in a running mission.
- The current jitter regression checks moving-target pursuit over time and caps coarse direction changes at 80 over 400 updates. It is useful coverage, but the threshold is permissive and should be treated as a regression guard, not proof of perfect pursuit.
- Navigation is a 100 × 100 grid A* implementation. Its current open-set selection scans the grid; optimise only if profiling shows it is a real bottleneck.
- Keep gameplay geometry authoritative and independent of rendering. Gaussian splatting and production art remain later visual milestones, not prerequisites for the first playable mission.

## What is not yet a complete playable mission

1. Objective model and interaction — define the documents objective in mission data/runtime state and let the player interact with it.
2. Mission progression — track objective completion and extraction eligibility.
3. Extraction trigger — detect the player reaching the extraction zone after completing the objective.
4. Mission outcome — expose success/failure state and a simple restart path.
5. Playable feedback — provide enough HUD/visual feedback to understand objective status, guard awareness and mission completion.
6. End-to-end validation — test the mission flow as a whole, not only its component systems.

These are the priorities for the first playable mission. New AI features, Gaussian rendering, character animation, inventory, multiple commandos and a mission editor should not displace this milestone unless they are required to make the core loop playable.

## Recommended next milestone: first playable mission

Build the smallest complete loop using the existing greybox:

1. Load the current mission and spawn the player and guards.
2. Allow the player to infiltrate while guards patrol, perceive, investigate and recover.
3. Reach and interact with the documents objective.
4. Mark the objective complete and enable extraction.
5. Reach the extraction zone and trigger mission success.
6. Allow restart so the mission can be replayed.

### Acceptance criteria

- The mission can be started from a clean launch.
- The objective is visible/readable and can be completed through player interaction.
- Extraction cannot complete before the objective is complete.
- Entering extraction after objective completion produces a clear success state.
- Restart returns the mission to a clean initial state.
- Existing guard, awareness, perception, sound and navigation tests continue to pass.
- New tests cover objective interaction, progression gating, extraction and restart.

## Working agreements for future development

- Work from the current main state unless a different branch is explicitly agreed.
- Inspect the current implementation and tests before proposing new tests or changing behaviour.
- Avoid duplicating existing coverage; identify the precise missing behaviour first.
- Make one focused change at a time, run odin test ., and report the actual result.
- Keep patches aligned with the current source files; do not assume an older file layout or enum/state model.
- Preserve the separation between mission/gameplay geometry and rendering.
- Update this document when a milestone materially changes what is implemented or what remains.

## Source of truth

The code and tests on the reviewed branch are authoritative. The README describes the mission concept; Roadmap.md describes longer-term direction; this file records the current implementation baseline and the immediate next milestone.