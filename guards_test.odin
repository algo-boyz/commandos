
package main

import "core:testing"
import "core:fmt"

@(test)
test_alerted_guard_moves_to_last_known_position :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        facing = {1, 0},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {10, 0},
        },
        speed = 2,
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    mission := Mission{}

    guard_update(guards, &mission, 1.0)

    testing.expect(t, guards[0].position.x == 2)
    testing.expect(t, guards[0].position.y == 0)
}

@(test)
test_alerted_guard_stops_at_last_known_position :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {1, 0},
        },
        speed = 3,
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    mission := Mission{}

    guard_update(guards, &mission, 1.0)
    guard_update(guards, &mission, 1.0)

    testing.expect(t, guards[0].position.x == 1)
    testing.expect(t, guards[0].position.y == 0)
}

@(test)
test_alerted_guard_cannot_move_through_building :: proc(t: ^testing.T) {
    mission := Mission{
        buildings = {
            Mission_Rect{
                x = 2,
                y = -1,
                w = 1,
                h = 2,
            },
        },
    }

    guard := Guard{
        position = {0, 0},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {5, 0},
        },
        speed = 1,
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}

    for _ in 0..<20 {
        guard_update(guards, &mission, 0.1)
    }

    testing.expect(t, guards[0].position.x < 2)
}


@(test)
test_alerted_guard_begins_search_at_last_known_position :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        facing = {1, 0},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {0, 0},
        },
        speed = 2,
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    mission := Mission{}

    guard_update(guards, &mission, 0.1)

    testing.expect(t, guards[0].searching)
    testing.expect(t, guards[0].search_pause_remaining > 0)
    testing.expect(t, guards[0].position.x == 0)
}

@(test)
test_alerted_guard_scans_left_and_right :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        facing = {1, 0},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {0, 0},
        },
        speed = 2,
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    mission := Mission{}

    guard_update(guards, &mission, 0.1)
    guard_update(guards, &mission, 0.75)
    guard_update(guards, &mission, 0.5)

    testing.expect(t, guards[0].searching)
    testing.expect(t, guards[0].facing.y < 0)
}

@(test)
test_alerted_guard_enters_recovering_after_search :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        facing = {1, 0},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {0, 0},
        },
        speed = 2,
        patrol = []Mission_Point{{5, 0}, {10, 0}},
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    defer delete(guards[0].patrol_path)
    mission := Mission{}

    for _ in 0..<70 {
        guard_update(guards, &mission, 0.1)
    }

    testing.expect(t, !guards[0].searching)
    testing.expect(t, guards[0].awareness.state == .RECOVERING)
    testing.expect(t, guards[0].position.x > 0)
    testing.expect(t, guards[0].position.x < 5)
}

@(test)
test_alerted_guard_returns_to_patrol_after_search :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        facing = {1, 0},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {0, 0},
            last_known_source = .SIGHT,
        },
        speed = 2,
        patrol = []Mission_Point{{5, 0}, {10, 0}},
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    defer delete(guards[0].patrol_path)
    mission := Mission{}

    // Advance until the search transitions into recovery.
    for _ in 0..<100 {
        guard_update(guards, &mission, 0.1)
        if guards[0].awareness.state == .RECOVERING {
            break
        }
    }

    testing.expect(t, guards[0].awareness.state == .RECOVERING)

    // Allow recovery pathfinding to finish across multiple updates.
    for _ in 0..<100 {
        guard_update(guards, &mission, 0.1)

        if guards[0].awareness.state == .UNAWARE {
            break
        }
    }

    testing.expect(t, guards[0].awareness.state == .UNAWARE)
    testing.expect(t, guards[0].awareness.suspicion == 0)
    testing.expect(t, guards[0].awareness.last_known_source == .NONE)
    testing.expect(t, guards[0].position.x == 5)
    testing.expect(t, guards[0].position.y == 0)
}

@(test)
test_alerted_guard_resumes_pursuit_after_reacquisition :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        facing = {1, 0},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {10, 0},
        },
        speed = 2,
        radius = GUARD_RADIUS,
        searching = true,
        search_pause_remaining = 0.5,
    }

    guards := []Guard{guard}
    mission := Mission{}

    guards[0].player_visible = true
    guard_update(guards, &mission, 0.5)

    testing.expect(t, !guards[0].searching)
    testing.expect(t, guards[0].position.x > 0)
}

@(test)
test_suspicious_guard_moves_to_heard_noise :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        facing = {1, 0},
        awareness = Guard_Awareness{
            state = .SUSPICIOUS,
            last_known_position = {10, 0},
            last_known_source = .SOUND,
        },
        speed = 2,
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    mission := Mission{}

    guard_update(guards, &mission, 1.0)

    testing.expect(t, guards[0].position.x == 2)
    testing.expect(t, guards[0].awareness.state == .SUSPICIOUS)
}

@(test)
test_suspicious_guard_finishes_noise_search_and_resets :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        facing = {1, 0},
        awareness = Guard_Awareness{
            state = .SUSPICIOUS,
            last_known_position = {0, 0},
            last_known_source = .SOUND,
        },
        speed = 2,
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    mission := Mission{}

    for _ in 0..<100 {
        guard_update(guards, &mission, 0.1)
    }

    testing.expect(t, guards[0].awareness.state == .UNAWARE)
    testing.expect(t, guards[0].awareness.last_known_source == .NONE)
    testing.expect(t, !guards[0].searching)
}

@(test)
test_guard_hears_footstep_and_becomes_suspicious :: proc(t: ^testing.T) {
    guard := Guard{
        position = {2, 0},
        awareness = guard_awareness_init(),
        hearing_threshold = GUARD_DEFAULT_HEARING_THRESHOLD,
    }
    footstep := Noise_Event{
        position = {0, 0},
        radius = 10,
        intensity = 1,
    }

    guard_hear_noise(&guard, footstep)

    testing.expect(t, guard.awareness.state == .SUSPICIOUS)
    testing.expect(t, guard.awareness.last_known_source == .SOUND)
    testing.expect(t, guard.awareness.last_known_position.x == 0)
    testing.expect(t, guard.awareness.last_known_position.y == 0)
}

@(test)
test_guard_does_not_hear_distant_footstep :: proc(t: ^testing.T) {
    guard := Guard{
        position = {20, 0},
        awareness = guard_awareness_init(),
        hearing_threshold = GUARD_DEFAULT_HEARING_THRESHOLD,
    }
    footstep := Noise_Event{
        position = {0, 0},
        radius = 10,
        intensity = 1,
    }

    guard_hear_noise(&guard, footstep)

    testing.expect(t, guard.awareness.state == .UNAWARE)
    testing.expect(t, guard.awareness.last_known_source == .NONE)
}

@(test)
test_guard_does_not_let_noise_override_visual_position :: proc(t: ^testing.T) {
    guard := Guard{
        position = {2, 0},
        awareness = Guard_Awareness{
            state = .SUSPICIOUS,
            last_known_position = {4, 5},
            last_known_source = .SIGHT,
        },
        hearing_threshold = GUARD_DEFAULT_HEARING_THRESHOLD,
    }
    footstep := Noise_Event{
        position = {0, 0},
        radius = 10,
        intensity = 1,
    }

    guard_hear_noise(&guard, footstep)

    testing.expect(t, guard.awareness.last_known_source == .SIGHT)
    testing.expect(t, guard.awareness.last_known_position.x == 4)
    testing.expect(t, guard.awareness.last_known_position.y == 5)
}

@(test)
test_guard_patrol_routes_around_adjacent_crates :: proc(t: ^testing.T) {
    mission := Mission{
        cover = {
            Mission_Cover{
                kind = "crate",
                x = 33,
                y = 42,
                w = 4,
                h = 3,
            },
            Mission_Cover{
                kind = "crate",
                x = 38,
                y = 45,
                w = 4,
                h = 3,
            },
        },
    }

    guard := Guard{
        position = {25, 48},
        patrol = []Mission_Point{
            {25, 48},
            {43.5, 49.5},
        },
        target_index = 1,
        speed = 3.2,
        pause_duration = 1.0,
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    defer delete(guards[0].patrol_path)

    reached_waypoint := false

    for _ in 0..<1000 {
        guard_update(guards, &mission, 0.05)

        testing.expect(
            t,
            !mission_point_collides(
                &mission,
                guards[0].position,
                guards[0].radius,
            ),
        )

        if guards[0].target_index == 0 {
            reached_waypoint = true
            break
        }
    }

    fmt.println("Guard patrol diagnostic:")
    fmt.printfln("  position: %.2f, %.2f",
        guards[0].position.x,
        guards[0].position.y,
    )
    fmt.printfln("  target_index: %d", guards[0].target_index)
    fmt.printfln("  path_found: %v", guards[0].patrol_path_found)
    fmt.printfln("  path_ready: %v", guards[0].patrol_path_ready)
    fmt.printfln("  path_index: %d / %d",
        guards[0].patrol_path_index,
        len(guards[0].patrol_path),
    )
        fmt.printfln("  path_ready: %v", guards[0].patrol_path_ready)
    fmt.printfln("  path_index: %d / %d",
        guards[0].patrol_path_index,
        len(guards[0].patrol_path),
    )

    if guards[0].patrol_path_index < len(guards[0].patrol_path) {
        next := guards[0].patrol_path[guards[0].patrol_path_index]
        fmt.printfln("  next node: %.2f, %.2f", next.x, next.y)
        fmt.printfln("  next node blocked: %v",
            mission_point_collides(&mission, next, guards[0].radius),
        )
    }
    testing.expect(t, reached_waypoint)
}


@(test)
test_guard_recovery_routes_around_building :: proc(t: ^testing.T) {
    mission := Mission{
        buildings = {
            Mission_Rect{
                x = 12,
                y = 10,
                w = 5,
                h = 5,
            },
        },
    }

    guard := Guard{
        position = {10.5, 12.5},
        awareness = Guard_Awareness{
            state = .RECOVERING,
            suspicion = 1,
            last_known_source = .SIGHT,
        },
        patrol = []Mission_Point{
            {10.5, 12.5},
            {18.5, 12.5},
        },
        target_index = 1,
        speed = 3.5,
        pause_duration = 1,
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    defer delete(guards[0].patrol_path)

    reached_waypoint := false

    for _ in 0..<1000 {
        guard_update(guards, &mission, 0.05)

        testing.expect(
            t,
            !mission_point_collides(
                &mission,
                guards[0].position,
                guards[0].radius,
            ),
        )

        if guards[0].awareness.state == .UNAWARE {
            reached_waypoint = true
            break
        }
    }

    testing.expect(t, reached_waypoint)
    testing.expect(t, guards[0].position.x == 18.5)
    testing.expect(t, guards[0].position.y == 12.5)
    testing.expect(t, guards[0].awareness.suspicion == 0)
    testing.expect(t, guards[0].awareness.last_known_source == .NONE)
}


@(test)
test_guard_recovery_does_not_reset_when_path_unreachable :: proc(t: ^testing.T) {
    mission := Mission{
        buildings = {
            Mission_Rect{
                x = 20,
                y = 0,
                w = 2,
                h = 100,
            },
        },
    }

    guard := Guard{
        position = {10.5, 10.5},
        awareness = Guard_Awareness{
            state = .RECOVERING,
            suspicion = 1,
            last_known_source = .SIGHT,
        },
        patrol = []Mission_Point{
            {10.5, 10.5},
            {30.5, 10.5},
        },
        target_index = 1,
        speed = 3.5,
        pause_duration = 1,
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    defer delete(guards[0].patrol_path)

    for _ in 0..<100 {
        guard_update(guards, &mission, 0.1)
    }

    testing.expect(t, guards[0].awareness.state == .RECOVERING)
    testing.expect(t, guards[0].awareness.suspicion == 1)
    testing.expect(t, guards[0].awareness.last_known_source == .SIGHT)
    testing.expect(t, guards[0].position.x < 20)
}
