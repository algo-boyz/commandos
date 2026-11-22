package main

import "core:math"

Guard :: struct {
    id: string,
    position: Mission_Point,
    facing: Mission_Point,
    patrol: []Mission_Point,
    target_index: int,
    speed: f32,
    pause_duration: f32,
    pause_remaining: f32,
    radius: f32,
}

GUARD_DEFAULT_SPEED :: 3.5
GUARD_DEFAULT_PAUSE :: 1.0
GUARD_RADIUS :: 0.8

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
            target_index = target_index,
            speed = speed,
            pause_duration = pause,
            radius = GUARD_RADIUS,
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

guard_update :: proc(guards: []Guard, dt: f32) {
    if dt <= 0 {
        return
    }
    for i in 0..<len(guards) {
        guard := &guards[i]
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
