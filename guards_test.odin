
package main

import "core:testing"

@(test)
test_alerted_guard_moves_to_last_known_position :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        facing = {1, 0},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_player_position = {10, 0},
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
            last_known_player_position = {1, 0},
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
            last_known_player_position = {5, 0},
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
            last_known_player_position = {0, 0},
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
            last_known_player_position = {0, 0},
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
test_alerted_guard_stays_alerted_after_search :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        facing = {1, 0},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_player_position = {0, 0},
        },
        speed = 2,
        radius = GUARD_RADIUS,
    }

    guards := []Guard{guard}
    mission := Mission{}

    for _ in 0..<60 {
        guard_update(guards, &mission, 0.1)
    }

    testing.expect(t, !guards[0].searching)
    testing.expect(t, guards[0].awareness.state == .ALERTED)
    testing.expect(t, guards[0].position.x == 0)
    testing.expect(t, guards[0].position.y == 0)
}

@(test)
test_alerted_guard_resumes_pursuit_after_reacquisition :: proc(t: ^testing.T) {
    guard := Guard{
        position = {0, 0},
        facing = {1, 0},
        awareness = Guard_Awareness{
            state = .ALERTED,
            last_known_player_position = {10, 0},
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
