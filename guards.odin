package main

import "core:math"

Guard :: struct {
    id: string,
    position: Mission_Point,
    facing: Mission_Point,
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
    patrol: []Mission_Point,
    patrol_path: []Mission_Point,
    patrol_path_index: int,
    patrol_path_target_index: int,
    patrol_path_ready: bool,
    patrol_path_found: bool,
    investigation_path: []Mission_Point,
    investigation_path_index: int,
    investigation_path_goal_x: int,
    investigation_path_goal_y: int,
    investigation_path_ready: bool,
    investigation_path_found: bool,
}

GUARD_DEFAULT_SPEED :: 3.5
GUARD_DEFAULT_PAUSE :: 1.0
GUARD_RADIUS :: 0.8
GUARD_DEFAULT_HEARING_THRESHOLD :: 0.2
GUARD_SEARCH_PAUSE :: 0.75
GUARD_SEARCH_HALF_ANGLE :: 1.2217305
GUARD_SEARCH_ANGULAR_SPEED :: 1.5707963
GUARD_SEARCH_SWEEPS :: 2

guard_patrol_path_clear :: proc(guard: ^Guard) {
    delete(guard.patrol_path)
    guard.patrol_path = nil
    guard.patrol_path_index = 0
    guard.patrol_path_ready = false
    guard.patrol_path_found = false
}

guard_investigation_path_clear :: proc(guard: ^Guard) {
    delete(guard.investigation_path)
    guard.investigation_path = nil
    guard.investigation_path_index = 0
    guard.investigation_path_ready = false
    guard.investigation_path_found = false
}

guard_investigation_path_prepare :: proc(
    guard: ^Guard,
    mission: ^Mission,
    target: Mission_Point,
) {
    goal_x := int(target.x)
    goal_y := int(target.y)

    if guard.investigation_path_ready &&
       guard.investigation_path_goal_x == goal_x &&
       guard.investigation_path_goal_y == goal_y {
        return
    }

    guard_investigation_path_clear(guard)

    guard.investigation_path_goal_x = goal_x
    guard.investigation_path_goal_y = goal_y
    guard.investigation_path_ready = true

    path := nav_find_path(
        mission,
        guard.position,
        target,
        guard.radius,
    )

    guard.investigation_path = path.points
    guard.investigation_path_index = 0
    guard.investigation_path_found = path.found
}

guard_patrol_path_prepare :: proc(
    guard: ^Guard,
    mission: ^Mission,
) {
    if guard.patrol_path_ready &&
       guard.patrol_path_target_index == guard.target_index {
        return
    }

    guard_patrol_path_clear(guard)

    if guard.target_index < 0 ||
       guard.target_index >= len(guard.patrol) {
        return
    }

    path := nav_find_path(
        mission,
        guard.position,
        guard.patrol[guard.target_index],
        guard.radius,
    )

    guard.patrol_path = path.points
    guard.patrol_path_index = 0
    guard.patrol_path_target_index = guard.target_index
    guard.patrol_path_ready = true
    guard.patrol_path_found = path.found
}

guard_patrol_update :: proc(
    guard: ^Guard,
    mission: ^Mission,
    dt: f32,
) {
    if dt <= 0 || guard.speed <= 0 {
        return
    }

    remaining_time := dt

    for remaining_time > 0 {
        if guard.pause_remaining > 0 {
            consumed := min(remaining_time, guard.pause_remaining)
            guard.pause_remaining -= consumed
            remaining_time -= consumed

            if remaining_time <= 0 {
                break
            }
        }

        guard_patrol_path_prepare(guard, mission)

        if !guard.patrol_path_found {
            return
        }

        if guard.patrol_path_index >= len(guard.patrol_path) {
            guard_arrive(guard)
            continue
        }

        target := guard.patrol_path[guard.patrol_path_index]

        dx := target.x - guard.position.x
        dy := target.y - guard.position.y
        distance := math.sqrt(dx*dx + dy*dy)

        if distance <= 0.0001 {
            guard.patrol_path_index += 1
            continue
        }

        step := min(guard.speed * remaining_time, distance)
        direction := Mission_Point{
            x = dx / distance,
            y = dy / distance,
        }

        candidate := Mission_Point{
            x = guard.position.x + direction.x * step,
            y = guard.position.y + direction.y * step,
        }

        // Keep collision detection as a final safety check.
        if mission_point_collides(mission, candidate, guard.radius) {
            guard_patrol_path_clear(guard)
            return
        }

        guard.position = candidate
        guard.facing = direction

        remaining_time -= step / guard.speed

        if step >= distance {
            guard.patrol_path_index += 1
        }
    }
}

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


guard_recovery_begin :: proc(guard: ^Guard) {
    guard_investigation_path_clear(guard)

    if len(guard.patrol) == 0 {
        guard.awareness.state = .UNAWARE
        guard.awareness.suspicion = 0
        guard.awareness.last_known_source = .NONE
        guard.search_complete = false
        return
    }

    dx := guard.patrol[0].x - guard.position.x
    dy := guard.patrol[0].y - guard.position.y
    nearest_distance := dx*dx + dy*dy
    nearest_index := 0

    for i in 1..<len(guard.patrol) {
        dx = guard.patrol[i].x - guard.position.x
        dy = guard.patrol[i].y - guard.position.y
        distance := dx*dx + dy*dy
        if distance < nearest_distance {
            nearest_distance = distance
            nearest_index = i
        }
    }

    guard.target_index = nearest_index
    guard_patrol_path_clear(guard)
    guard.search_complete = false
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

    guard_patrol_path_clear(guard)

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

    // Reacquisition cancels the search. Awareness has already
    // refreshed the last-known position.
    if guard.player_visible {
        guard.searching = false
        guard.search_complete = false
        guard.search_pause_remaining = 0
        guard.search_sweeps_completed = 0
    }

    guard_investigation_path_prepare(guard, mission, target)

    dx_to_target := target.x - guard.position.x
    dy_to_target := target.y - guard.position.y
    distance_to_target := math.sqrt(
        dx_to_target*dx_to_target +
        dy_to_target*dy_to_target,
    )

    if distance_to_target <= 0.15 {
        guard.investigation_path_index = len(
            guard.investigation_path,
        )
    }

    // Do not search or recover if the destination cannot be reached.
    if !guard.investigation_path_found {
        return
    }

    remaining_time := dt

    for remaining_time > 0 {
        // Reaching the final cell centre means the guard has reached
        // the investigation area. A* paths terminate at cell centres.
        if guard.investigation_path_index >=
           len(guard.investigation_path) {
            if guard.player_visible {
                return
            }

            if !guard.searching && !guard.search_complete {
                guard_search_begin(guard)
            }

            if guard.searching {
                guard_search_update(guard, remaining_time)

                if guard.search_complete &&
                   guard.awareness.state == .SUSPICIOUS &&
                   guard.awareness.last_known_source == .SOUND {
                    guard.awareness.state = .UNAWARE
                    guard.awareness.suspicion = 0
                    guard.awareness.last_known_source = .NONE
                    guard.search_complete = false
                    guard_investigation_path_clear(guard)
                } else if guard.search_complete &&
                          guard.awareness.state == .ALERTED {
                    guard.awareness.state = .RECOVERING
                    guard_recovery_begin(guard)
                    guard_investigation_path_clear(guard)
                }
            }

            return
        }

        waypoint := guard.investigation_path[
            guard.investigation_path_index
        ]

        dx := waypoint.x - guard.position.x
        dy := waypoint.y - guard.position.y
        distance := math.sqrt(dx*dx + dy*dy)

        if distance <= 0.0001 {
            guard.investigation_path_index += 1
            continue
        }

        step := min(guard.speed * remaining_time, distance)

        direction := Mission_Point{
            x = dx / distance,
            y = dy / distance,
        }

        candidate := Mission_Point{
            x = guard.position.x + direction.x * step,
            y = guard.position.y + direction.y * step,
        }

        // Final collision safety check. If the route is no longer
        // usable, discard it and let the next update replan.
        if mission_point_collides(mission, candidate, guard.radius) {
            guard_investigation_path_clear(guard)
            return
        }

        guard.position = candidate
        guard.facing = direction

        remaining_time -= step / guard.speed

        if step >= distance {
            guard.investigation_path_index += 1
        }
    }
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
    
    // Only turn toward noise if it became the active investigation target.
    if guard.awareness.last_known_source == .SOUND &&
       guard.awareness.last_known_position.x == noise.position.x &&
       guard.awareness.last_known_position.y == noise.position.y {
        dx := noise.position.x - guard.position.x
        dy := noise.position.y - guard.position.y
        direction_length := math.sqrt(dx*dx + dy*dy)

        if direction_length > 0.0001 {
            guard.facing = {
                dx / direction_length,
                dy / direction_length,
            }
        }
    }

    guard.facing = {
        noise.position.x - guard.position.x,
        noise.position.y - guard.position.y,
    }

    direction_length := math.sqrt(
        guard.facing.x*guard.facing.x +
        guard.facing.y*guard.facing.y,
    )

    if direction_length > 0.0001 {
        guard.facing.x /= direction_length
        guard.facing.y /= direction_length
    }

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

guard_recover_update :: proc(
    guard: ^Guard,
    mission: ^Mission,
    dt: f32,
) {
    if dt <= 0 || guard.speed <= 0 {
        return
    }

    if len(guard.patrol) == 0 {
        guard.awareness.state = .UNAWARE
        guard.awareness.suspicion = 0
        guard.awareness.last_known_source = .NONE
        guard_patrol_path_clear(guard)
        return
    }

    guard_patrol_path_prepare(guard, mission)

    if !guard.patrol_path_found {
        return
    }

    remaining_time := dt

    for remaining_time > 0 {
        if guard.patrol_path_index >= len(guard.patrol_path) {
            target := guard.patrol[guard.target_index]

            guard.position = target
            guard.target_index = (guard.target_index + 1) % len(guard.patrol)
            guard.pause_remaining = guard.pause_duration

            guard.awareness.state = .UNAWARE
            guard.awareness.suspicion = 0
            guard.awareness.last_known_source = .NONE

            guard_patrol_path_clear(guard)
            return
        }

        target := guard.patrol_path[guard.patrol_path_index]

        dx := target.x - guard.position.x
        dy := target.y - guard.position.y
        distance := math.sqrt(dx*dx + dy*dy)

        if distance <= 0.0001 {
            guard.patrol_path_index += 1
            continue
        }

        step := min(guard.speed * remaining_time, distance)

        direction := Mission_Point{
            x = dx / distance,
            y = dy / distance,
        }

        candidate := Mission_Point{
            x = guard.position.x + direction.x * step,
            y = guard.position.y + direction.y * step,
        }

        if mission_point_collides(mission, candidate, guard.radius) {
            guard_patrol_path_clear(guard)
            return
        }

        guard.position = candidate
        guard.facing = direction

        remaining_time -= step / guard.speed

        if step >= distance {
            guard.patrol_path_index += 1
        }
    }
}

guard_update :: proc(guards: []Guard, mission: ^Mission, dt: f32) {
    if dt <= 0 {
        return
    }

    for i in 0..<len(guards) {
        guard := &guards[i]

        if guard.awareness.state == .RECOVERING {
            guard_recover_update(guard, mission, dt)
            continue
        }

        if guard.awareness.state == .ALERTED ||
           (guard.awareness.state == .SUSPICIOUS &&
            guard.awareness.last_known_source == .SOUND) {
            guard_investigate_update(guard, mission, dt)
            continue
        }

        if len(guard.patrol) < 2 || guard.speed <= 0 {
            continue
        }

        guard_patrol_update(guard, mission, dt)
    }
}

guards_destroy :: proc(guards: []Guard) {
    for guard in guards {
        delete(guard.patrol_path)
        delete(guard.investigation_path)
    }

    delete(guards)
}