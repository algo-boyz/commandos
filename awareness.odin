
package main

Guard_Awareness_State :: enum u8 {
    UNAWARE,
    SUSPICIOUS,
    ALERTED,
}

Guard_Awareness :: struct {
    state: Guard_Awareness_State,
    suspicion: f32,
    last_known_player_position: Mission_Point,
}

Awareness_Config :: struct {
    build_duration: f32,
    decay_duration: f32,
}

AWARENESS_DEFAULT :: Awareness_Config{
    build_duration = 1.25,
    decay_duration = 2.0,
}

guard_awareness_init :: proc() -> Guard_Awareness {
    return Guard_Awareness{
        state = .UNAWARE,
        suspicion = 0,
    }
}

// Updates one guard's awareness state.
//
// Suspicion builds while the player is visible and decays while hidden.
// ALERTED is persistent in this iteration.
guard_awareness_update :: proc(
    awareness: ^Guard_Awareness,
    sees_player: bool,
    player_position: Mission_Point,
    dt: f32,
    config: Awareness_Config,
) {
    if dt <= 0 || awareness.state == .ALERTED {
        return
    }

    if sees_player {
        awareness.last_known_player_position = player_position

        if config.build_duration <= 0 {
            awareness.suspicion = 1
        } else {
            awareness.suspicion += dt / config.build_duration
        }

        if awareness.suspicion >= 1 {
            awareness.suspicion = 1
            awareness.state = .ALERTED
        } else {
            awareness.state = .SUSPICIOUS
        }
    } else {
        if config.decay_duration <= 0 {
            awareness.suspicion = 0
        } else {
            awareness.suspicion -= dt / config.decay_duration
        }

        if awareness.suspicion <= 0 {
            awareness.suspicion = 0
            awareness.state = .UNAWARE
        } else {
            awareness.state = .SUSPICIOUS
        }
    }
}
