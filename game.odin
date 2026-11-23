package main

// Advances the whole simulation by dt. This is the single entry point the
// renderer and the tests both use; it never reads the keyboard.
game_update :: proc(world: ^World, input: Input, dt: f32) {
    if dt <= 0 {
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
}
