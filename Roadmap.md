# Commandos

**Build a spiritual successor to Commandos, using Gaussian splatting as an artistic and technical differentiator.**

## **1. What actually made Commandos special?**

[commandos-behind-enemy-lines-windows-screenshot-green-lights - Arcade Attack](https://images.openai.com/static-rsc-4/z0661VvpkPhQXhHq_jCTTSxRVyNggn3ie3Vmv6llAonyKdkAaU4rBaafN2A7x1q4UjsMbOwfSTBHDROePOVxBHPJOokl-Oz85A06YSf0x527aWRV0omqYZPM0InVHk3Zx8BUgi-5csKcI6dcnKVObaOdTcuZolKda_4dJ7XpxD0?purpose=inline)

[Screenshot of Commandos 2: Men of Courage (Windows, 2001) - MobyGames](https://images.openai.com/static-rsc-4/A8eNIQuKiQM_1jpmnHjJsTMtpznQOAgottOGgH53wStt_aWfX8aYSCJWAzp5vmzJ0BRY9JVkC_p-8GG74FL_aqFcDhvpMb9e7JPzddAngy24ONBxSuhz0HQT5mn33JKjeD6oBkREK2mCfOBrVq99ueFpV9LDl2zRgKQYEpOrims?purpose=inline)

[Commandos: Behind Enemy Lines — The Games of 1998](https://images.openai.com/static-rsc-4/zoAOIXZ-2mJonXfd1uNaXSGhUfX67HH0RYBQNBKAsdNfJp6z6fMkpdryOSXLBC8smdkfgOxIB7inI2pmMcGDEgJbNpuIvZjjhfAV666mEiIlZwy39FcES4hujKaiuZKQmxzz7YeL94G_CVMyB8rULaT6bIPIsDv7REUdjteqiAI?purpose=inline)

It was the combination of:

- Carefully designed, dense environments.
- Multiple specialists with complementary abilities.
- Interconnected stealth systems.
- Enemy patrol routines and vision cones.
- Environmental opportunities and emergent solutions.
- A feeling that you're solving a living tactical puzzle.
- Missions that reward observation, patience and creativity.

## **2. Technology strategy**

Not everything needs to be Gaussian.

A Commandos-like game has several fundamentally different requirements:

| Requirement              | Best initial technology                 |
| ------------------------ | --------------------------------------- |
| Terrain and scenery      | 3D Gaussian splats / meshes             |
| Buildings and interiors  | Hybrid geometry + splats                |
| Characters               | Conventional 3D models initially        |
| Character animation      | Skeletal animation                      |
| Vehicles                 | Meshes + animation                      |
| Enemy AI                 | Custom deterministic simulation         |
| Navigation               | Grid / navigation mesh                  |
| Visibility and occlusion | Explicit gameplay geometry              |
| Atmosphere               | Gaussian rendering, lighting, particles |

Gaussian splats are fantastic at reproducing visual complexity, but they aren't inherently a gameplay representation.

Imagine a guard standing behind a building. The player needs to know whether the guard can see the commando. We need reliable geometry, not just a beautiful cloud of translucent ellipsoids.

Likewise, we need reliable collision, pathfinding, selection, interaction, shadows and animation.

**Proposal: two representations of the same world.**

**Visual world**

Gaussian splats · meshes · materials · atmosphere

**Gameplay world**

Collision · navigation · visibility · interaction · AI

Shared coordinate system, separate responsibilities.

This is a much more powerful architecture than trying to make Gaussian splats do everything.

## **3. The actual fastest route: one mission**

[Commandos: Beyond the Call of Duty (1998)](https://images.openai.com/static-rsc-4/azCwHVoEaE1KQ98-_oVrifPP1xHZ_CZGvAWVnx_hBPWg6yi3Y6eIHOHPyF-Mx7OslgcyWcnmI3oscvc2ihXH36TnBN58ra_gMHPp5exZIwZ6nFMNTQ9Xcl1rrMhoQtPM6dlNeEe6FtY3ArEdoPVq0AIOAvB4sS56KcXIX9HQVEY?purpose=inline)

[Test de Commandos 2 : Men of Courage sur PC](https://images.openai.com/static-rsc-4/XfXQ0nGMBs96uVkHEWsZUQoKRqsq4F-HO1iIq9MTt3uOHs07GLuhVBvOsG858zsNROmgkmXw46FynYzDK2dHr8W0gKDxx0DS_2p-jPVb6nSL7oCUxC6bOAmsxUjynhQjJJtl1pLn3of9M0c4D0xTr7E6OnWEbUb6_MeGkDXm4GY?purpose=inline)

[Commandos 2: Destination Paris 1.46 Released! news - ModDB](https://images.openai.com/static-rsc-4/bzCAgsYD6Tlhj1dVVEnSPCZHY17cmvKkzAFWpJ5EeY-Bq93MLcyCIFeOE9UEGZx2iG-N6RU_UjjJX_3fIdnSkPwSD72BIm09NKmNQzL_vKPSPKWqclClOIDg0d6TUKZxgUiLnlek82cpVgjNJVHUXQtML6ulzF5H7IU47UQo154?purpose=inline)

[commandos-behind-enemy-lines-windows-screenshot-green-lights - Arcade Attack](https://images.openai.com/static-rsc-4/z0661VvpkPhQXhHq_jCTTSxRVyNggn3ie3Vmv6llAonyKdkAaU4rBaafN2A7x1q4UjsMbOwfSTBHDROePOVxBHPJOokl-Oz85A06YSf0x527aWRV0omqYZPM0InVHk3Zx8BUgi-5csKcI6dcnKVObaOdTcuZolKda_4dJ7XpxD0?purpose=inline)

[Desperados III Mission 8: Baton Rouge Walkthrough - Neoseeker](https://images.openai.com/static-rsc-4/gDrSyVnS0Y3qY9uMm5sfVj1X2ktcuNDR9xOspwCjiwDAq_ga_zi1Z57_AN1MDPSM_OTPq1t0m_hFLJY54IexqsdFq9-CMeB9g4zfRlMfI0c5Uwe9Bh5hP1l8aBYqqML0knkWYZx5QJGeqTBlf1LDfQotnw3jjBeZipUyDXS1QWc?purpose=inline)

[Commandos: Origins - Test de Commandos: Origins - Tout n'est pas rose pour le retour d'une franchise culte - Jeux vidéo](https://images.openai.com/static-rsc-4/vWiHwxCK005efjOsJb7p3mkM3XJCHBb_GVUipmndkFd3DXFhm8eHRt0yXqZgwDGJFN1lmLA8u12C9hAsE0ERbw5-V0Sj2OLytgQFkyAToNm7sHyFP_h9-AJhZyJiq8sJhfXb69ulKe8Gqnydc0xOZBOstQDxN8JFPsgRtA9tkAU?purpose=inline)

1. One playable commando.
2. Two or three guards.
3. Patrol routes.
4. Vision cones.
5. Crouching and hiding.
6. Distractions.
7. Body detection.
8. Alarm escalation.
9. One objective and extraction.

The important thing is that the mission is fun before we add expensive graphics.

# **4. Development roadmap**

Primary objective: playable vertical slice

1. **M1 — Tactical gameplay prototype**

   First priority
   - Isometric camera.
   - Character movement.
   - Grid-free navigation.
   - Guard patrols and perception.
   - Stealth and detection.
   - Basic mission objectives.

   Deliverable: a playable greybox mission.

2. **M2 — Art direction experiment**
   - Capture or create one detailed environment.
   - Import static SPZ assets through OSPZ.
   - Render Gaussian scenery.
   - Establish a painterly, cinematic aesthetic.
   - Compare Gaussian, mesh and hybrid representations.

   Deliverable: one visually distinctive playable compound.

3. **M3 — Character and animation pipeline**
   - Character rigs.
   - Skeletal animation.
   - Interaction animations.
   - Cover and hiding.
   - Gaussian environmental animation experiments.

   Deliverable: characters that feel integrated into the environment.

4. **M4 — Mission systems**
   - Multiple specialists.
   - Inventory and abilities.
   - Enemy alert states.
   - Sound propagation.
   - Mission scripting.
   - Multiple approaches to objectives.

   Deliverable: a complete short mission.

5. **M5 — Production pipeline**
   - 4DGS asset pipeline.
   - Environment editor.
   - Mission editor.
   - Asset compression.
   - Save/load.
   - Performance optimization.

   Deliverable: a repeatable way to produce new missions.

## **5. Where OSPZ and PixlSplat fit**

**OSPZ**

The asset infrastructure:

- SPZ compatibility
- Gaussian IO
- Animation metadata
- Compression
- Temporal assets

**PixlSplat**

The visual production tool:

- Scene inspection
- Gaussian editing
- Asset composition
- Environment preparation
- Animation preview

The game should consume both, rather than become entangled with their internal implementations.

In particular, make PixlSplat useful for producing actual game environments as early as possible.

## **6. The artistic direction: this is where we can do something special**

I wouldn't aim for photorealistic Gaussian reconstructions.

I'd aim for something between:

[Pre-Rendered Backgrounds Aesthetics (@PRBG_Aesthetics) on X](https://images.openai.com/static-rsc-4/oS3ElzN9xon4Dy3rhJsFFi4kt1qd-YwqM3hDLvuMKPpZZFfcUQCbdhVeKDZYUfjpYcM1OzELkNVc0TN6Id_PjO4-B-LnLSu8oovc-Tt0vo_1YqVPnFo9u5y80a3olDvM_mE3MKECugmifByMRbUOQw-issjqWM4jTIK_UlwOsD4?purpose=inline)

**Commandos**

Strong composition, readable environments, tactical clarity.

[Discover the Serenity of Sainte-Marie Village in French Countryside | AI Art Generator | Easy-Peasy.AI](https://images.openai.com/static-rsc-4/TeIZUPKXKv-eGT_6JPPR45VI6Yvipz6-TX0m18MQNCL6rMbk5UwCppiEXJpVQUYPXhGVIr_kGOMq62VOW5XMUQXzIuK6l45jSgZx_gf0F-FCxuE9V_LtYZ-_7V9naac0tYWawF3VfV6Q5sxiiypmt34wq1HSf7YTQy7_aCMikeE?purpose=inline)

**Painterly environments**

Organic detail, expressive lighting, rich atmosphere.

[Blizzcon 2018 - Warcraft III: Reforged - Gallery - World of Warcraft](https://images.openai.com/static-rsc-4/oktwhkmcAXqC3219RRc4LbPsOLL6HHRwH21nObmQHoLjEc6ihbKDavdp0KMeum7_GXv8qVqthCeyjjDn84Hy--wOB7XOgJOywGco82OsNlp8we-aeqof405839yibCDJj9CIi1vI_NioHCN-sYGg0oax6zLaJjhCr45kOHdoM1g?purpose=inline)

**Stylized readability**

Distinct silhouettes and visual hierarchy.

[Indie Essentials - Walking Simulators 2](https://images.openai.com/static-rsc-4/BKXFZW7cSZuunMlTCjdvPZthVGpux8w8xvUVZ-7KAJlF_0IzkLakPA6oWvbNJ0Ff9HBOYcy-BuCvxXfy3uVDkydDe_QPHNNGFl6TwurdvHaSAZorLcEu6teYYdPml2-2aDsXxmdjOU9fEP5dZAOn8lfjAdyYfFvkoyDJPgCUBkw?purpose=inline)

**Gaussian magic**

A visual texture and depth that conventional game assets struggle to reproduce.

One particularly interesting idea: use Gaussian splats to reproduce highly detailed environments, but retain conventional geometry for interactive objects.

That gives us painterly scenery without sacrificing gameplay precision.

We could even experiment with deliberately stylized Gaussian rendering: color grading, controlled opacity, depth-aware outlines and atmospheric perspective.

## **7. What about 4D Gaussian Splatting?**

I would still pursue it, but change its immediate purpose.

Rather than making it the foundation of character animation, I'd investigate:

- Moving foliage.
- Smoke and explosions.
- Water and environmental effects.
- Animated environmental set pieces.
- Background characters and crowds.
- Captured cinematic sequences.

Eventually, native 4D Gaussian assets could become a distinctive way of distributing animated environmental content.

But I'd keep the main characters on a conventional animation pipeline until we have a compelling reason to change.

# **8. My recommended first 30 days**

Assuming we're keeping Odin + Raylib and working with limited resources:

| Period | Deliverable                                              |
| ------ | -------------------------------------------------------- |
| Week 1 | Isometric camera, movement, greybox environment          |
| Week 2 | Guard AI, patrols, vision and detection                  |
| Week 3 | Stealth mechanics, interactions, mission objective       |
| Week 4 | Import an SPZ environment and integrate hybrid rendering |

At the end of this, we should be able to play a small mission.

Not watch a technology demo. Actually play it.

## **9. One important strategic decision**

There are two possible ambitions here:

**A. Make a great Commandos successor**

Optimize for gameplay, production speed, level design and a shippable commercial product.

Technology is selected based on what helps us ship.

**B. Build a new kind of game engine and game**

Own the rendering pipeline, Gaussian asset formats, animation system, environment tools and gameplay framework.

Higher technical ambition, potentially much greater differentiation, but considerably more risk.

My preference is a combination: **A as the commercial objective, B as our technological advantage.**

The game must remain playable even if our 4DGS experiments fail.

## **My proposed next step**

Before writing more OSPZ animation code, I'd establish the actual game architecture and build the first greybox mission.

I would call the project something provisional like *Operation Eagle Nest*.

The first technical target:

Vertical slice v0.1

**One commando. One compound. Three guards. One objective. Multiple ways to infiltrate.**

And one beautiful Gaussian environment.

That's the point where we find out whether we have the beginnings of something special.

# **Commandos — Project assessment & development roadmap**

My assessment: **we've moved beyond a camera-and-movement prototype. We now have the foundations of a proper tactical stealth game.**

The important milestone isn't the amount of code we've written. It's that we've started establishing the systems that make a Commandos-style game possible:

- A navigable isometric world.
- A data-driven mission environment.
- Shared geometry for rendering and collision.
- Player movement with physical constraints.
- Guard patrols and waypoint timing.
- A perception and awareness system.
- Investigation behaviour, including searching the last known player position.

That's a meaningful progression.

I would resist the temptation to introduce Gaussian Splatting just yet. We should first establish a small but convincing gameplay loop. That will give us something concrete to render with the new technology later.

## **1. Where we stand**

**Current project maturity**

Core prototype

**World and camera**

Established

**Mission geometry**

Established

**Player controller**

First iteration

**Guard AI**

In development

**Gameplay loop**

Not implemented

**Visual production**

Not started

Qualitative engineering assessment, not measured completion percentages.

### **What's particularly good**

**1. Mission geometry is becoming authoritative.**

Moving the environment into `mission.json` was an important decision. We can now develop missions independently of rendering and gameplay implementation.

**2. We have started thinking in terms of behaviour rather than animation.**

The guard's investigation and search behaviour is much more important than making a guard look convincing. The player needs to understand what the guard knows, suspects and is doing.

**3. We haven't overengineered the renderer.**

Raylib is doing exactly what we need right now: providing a quick feedback loop while we develop gameplay.

## **2. What needs attention before adding more features**

Having inspected the current branch, I see a few things worth addressing. Nothing requires a major rewrite.

### **A. Separate simulation from rendering**

In `main.odin`, guard awareness is currently updated inside the drawing section.

That means perception, suspicion and state transitions are effectively tied to rendering.

We should change this:

```
Game loop
 ├── Input
 ├── Player update
 ├── Guard movement
 ├── Guard perception
 ├── Guard awareness
 ├── Mission state
 └── Rendering
```

Rendering should become read-only.

This is important when we eventually introduce more expensive rendering techniques, variable frame rates or replay functionality.

### **B. Guard patrols need collision awareness**

Player movement and guard investigation already use collision checks, but ordinary patrol movement does not.

Currently guards move directly between waypoints.

We should eventually make patrol navigation respect the same geometry as the player. Otherwise guards can walk through buildings and obstacles.

I would not introduce a full navigation mesh yet. For this scale of game, waypoint paths with collision-aware movement are sufficient initially.

### **C. Mission schema needs tightening**

`mission.json` already contains objectives, routes, coordinate-space metadata and identifiers.

However, the current `Mission` structure doesn't yet represent all those fields.

We should bring the schema and runtime model into alignment, and validate mission data during loading.

In particular:

- Invalid or missing spawn positions.
- Patrol waypoints inside buildings.
- Unreachable extraction points.
- Invalid wall openings.
- Missing objective definitions.

### **D. Awareness and investigation need another iteration**

The existing three states are a good starting point:

- UNAWARE
- SUSPICIOUS
- ALERTED

But we need to distinguish between what a guard perceives and what the guard believes.

For example:

A guard might see something suspicious, walk towards it, find nothing, and eventually return to patrol.

An alerted guard might investigate the last known position, search the area, and then return to a heightened state of vigilance.

That distinction will become central to the gameplay.

## **3. Proposed development roadmap**

I'd organise the next development stages around gameplay milestones rather than technical subsystems.

[commandos-behind-enemy-lines-windows-screenshot-green-lights - Arcade Attack](https://images.openai.com/static-rsc-4/z0661VvpkPhQXhHq_jCTTSxRVyNggn3ie3Vmv6llAonyKdkAaU4rBaafN2A7x1q4UjsMbOwfSTBHDROePOVxBHPJOokl-Oz85A06YSf0x527aWRV0omqYZPM0InVHk3Zx8BUgi-5csKcI6dcnKVObaOdTcuZolKda_4dJ7XpxD0?purpose=inline)

**Milestone 1 — Convincing guard behaviour**

Next

Simulation, perception and AI

- Separate simulation and rendering.
- Fix patrol collision.
- Improve guard state transitions.
- Add return-to-patrol behaviour.
- Make awareness visible to the player.

[Commandos: Behind Enemy Lines :: Gallery :: DJ OldGames](https://images.openai.com/static-rsc-4/wWvhX5TYxSnQWzWwaOSjQgLgGd3lXHnHa6wRuEpqnMt31Zpvyzs799ZKShjtxWKwEawXllGcnHePmeLzl9BLmYEKabvPcFGowxx-2OKaqEeOPP7IhRiblnqvXlHvYFtX25uHlcvAFqimuAFjIKnShuxqgL5eTJuqJwd-BJ82AiI?purpose=inline)

**Milestone 2 — Tactical stealth**

Player interaction and meaningful choices

- Line-of-sight and occlusion.
- Concealment and cover.
- Crouching or stance changes.
- Distraction mechanics.
- Guard investigation of sounds.

[Commandos: Behind Enemy Lines](https://images.openai.com/static-rsc-4/GdlT3kj4DEbDs5ZJ7cugYhQk6RinMtubQcUelBRLbyo6hfBVtpW9lT7qDZxHp_nVuXNsTfUeyRSOYujzEgwWLbJc79J3X5eAWEiYOO7TNUYbY2I-1vWEQNmpxeHhv7fqM8RVUv9cK876CZN-xzBLHMAQaT3d5WfWwXS16JvH8tI?purpose=inline)

**Milestone 3 — Playable mission**

Actual gameplay loop

- Objective interaction.
- Pick-up and carry documents.
- Extraction detection.
- Mission success/failure.
- Basic mission restart.

[Commandos 2: Men of Courage (Windows) - My Abandonware](https://images.openai.com/static-rsc-4/FdVmseyCe68ODFHP_N9gmV7G1oiKutS7wGSubgTcLCGf-t14vvFXrO4bXTJmS5xo59zSmDXL7fhyl9i_bTuuV-kMP3WweibUp-XDI08w1zGkg0pv-D4mJzWFXR0QW5-OFoc0nlDadNo7FJOIzy4iDg865OkaojJkZc0ceYeL4u4?purpose=inline)

**Milestone 4 — Visual identity**

From greybox to atmosphere

- Terrain and environmental materials.
- Lighting and shadows.
- Vegetation and architectural detail.
- Character silhouettes and animation.
- Atmospheric effects.

[Marble](https://images.openai.com/static-rsc-4/bRXl5egO2q8lqc43EnNXHiFNDWkjglfwHz8LLWe1r_s8waMOD-TfoNYcEGMfVPkkk2N8h7hiSO3jD8AZ5qAs0Zn4twO9Oz586FRqxAFUxH8aMp4ATF97uKDN2ulYthU-_WQ652gFmRJPVPLda2x48lpsrWQ2pYmNWI6ODit-edI?purpose=inline)

**Milestone 5 — Gaussian Splatting renderer**

Introduce the new medium

- Static Gaussian environment rendering.
- OSPZ asset integration.
- Depth and collision compatibility.
- Hybrid Raylib and Gaussian rendering.
- Evaluate 4DGS for animated environments.

## **4. The most important design decision: tactical readability**

I think this is where we should be particularly careful.

The original Commandos games were successful because players could understand the tactical situation.

A guard wasn't just an NPC with a vision cone. He was a predictable but exploitable part of a larger tactical puzzle.

We should eventually expose three distinct layers of information:

| Layer      | What it means                            |
| ---------- | ---------------------------------------- |
| Perception | What the guard can currently see or hear |
| Awareness  | What the guard suspects or knows         |
| Behaviour  | What the guard decides to do             |

These should remain separate systems.

For example, losing sight of the player shouldn't immediately make a guard forget where he was last seen.

Similarly, a suspicious guard shouldn't automatically know where the player is.

That gives us the beginnings of interesting stealth gameplay.

## **5. What I would implement next**

My recommendation is to tackle **Guard Behaviour v2** before introducing new player abilities.

I would break it into four small iterations.

**Iteration 1 — Simulation update refactor**

- Move all state mutation out of rendering.
- Establish a consistent update order.
- Ensure perception updates before guard decisions.
- Keep rendering purely observational.

**Iteration 2 — Complete guard state machine**

I'd introduce these states:

UNAWARE

Normal patrol behaviour

SUSPICIOUS

Investigate unusual activity

ALERTED

Chase last known position and search

SEARCHING

Search area, then return to patrol

UNAWARE

Resume normal patrol

We can retain the current enum initially and add the missing behaviour without prematurely introducing a complicated hierarchical state machine.

**Iteration 3 — Visual perception**

- Vision range.
- Field of view.
- Building and wall occlusion.
- Cover occlusion.
- Detection accumulation.
- Last-known-position tracking.

**Iteration 4 — Player feedback**

The player should be able to understand the guards' intentions:

- Suspicion indicators.
- Visual awareness feedback.
- Search behaviour.
- Guard facing and attention.
- Eventually, selectable guard inspection.

We should make this playable before adding sound distractions or elaborate animations.

## **6. Architectural direction**

One thing I would establish now is a relatively small separation of responsibilities.

```
commandos/
├── main.odin
├── game.odin
├── player.odin
├── mission.odin
├── collision.odin
├── guards.odin
├── awareness.odin
├── perception.odin
├── navigation.odin
├── interaction.odin
├── rendering.odin
├── isometric/
│   └── iso.odin
├── mission.json
└── *_test.odin
```

This is a target organisation, not a request to restructure everything immediately.

I'd move code into these modules as the corresponding functionality becomes necessary.

In particular, I would keep collision and mission geometry independent of the renderer. That will become very useful when we introduce Gaussian environments.

The renderer should not own the world.

## **7. What about Gaussian Splatting?**

I would deliberately postpone it until Milestone 4, but design the interfaces with it in mind.

The interesting opportunity isn't simply replacing cubes with Gaussian splats.

It's combining:

- Gaussian splats for rich environmental appearance.
- Conventional geometry for collision and navigation.
- Conventional meshes for characters and interactive objects.
- 4D Gaussian Splatting for potentially animated environmental elements.

That hybrid approach could give us the painterly, almost photographic environments we're after without sacrificing the tactical precision that makes Commandos work.

And our existing OSPZ work gives us a potential asset pipeline rather than starting from scratch.

## **8. Immediate next step**

My recommendation

**Let's implement Guard Behaviour v2, starting with the simulation update refactor.**

I'd use the following acceptance criteria:

1. Rendering never modifies gameplay state.
2. Guards cannot walk through mission geometry.
3. Patrols remain deterministic.
4. Guards remember their last known player position.
5. Guards investigate and search.
6. Guards can eventually resume their patrol.
7. All state transitions have automated tests.

Once that's working, we'll have something much more interesting than a greybox environment: a small, functioning stealth simulation.

**One guiding principle for the entire project:** build a game that would be fun with primitive cubes first. Then make those cubes beautiful with Gaussian Splatting.

That's the fastest route to a Commandos-worthy sequel.