# Commandos Dev-Handover

**Project:** `algo-boyz/commandos`\
**Language:** Odin\
**Rendering:** Raylib\
**Platform:** macOS (Apple Silicon)\

We're building a tactical stealth game inspired by the original *Commandos* series, using Odin & Raylib.

The goal is to capture the atmosphere & gameplay of Commandos while exploring modern rendering techniques, particularly Gaussian Splatting & eventually 4D Gaussian Splatting.

We're developing incrementally, prioritising a working game over speculative architecture.

## 1. Current implementation

### Camera & player

- Isometric camera with azimuth 45° & elevation 38°.
- Orthographic projection.
- Smooth camera follow.
- Shift + drag camera panning.
- Scroll-wheel zoom.
- WASD player movement.
- Acceleration & deceleration.
- Independent-axis collision resolution.
- Player facing indicator.
- Camera follow toggle with F.

The camera currently feels right for a first iteration.

### Mission geometry

- `main.odin`
- `mission.odin`
- `mission.json`
- `isometric/iso.odin`

Implemented:

- JSON mission loading.
- Mission-defined player spawn & extraction.
- Data-driven buildings & walls.
- Wall openings.
- Crates, barrels & trees.
- Shared geometry definitions for rendering & collision.
- Circle-versus-box & circle-versus-circle collision.

The user pushes changes & confirms:

`odin test .` — working.

## 2. Latest development

1. Guard patrol movement.
2. Line of sight.
3. Stealth awareness & detection.
4. Eventually combat & mission objectives.

Features:

- Reads patrol waypoints from mission data.
- Configurable movement speed.
- Configurable pause duration at waypoints.
- Cyclic patrol routes.
- Facing direction.
- Consumes leftover frame time across waypoint & pause boundaries.
- No Raylib dependency in the simulation logic.

Default parameters:

- Speed: 3.5 mission units/second.
- Pause: 1 second.
- Radius: 0.8.

## GitHub

[https://github.com/algo-boyz/commandos](https://github.com/algo-boyz/commandos)

The repo was readable through GitHub integration, but write operations returned HTTP 403

- The user should git apply .patch & test the changes locally.

## 5. Dev workflow & preferences

- Working directly against the actual repository.
- Small, incremental implementation steps.
- Complete, usable Odin code rather than pseudocode.
- Deterministic tests.
- Minimal dependencies.
- Architecture that supports future expansion without premature complexity.
- Compiler errors addressed iteratively.
- User tests locally, then shares compiler output or confirms success.

Use Odin syntax & when possible, add tests before or alongside simulation features.

**Phase 1 — Guard perception**

- Field of view.
- Facing direction.
- Range.
- Line-of-sight obstruction from walls & buildings.

**Phase 2 — Awareness**

- Idle.
- Suspicious.
- Investigating.
- Alerted.
- Returning to patrol.

**Phase 3 — Stealth gameplay**

- Visual detection feedback.
- Cover & concealment.
- Player visibility.
- Sound propagation.

---

- A guard spots the player.
- Suspicion builds until the guard becomes alerted.
- The player escapes behind cover.
- The guard moves to the last position where the player was seen.
- The guard stops there, even if the player has moved elsewhere.
- When a guard reaches the last-known position, it pauses briefly.
- It scans left and right, rotating its facing direction.
- If it sees the player again, it updates the last-known position and resumes pursuit.
- If it doesn't, it remains alerted for now.

- Player movement emits footsteps at a 0.45-second cadence.
- Footsteps use the existing Noise_Event.
- Noise is delivered to guards through existing guard_hear_noise().
- Existing attenuation and hearing thresholds determine who hears it.
- Existing awareness logic transitions guards to suspicious and preserves the sound source.
- Existing investigation behaviour handles the response.
- Visual detection still takes precedence.
- Walk near a guard — they should investigate.
- Walk farther away — they should remain unaware.
- Walk behind walls — confirm sound still propagates (currently expected; sound occlusion isn't implemented).
- Stop moving — footsteps stop.

### **Controls**

| Input        | Mode  | Speed | Noise  |
| ------------ | ----- | ----- | ------ |
| WASD         | Walk  | 12    | Normal |
| Ctrl + WASD  | Sneak | 4.5   | Quiet  |
| Shift + WASD | Run   | 18    | Loud   |
