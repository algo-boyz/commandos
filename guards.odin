package main

import "core:math"

Guard :: struct {
    id: string,
    position: Mission_Point,
    facing: Mission_Point,
    patrol: []Mission_Point,
    awareness: Guard_Awareness,
    target_index: int,
    speed: f32,
    pause_duration: f32,
    pause_remaining: f32,
    radius: f32,
    hearing_threshold: f32,
    player_visible: bool,
    searching: bool,
    search_pause_remaining: f32,
    search_base_facing: Mission_Point,
    search_angle: f32,
    search_direction: f32,
    search_sweeps_completed: int,
    search_complete: bool,
}

GUARD_DEFAULT_SPEED :: 3.5
GUARD_DEFAULT_PAUSE :: 1.0
GUARD_RADIUS :: 0.8
GUARD_DEFAULT_HEARING_THRESHOLD :: 0.2
GUARD_SEARCH_PAUSE :: 0.75
GUARD_SEARCH_HALF_ANGLE :: 1.2217305
GUARD_SEARCH_ANGULAR_SPEED :: 1.5707963
GUARD_SEARCH_SWEEPS :: 2

guard_search_begin :: proc(guard: ^Guard) {
    guard.searching = true
    guard.search_pause_remaining = GUARD_SEARCH_PAUSE
    guard.search_base_facing = guard.facing
    guard.search_angle = 0
    guard.search_direction = -1
    guard.search_sweeps_completed = 0
    guard.search_complete = false
}

guard_search_update :: proc(guard: ^Guard, dt: f32) {
    if !guard.searching || dt <= 0 {
        return
    }

    if guard.search_pause_remaining > 0 {
        guard.search_pause_remaining = max(
            0,
            guard.search_pause_remaining - dt,
        )
        return
    }

    guard.search_angle +=
        guard.search_direction * GUARD_SEARCH_ANGULAR_SPEED * dt

    if guard.search_angle <= -GUARD_SEARCH_HALF_ANGLE {
        guard.search_angle = -GUARD_SEARCH_HALF_ANGLE
        guard.search_direction = 1
    } else if guard.search_angle >= GUARD_SEARCH_HALF_ANGLE {
        guard.search_angle = GUARD_SEARCH_HALF_ANGLE
        guard.search_direction = -1
        guard.search_sweeps_completed += 1

        if guard.search_sweeps_completed >= GUARD_SEARCH_SWEEPS {
            guard.searching = false
            guard.search_complete = true
            guard.facing = guard.search_base_facing
            return
        }
    }

    c := math.cos(guard.search_angle)
    s := math.sin(guard.search_angle)
    guard.facing = {
        guard.search_base_facing.x*c - guard.search_base_facing.y*s,
        guard.search_base_facing.x*s + guard.search_base_facing.y*c,
    }
}

guards_init :: proc(mission: ^Mission) -> []Guard {
    guards := make([]Guard, len(mission.guards), context.allocator)
    for definition, i in mission.guards {
        speed := definition.speed
        if speed <= 0 {
            speed = GUARD_DEFAULT_SPEED
        }
        pause := definition.pause_duration
        if pause < 0 {
            pause = GUARD_DEFAULT_PAUSE
        }
        position := Mission_Point{}
        if len(definition.patrol) > 0 {
            position = definition.patrol[0]
        }
        target_index := 0
        if len(definition.patrol) > 1 {
            target_index = 1
        }
        guards[i] = Guard{
            id = definition.id,
            position = position,
            facing = {1, 0},
            patrol = definition.patrol,
            awareness = guard_awareness_init(),
            target_index = target_index,
            speed = speed,
            pause_duration = pause,
            radius = GUARD_RADIUS,
            hearing_threshold = GUARD_DEFAULT_HEARING_THRESHOLD,
        }
    }
    return guards
}

guard_arrive :: proc(guard: ^Guard) {
    if len(guard.patrol) == 0 {
        return
    }
    guard.position = guard.patrol[guard.target_index]
    guard.target_index = (guard.target_index + 1) % len(guard.patrol)
    guard.pause_remaining = guard.pause_duration
}


guard_investigate_update :: proc(
    guard: ^Guard,
    mission: ^Mission,
    dt: f32,
) {
    if dt <= 0 || guard.speed <= 0 {
        return
    }

    target := guard.awareness.last_known_position

    dx := target.x - guard.position.x
    dy := target.y - guard.position.y
    distance := math.sqrt(dx*dx + dy*dy)

    // Reacquisition cancels the search. The awareness system has
    // already refreshed the last-known position.
    if guard.player_visible {
        guard.searching = false
        guard.search_complete = false
        guard.search_pause_remaining = 0
        guard.search_sweeps_completed = 0
    }

    // Reached the last-known position: pause and scan.
    if distance <= 0.15 {
        if !guard.player_visible {
            if !guard.searching && !guard.search_complete {
                guard_search_begin(guard)
            }

            if guard.searching {
                guard_search_update(guard, dt)

                // A sound investigation ends after the guard has
                // searched the reported location.
                if guard.search_complete &&
                    guard.awareness.state == .SUSPICIOUS &&
                    guard.awareness.last_known_source == .SOUND {
                    guard.awareness.state = .UNAWARE
                    guard.awareness.suspicion = 0
                    guard.awareness.last_known_source = .NONE
                    guard.search_complete = false
                }
            }
        }
        return
    }
    // The target changed after reacquisition; resume pursuit.
    guard.searching = false
    guard.search_complete = false
    guard.search_pause_remaining = 0

    step := min(guard.speed * dt, distance)
    direction_x := dx / distance
    direction_y := dy / distance

    // Resolve X and Y independently to allow sliding along obstacles.
    candidate := Mission_Point{
        x = guard.position.x + direction_x * step,
        y = guard.position.y,
    }

    if !mission_point_collides(mission, candidate, guard.radius) {
        guard.position.x = candidate.x
    }

    candidate = Mission_Point{
        x = guard.position.x,
        y = guard.position.y + direction_y * step,
    }

    if !mission_point_collides(mission, candidate, guard.radius) {
        guard.position.y = candidate.y
    }

    guard.facing = {direction_x, direction_y}
}

guard_hear_noise :: proc(guard: ^Guard, noise: Noise_Event) {
    if guard.awareness.state == .ALERTED {
        return
    }
    if !guard_can_hear(guard.position, noise, guard.hearing_threshold) {
        return
    }

    previous_source := guard.awareness.last_known_source
    guard_awareness_hear_noise(&guard.awareness, noise.position)

    // A new audible event restarts an unfinished sound search. A visual
    // last-known position is never replaced by a later noise event.
    if guard.awareness.last_known_source == .SOUND &&
       (previous_source != .SOUND ||
        guard.awareness.last_known_position.x != noise.position.x ||
        guard.awareness.last_known_position.y != noise.position.y) {
        guard.searching = false
        guard.search_complete = false
        guard.search_pause_remaining = 0
        guard.search_sweeps_completed = 0
    }
}

guard_update :: proc(guards: []Guard, mission: ^Mission, dt: f32) {
    if dt <= 0 {
        return
    }
    for i in 0..<len(guards) {
        guard := &guards[i]
        if guard.awareness.state == .ALERTED ||
            (guard.awareness.state == .SUSPICIOUS &&
             guard.awareness.last_known_source == .SOUND) {
            guard_investigate_update(guard, mission, dt)
            continue
        }
        if len(guard.patrol) < 2 || guard.speed <= 0 {
            continue
        }
        remaining_time := dt
        // Consume the full frame time, including waypoint and pause boundaries.
        for remaining_time > 0 {
            if guard.pause_remaining > 0 {
                consumed := remaining_time
                if consumed > guard.pause_remaining {
                    consumed = guard.pause_remaining
                }
                guard.pause_remaining -= consumed
                remaining_time -= consumed
                if remaining_time <= 0 {
                    break
                }
            }
            target := guard.patrol[guard.target_index]
            dx := target.x - guard.position.x
            dy := target.y - guard.position.y
            distance := math.sqrt(dx*dx + dy*dy)
            if distance <= 0.0001 {
                guard_arrive(guard)
                // Avoid an infinite loop if a route contains duplicate points.
                if guard.pause_remaining <= 0 {
                    guard.pause_remaining = 0.001
                }
                continue
            }
            travel_time := distance / guard.speed
            if travel_time <= remaining_time {
                guard.position = target
                guard.facing = {dx / distance, dy / distance}
                remaining_time -= travel_time
                guard_arrive(guard)
            } else {
                fraction := (guard.speed * remaining_time) / distance
                guard.position.x += dx * fraction
                guard.position.y += dy * fraction
                guard.facing = {dx / distance, dy / distance}
                remaining_time = 0
            }
        }
    }
}
