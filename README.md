# Operation Eagle Nest — Greybox v0.1

A small, deliberately readable infiltration sandbox for the Commandos-inspired prototype.

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
- A headless simulation entry point: `game_update(world, input, dt)`. `Input` is a plain struct filled from the keyboard in `main.odin`, and `World` owns the mission, player, guards and mission progress, so the whole simulation runs without raylib input.
- The documents objective: modelled in mission data, completed by pressing E within `OBJECTIVE_INTERACT_RADIUS` of it.
- Extraction gated on the objective, a success outcome that freezes the world, and restart (R) via `world_reset`.
- Greybox feedback: objective marker, locked/unlocked extraction pad, objective status text and a mission-complete banner.

The README's original first-implementation checklist is therefore historical, not a list of work that is still wholly outstanding.

## Test coverage already present

| Test file | Existing coverage |
|---|---|
| guards_test.odin | Patrol and investigation movement, collision avoidance, arrival at last-known position, searching/scanning, recovery and patrol resumption, reacquisition, hearing, sight-over-sound priority, obstacle routing, unreachable targets, direct pursuit, moving-target jitter regression |
| awareness_test.odin | Initial state, suspicion accumulation/decay, alert persistence, sound suspicion, visual override, sound suspicion persistence during investigation |
| perception_test.odin | Vision range, field of view, building occlusion, wall openings |
| sound_test.odin | Noise intensity falloff, radius limits, hearing thresholds and invalid noise |
| navigation_test.odin | Direct paths, building avoidance, diagonal corner rules, blocked goals and out-of-bounds positions |
| game_test.odin | Pipeline through `game_update` with synthetic input: footsteps heard without line of sight, sneaking quieter than walking, sight building suspicion into an alert, player input stopped by geometry |
| mission_flow_test.odin | Objective interaction range and edge-triggering, extraction gating, missions without an objective, success and frozen world, restart returning to a clean state |

Do not add duplicate tests for these behaviours without first identifying a specific uncovered case. Prefer strengthening an existing regression test or adding an integration test that covers a real gap.

## Important implementation notes

- mission.odin currently models player spawn, extraction location/radius, the documents objective, buildings, walls, cover and guard patrol definitions.
- `mission.json` also contains `routes`, which the runtime Mission structure does not model. Treat them as design notes, not an implemented gameplay system.
- Building interiors are solid boxes in the greybox, so the documents objective (inside the barracks) is reached from the building's outer face. `OBJECTIVE_INTERACT_RADIUS` is sized for that; revisit it if buildings gain walkable interiors.
- A mission with no objective (empty id) has extraction available from the start.
- The guard tests exercise AI functions and update behaviour directly. `game_test.odin` and `mission_flow_test.odin` cover the pipeline and mission flow through `game_update` with synthetic input, but only on small hand-built missions, not on `mission.json` itself.
- Within one `game_update`, a heard footstep turns the guard towards the noise before the perception pass runs. A guard with a clear view of the player can therefore hear, turn and see in the same frame, and sight then replaces the sound as the last-known source.
- The current jitter regression checks moving-target pursuit over time and caps coarse direction changes at 80 over 400 updates. It is useful coverage, but the threshold is permissive and should be treated as a regression guard, not proof of perfect pursuit.
- Navigation is a 100 × 100 grid A* implementation. Its current open-set selection scans the grid; optimise only if profiling shows it is a real bottleneck.
- Keep gameplay geometry authoritative and independent of rendering. Gaussian splatting and production art remain later visual milestones, not prerequisites for the first playable mission.

## What is not yet a complete playable mission

The objective, extraction gating, success outcome and restart are implemented (see the baseline above). What remains:

1. Failure state — decide what ends a mission in failure (for example an alerted guard reaching the player) and expose it as a `Mission_Outcome`. Only `PLAYING` and `SUCCESS` exist today.
2. Playable feedback — the greybox HUD shows objective status and the outcome, but not guard awareness beyond sphere colour.
3. Flow validation on the real mission — the flow tests use small hand-built missions. Add a test that loads `mission.json` and checks that the objective and extraction are reachable from the spawn.
4. Manual playthrough — the objective, extraction and restart loop has not yet been played through in a running build.

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