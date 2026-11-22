# Operation Eagle Nest — Greybox v0.1

A small, deliberately readable infiltration sandbox for the Commandos-inspired prototype.

## Design goal
Test tactical readability and player choice before art production. The compound supports three distinct approaches, simple guard routines, and one objective/extraction loop.

## Layout (top-down, normalized 0–100)
- **North:** barracks block and guarded main gate.
- **Center:** courtyard, crates/barrels, and open sight lines.
- **East:** watchtower and exposed service approach.
- **South:** tree line and soft-cover approach.
- **West:** damaged wall breach and alternate entry.

## Routes
1. **West breach:** shortest route; close to patrol.
2. **South perimeter:** slower, uses vegetation/soft cover.
3. **East service side:** exposed to elevated observation.

## Greybox entities
- Player spawn: south-west tree line.
- Objective: documents in the barracks.
- Extraction: south-east edge.
- Guards: three initial patrols.
- Cover: crates, barrels, tree line, compound walls.

## Gameplay loop
1. Observe patrols.
2. Choose an entry route.
3. Avoid or distract guards.
4. Retrieve the documents.
5. Reach extraction.

## First implementation scope
- Isometric camera and world-to-screen transform.
- Ground plane and blockout walls/buildings.
- Player movement, facing, and collision.
- Three guard patrol paths.
- Basic guard vision cones and detection states.
- Objective interaction and extraction trigger.

No Gaussian rendering, character animation, weapons, inventory, or mission editor in this milestone.

## Coordinate convention
Mission layout uses normalized top-down coordinates in a 100 × 100 square. `mission.json` is authoritative for greybox placement; the SVG is a quick visual reference.
