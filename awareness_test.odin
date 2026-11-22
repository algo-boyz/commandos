
package main

import "core:testing"

@(test)
test_awareness_starts_unaware :: proc(t: ^testing.T) {
    awareness := guard_awareness_init()

    testing.expect(t, awareness.state == .UNAWARE)
    testing.expect(t, awareness.suspicion == 0)
}

@(test)
test_awareness_builds_suspicion :: proc(t: ^testing.T) {
    awareness := guard_awareness_init()

    guard_awareness_update(
        &awareness,
        true,
        {10, 20},
        0.5,
        AWARENESS_DEFAULT,
    )

    testing.expect(t, awareness.state == .SUSPICIOUS)
    testing.expect(t, awareness.suspicion > 0)
    testing.expect(t, awareness.suspicion < 1)
    testing.expect(t, awareness.last_known_player_position.x == 10)
    testing.expect(t, awareness.last_known_player_position.y == 20)
}

@(test)
test_awareness_becomes_alerted :: proc(t: ^testing.T) {
    awareness := guard_awareness_init()

    guard_awareness_update(
        &awareness,
        true,
        {15, 25},
        1.25,
        AWARENESS_DEFAULT,
    )

    testing.expect(t, awareness.state == .ALERTED)
    testing.expect(t, awareness.suspicion == 1)
}

@(test)
test_awareness_decays_to_unaware :: proc(t: ^testing.T) {
    awareness := guard_awareness_init()

    guard_awareness_update(
        &awareness,
        true,
        {10, 20},
        0.5,
        AWARENESS_DEFAULT,
    )

    guard_awareness_update(
        &awareness,
        false,
        {},
        1.0,
        AWARENESS_DEFAULT,
    )

    testing.expect(t, awareness.state == .UNAWARE)
    testing.expect(t, awareness.suspicion == 0)
}

@(test)
test_awareness_alert_persists :: proc(t: ^testing.T) {
    awareness := guard_awareness_init()

    guard_awareness_update(
        &awareness,
        true,
        {15, 25},
        1.25,
        AWARENESS_DEFAULT,
    )

    guard_awareness_update(
        &awareness,
        false,
        {0, 0},
        10.0,
        AWARENESS_DEFAULT,
    )

    testing.expect(t, awareness.state == .ALERTED)
    testing.expect(t, awareness.suspicion == 1)
    testing.expect(t, awareness.last_known_player_position.x == 15)
    testing.expect(t, awareness.last_known_player_position.y == 25)
}
