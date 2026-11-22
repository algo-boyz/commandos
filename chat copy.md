**Commandos —&#x20;**&#x43;urrent development checkpoint



**Project**

- **Repository:** [github.com/algo-boyz/commandos](https://github.com/algo-boyz/commandos?utm_source=chatgpt.com)
- **Language:** Odin
- **Rendering:** Raylib
- **Platform:** macOS · Apple Silicon
- **Genre:** Tactical stealth game inspired by the original *Commandos*
- **Current focus:** Mission navigation and guard pathfinding

**1. Current project status**



The following systems are implemented:

- Isometric 3D camera and greybox environment.
- Player movement with acceleration, deceleration and collision.
- Mission geometry loaded from mission.json.
- Buildings, walls, wall openings, crates, barrels and trees.
- Guard patrol waypoint movement.
- Guard awareness states: unaware, suspicious, alerted and recovering.
- Visual and auditory awareness.
- Last-known-position investigation.
- Guard search behavior with directional scanning.
- Patrol recovery after investigation.
- Mission geometry collision checks.

The existing test suite currently passes:



**2. Navigation implementation**



We have started a new navigation.odin module.



The initial implementation provides:



Feature



Implementation



Grid



100 × 100



Coordinate system



XZ ground plane



Movement



8 directions



Cardinal cost



1



Diagonal cost



√2



Heuristic



Octile distance



Collision



mission_point_collides()



Diagonal corner cutting



Prevented



Path reconstruction



Start to goal



Open set



Linear minimum-score scan



The pathfinder uses mission geometry as its source of truth.



**Important implementation detail**



Navigation uses Mission_Point:

- x corresponds to world X.
- y corresponds to world Z.

The guard's collision radius should be used when generating paths. The current guard radius is GUARD_RADIUS = 0.8.



**4. Current development milestone**



Navigation core implemented



1. **Navigation debug visualization**\
   &#x20;Display calculated paths in the actual mission environment.
2. **Navigation edge-case tests**\
   &#x20;Test wall openings, narrow passages, guard clearance and unreachable destinations.
3. **Path smoothing**\
   &#x20;Remove unnecessary intermediate grid points while preserving collision clearance.
4. **Guard patrol integration**\
   &#x20;Replace direct waypoint interpolation with path-following.
5. **Investigation and recovery integration**\
   &#x20;Use navigation for suspicious and alerted guards returning to their patrol routes.
6. **Dynamic navigation**\
   &#x20;Later consider moving obstacles, door states, squad movement and navigation updates.

**6. Architecture decisions**



Keep these principles:

- Mission geometry remains the source of truth.
- Navigation is independent of rendering.
- Navigation is independent of guard awareness logic.
- Guards navigate in the XZ plane; no unnecessary 3D pathfinding.
- Do not integrate pathfinding into guard behavior until visualization and tests are solid.
- Prefer simple, deterministic algorithms before optimization.
- A binary heap can replace the linear open-set scan later if profiling warrants it.

**7. Development workflow**

1. Implement one small, isolated milestone.
2. Provide exact file changes.
3. Run odin test ..
4. Fix compiler and test failures before moving on.
5. User verifies locally.
6. User pushes the working changes.
7. Continue to the next milestone.

**Important:** Previous attempts at generating malformed git apply patches caused unnecessary friction. Always work from the current repository contents and provide accurate, minimal changes. Do not invent file contents or assume the local repository matches an old snapshot.



**Starting prompt for the next chat**



Continue development of algo-boyz/commandos from this handover.



We have completed the initial A\* navigation core in navigation.odin and its tests in navigation_test.odin. All 39 tests currently pass.



The next major improvement is **guard perception and behavior integration** — making guards react to actual world events in a more coherent way rather than just isolated state transitions.