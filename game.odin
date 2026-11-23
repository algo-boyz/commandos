package main

// How close the player must be to the objective to interact with it.
// Building interiors are solid in the greybox, so this must be large enough
// to reach an objective that sits inside a building from its outer face.
OBJECTIVE_INTERACT_RADIUS :: 4.0

// Advances the whole simulation by dt. This is the single entry point the
// renderer and the tests both use; it never reads the keyboard.
//
// Restart works in any state. Once the mission has an outcome the world is
// frozen until restart.
game_update :: proc(world: ^World, input: Input, dt: f32) {
    if input.restart {
        world_reset(world)
        return
    }

    if dt <= 0 || world.outcome != .PLAYING {
        return
    }

    player := &world.player
    guards := world.guards
    mission := &world.mission

    // 1. Update player movement and deliver emitted footsteps.
    if player_update(player, input, mission, dt) {
        noise := Noise_Event{
            position = {
                player.position.x,
                player.position.z,
            },
            radius = player.footstep_noise_radius,
            intensity = player.footstep_noise_intensity,
        }

        for i in 0..<len(guards) {
            guard_hear_noise(&guards[i], noise)
        }
    }

    // 2. Perception and awareness belong to simulation,
    //    not the rendering pass.
    vision := VISION_DEFAULT
    awareness_config := AWARENESS_DEFAULT
    player_point := Mission_Point{
        player.position.x,
        player.position.z,
    }

    for i in 0..<len(guards) {
        guard := &guards[i]

        sees_player := guard_can_see(
            guard.position,
            guard.facing,
            player_point,
            mission,
            vision,
        )

        guard.player_visible = sees_player

        guard_awareness_update(
            &guard.awareness,
            sees_player,
            player_point,
            dt,
            awareness_config,
        )
    }

    // 3. Behaviour reacts to this frame's perception.
    guard_update(guards, mission, dt)

    // 4. Objective and extraction progression.
    mission_progress_update(world, input)
}

// Completes the objective on interaction, and ends the mission in success
// once the player reaches extraction with the objective complete.
mission_progress_update :: proc(world: ^World, input: Input) {
    mission := &world.mission

    if input.interact &&
       !world.objective_complete &&
       world_player_within(
           world,
           mission.objective.x,
           mission.objective.y,
           OBJECTIVE_INTERACT_RADIUS,
       ) {
        world.objective_complete = true
    }

    if world.objective_complete &&
       mission.extraction.radius > 0 &&
       world_player_within(
           world,
           mission.extraction.x,
           mission.extraction.y,
           mission.extraction.radius,
       ) {
        world.outcome = .SUCCESS
    }
}
