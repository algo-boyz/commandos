
package actors

import "core:testing"
import "core:fmt"

import "../mission"

// Central test builder for Guard values. Keep all default field values
// here so future Guard struct changes only need updating in one place.
test_guard :: proc(
    position: mission.Mission_Point = {0, 0},
    facing: mission.Mission_Point = {1, 0},
    awareness: Guard_Awareness = {},
    speed: f32 = 2,
    radius: f32 = GUARD_RADIUS,
    patrol: []mission.Mission_Point = nil,
    target_index: int = 0,
    pause_duration: f32 = GUARD_DEFAULT_PAUSE,
    hearing_threshold: f32 = GUARD_DEFAULT_HEARING_THRESHOLD,
    player_visible: bool = false,
    searching: bool = false,
    search_pause_remaining: f32 = 0,
) -> Guard {
    a := awareness
    if a == {} {
        a = guard_awareness_init()
    }
    behaviour := Guard_Behaviour.PATROL
    if a.state == .ALERTED ||
       (a.state == .SUSPICIOUS && a.last_known_source == .SOUND) {
        behaviour = .INVESTIGATE
    } else if a.state == .RECOVERING {
        behaviour = .RECOVER
    }
    if searching {
        behaviour = .SEARCH
    }
    return Guard{
        position = position,
        facing = facing,
        awareness = a,
        behaviour = behaviour,
        speed = speed,
        radius = radius,
        hearing_threshold = hearing_threshold,
        player_visible = player_visible,
        patrol = Guard_Patrol{
            points = patrol,
            target_index = target_index,
            pause_duration = pause_duration,
        },
        search = Guard_Search{
            active = searching,
            pause_remaining = search_pause_remaining,
        },
    }
}

@(test)
test_alerted_guard_moves_to_last_known_position :: proc(t: ^testing.T) {
    guard := test_guard(awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {10, 0},
        })

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)
    mission := Mission{}

    guard_update(guards, &mission, 1.0)

    testing.expect(t, guards[0].position.x > 0)
    testing.expect(t, guards[0].position.y >= 0)
    testing.expect(
        t,
        !mission.point_collides(
            &mission,
            guards[0].position,
            guards[0].radius,
        ),
    )
}

@(test)
test_alerted_guard_stops_at_last_known_position :: proc(t: ^testing.T) {
    guard := test_guard(awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {1, 0},
        }, speed = 3)

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)
    mission := Mission{}

    guard_update(guards, &mission, 1.0)
    guard_update(guards, &mission, 1.0)

    // The navigation endpoint is the centre of the target grid cell.
    testing.expect(t, guards[0].position.x >= 1)
    testing.expect(t, guards[0].position.x < 2)
    testing.expect(t, guards[0].position.y >= 0)
    testing.expect(t, guards[0].position.y < 1)
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

    guard := test_guard(awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {5, 0},
        }, speed = 1)

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)

    for _ in 0..<20 {
        guard_update(guards, &mission, 0.1)
    }

    testing.expect(t, guards[0].position.x < 2)
}


@(test)
test_alerted_guard_begins_search_at_last_known_position :: proc(t: ^testing.T) {
    guard := test_guard(awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {0, 0},
        })

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)
    mission := Mission{}

    guard_update(guards, &mission, 0.1)

    testing.expect(t, guards[0].search.active)
    testing.expect(t, guards[0].search.pause_remaining > 0)
    testing.expect(t, guards[0].position.x == 0)
}

@(test)
test_alerted_guard_scans_left_and_right :: proc(t: ^testing.T) {
    guard := test_guard(awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {0, 0},
        })

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)
    mission := Mission{}

    guard_update(guards, &mission, 0.1)
    guard_update(guards, &mission, 0.75)
    guard_update(guards, &mission, 0.5)

    testing.expect(t, guards[0].search.active)
    testing.expect(t, guards[0].facing.y < 0)
}

@(test)
test_alerted_guard_enters_recovering_after_search :: proc(t: ^testing.T) {
    guard := test_guard(awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {0, 0},
        }, patrol = []Mission_Point{{5, 0}, {10, 0}})

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)
    lvl := Mission{}

    for _ in 0..<70 {
        guard_update(guards, &lvl, 0.1)
    }

    testing.expect(t, !guards[0].search.active)
    testing.expect(t, guards[0].awareness.state == .RECOVERING)
    testing.expect(t, guards[0].position.x > 0)
    testing.expect(t, guards[0].position.x < 5)
}

@(test)
test_alerted_guard_returns_to_patrol_after_search :: proc(t: ^testing.T) {
    guard := test_guard(awareness = actors.Guard_Awareness{
            state = .ALERTED,
            last_known_position = {0, 0},
            last_known_source = .SIGHT,
        }, patrol = []mission.Mission_Point{{5, 0}, {10, 0}})

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)
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
    guard := test_guard(
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {10, 0},
        },
        searching = true,
        search_pause_remaining = 0.5,
    )

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)
    mission := Mission{}

    guards[0].player_visible = true
    guard_update(guards, &mission, 0.5)

    testing.expect(t, !guards[0].search.active)
    testing.expect(t, guards[0].position.x > 0)
}

@(test)
test_suspicious_guard_moves_to_heard_noise :: proc(t: ^testing.T) {
    guard := test_guard(awareness = Guard_Awareness{
            state = .SUSPICIOUS,
            last_known_position = {10, 0},
            last_known_source = .SOUND,
        })

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)
    mission := Mission{}

    guard_update(guards, &mission, 1.0)

    testing.expect(t, guards[0].position.x > 0)
    testing.expect(t, guards[0].awareness.state == .SUSPICIOUS)
    testing.expect(
        t,
        !mission.point_collides(
            &mission,
            guards[0].position,
            guards[0].radius,
        ),
    )
}

@(test)
test_suspicious_guard_finishes_noise_search_and_resets :: proc(t: ^testing.T) {
    guard := test_guard(awareness = Guard_Awareness{
            state = .SUSPICIOUS,
            last_known_position = {0, 0},
            last_known_source = .SOUND,
        })

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)
    mission := mission.Mission{}

    for _ in 0..<100 {
        guard_update(guards, &mission, 0.1)
    }

    testing.expect(t, guards[0].awareness.state == .UNAWARE)
    testing.expect(t, guards[0].awareness.last_known_source == .NONE)
    testing.expect(t, !guards[0].search.active)
}

@(test)
test_guard_hears_footstep_and_becomes_suspicious :: proc(t: ^testing.T) {
    guard := test_guard(position = {2, 0})
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
    guard := test_guard(position = {20, 0})
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
    guard := test_guard(position = {2, 0}, awareness = Guard_Awareness{
            state = .SUSPICIOUS,
            last_known_position = {4, 5},
            last_known_source = .SIGHT,
        })
    footstep := Noise_Event{
        position = {0, 0},
        radius = 10,
        intensity = 1,
    }

    guard_hear_noise(&guard, footstep)

    testing.expect(t, guard.awareness.last_known_source == .SIGHT)
    testing.expect(t, guard.awareness.last_known_position.x == 4)
    testing.expect(t, guard.awareness.last_known_position.y == 5)
    testing.expect(t, guard.facing.x == 1)
    testing.expect(t, guard.facing.y == 0)
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

    guard := test_guard(
        position = {25, 48},
        patrol = []Mission_Point{
            {25, 48},
            {43.5, 49.5},
        },
        target_index = 1,
        speed = 3.2,
        pause_duration = 1.0,
    )

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)

    reached_waypoint := false

    for _ in 0..<1000 {
        guard_update(guards, &mission, 0.05)

        testing.expect(
            t,
            !mission.point_collides(
                &mission,
                guards[0].position,
                guards[0].radius,
            ),
        )

        if guards[0].patrol.target_index == 0 {
            reached_waypoint = true
            break
        }
    }

    if guards[0].patrol.route.index < len(guards[0].patrol.route.path) {
        next := guards[0].patrol.route.path[guards[0].patrol.route.index]
        fmt.printfln("  next node: %.2f, %.2f", next.x, next.y)
        fmt.printfln("  next node blocked: %v",
            mission.point_collides(&mission, next, guards[0].radius),
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

    guard := test_guard(
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
    )

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)

    reached_waypoint := false

    for _ in 0..<1000 {
        guard_update(guards, &mission, 0.05)

        testing.expect(
            t,
            !mission.point_collides(
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

    guard := test_guard(
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
    )

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)

    for _ in 0..<100 {
        guard_update(guards, &mission, 0.1)
    }

    testing.expect(t, guards[0].awareness.state == .RECOVERING)
    testing.expect(t, guards[0].awareness.suspicion == 1)
    testing.expect(t, guards[0].awareness.last_known_source == .SIGHT)
    testing.expect(t, guards[0].position.x < 20)
}

@(test)
test_alerted_guard_routes_around_building :: proc(t: ^testing.T) {
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

    guard := test_guard(awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {5, 0},
        })

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)

    routed_around := false
    reached_destination_cell := false

    for _ in 0..<500 {
        guard_update(guards, &mission, 0.05)

        testing.expect(
            t,
            !mission.point_collides(
                &mission,
                guards[0].position,
                guards[0].radius,
            ),
        )

        if guards[0].position.y > 1.8 ||
           guards[0].position.y < -1.8 {
            routed_around = true
        }

        if guards[0].position.x >= 5 &&
           guards[0].position.x < 6 &&
           guards[0].position.y >= 0 &&
           guards[0].position.y < 1 {
            reached_destination_cell = true
            break
        }
    }

    testing.expect(t, routed_around)
    testing.expect(t, reached_destination_cell)
}

@(test)
test_alerted_guard_does_not_move_toward_unreachable_target :: proc(
    t: ^testing.T,
) {
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

    guard := test_guard(position = {10.5, 10.5}, awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {30.5, 10.5},
        })

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)

    for _ in 0..<10 {
        guard_update(guards, &mission, 0.1)
    }

    testing.expect(t, guards[0].position.x == 10.5)
    testing.expect(t, guards[0].position.y == 10.5)
    testing.expect(t, guards[0].awareness.state == .ALERTED)
    testing.expect(t, !guards[0].search.active)
}

@(test)
test_guard_turns_toward_heard_noise :: proc(t: ^testing.T) {
    guard := test_guard(position = {2, 2})

    noise := Noise_Event{
        position = {2, 8},
        radius = 10,
        intensity = 1,
    }

    guard_hear_noise(&guard, noise)

    testing.expect(t, guard.awareness.state == .SUSPICIOUS)
    testing.expect(t, guard.awareness.last_known_source == .SOUND)
    testing.expect(t, guard.facing.x == 0)
    testing.expect(t, guard.facing.y == 1)
}

@(test)
test_guard_visible_pursuit_uses_direct_steering :: proc(t: ^testing.T) {
    guard := test_guard(
        position = {0.2, 0.2},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {5.8, 0.2},
            last_known_source = .SIGHT,
        },
        player_visible = true,
    )

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)

    mission := Mission{}

    guard_update(guards, &mission, 0.1)

    testing.expect(t, guards[0].position.x > 0.2)
    testing.expect(t, guards[0].position.y == 0.2)
    testing.expect(t, guards[0].facing.x > 0.99)
    testing.expect(t, !guards[0].investigation.ready)
}

@(test)
test_guard_visible_pursuit_does_not_jitter_when_target_moves :: proc(
    t: ^testing.T,
) {
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

    guard := test_guard(awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {5, 0},
            last_known_source = .SIGHT,
        }, player_visible = true)

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)

    previous_position := guards[0].position
    direction_changes := 0
    previous_direction := 0

    for i in 0..<400 {
        // Move the visible target periodically while the guard pursues.
        if i == 100 {
            guards[0].awareness.last_known_position = {5, 2}
        } else if i == 200 {
            guards[0].awareness.last_known_position = {5, -2}
        } else if i == 300 {
            guards[0].awareness.last_known_position = {7, 0}
        }

        guard_update(guards, &mission, 0.05)

        current := guards[0].position

        testing.expect(
            t,
            !mission.point_collides(
                &mission,
                current,
                guards[0].radius,
            ),
        )

        dx := current.x - previous_position.x
        dy := current.y - previous_position.y

        if dx*dx + dy*dy > 0.000001 {
            direction := 0
            if abs(dx) > abs(dy) {
                direction = 1 if dx > 0 else -1
            } else {
                direction = 2 if dy > 0 else -2
            }

            if previous_direction != 0 &&
               direction != previous_direction {
                direction_changes += 1
            }

            previous_direction = direction
        }

        previous_position = current
    }

    testing.expect(t, direction_changes < 80)
}

@(test)
test_navigation_path_preserves_exact_start_position :: proc(
    t: ^testing.T,
) {
    mission := Mission{}

    start := Mission_Point{0.2, 0.2}
    goal := Mission_Point{5.5, 0.5}

    path := nav_find_path(
        &mission,
        start,
        goal,
        GUARD_RADIUS,
    )
    defer delete(path.points)

    testing.expect(t, path.found)
    testing.expect(t, len(path.points) > 0)

    testing.expect(t, path.points[0].x == start.x)
    testing.expect(t, path.points[0].y == start.y)
}

@(test)
test_guard_visible_pursuit_uses_navigation_around_obstacle :: proc(
    t: ^testing.T,
) {
    mission := Mission{
        buildings = {
            mission.Mission_Rect{
                x = 2,
                y = -1,
                w = 1,
                h = 2,
            },
        },
    }

    guard := test_guard(awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_position = {5, 0},
            last_known_source = .SIGHT,
        }, player_visible = true)

    guards := []Guard{guard}
    defer delete(guards[0].investigation.path)
    defer delete(guards[0].patrol.route.path)

    routed_around := false

    for _ in 0..<500 {
        guard_update(guards, &mission, 0.05)

        testing.expect(
            t,
            !mission.point_collides(
                &mission,
                guards[0].position,
                guards[0].radius,
            ),
        )

        if abs(guards[0].position.y) > 1.5 {
            routed_around = true
            break
        }
    }

    testing.expect(t, routed_around)
}