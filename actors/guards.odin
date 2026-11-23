package actors

import "../mission"
import "../nav"
import "../geom"
import "core:math"

// ---------------------------------------------------------------------------
// Explicit behaviour: what the guard is *doing*.
// Guard_Awareness_State remains the separate "what it knows" layer.
// ---------------------------------------------------------------------------
Guard_Behaviour :: enum u8 {
    PATROL,
    PURSUE,      // direct steering while the player is visible
    INVESTIGATE, // walking an A* path to last-known position
    SEARCH,      // scanning in place at last-known position
    RECOVER,     // returning to the nearest patrol waypoint
}

// Shared path-walking state used by patrol, investigation and recovery.
Path_Follower :: struct {
    path:  []geom.Point,
    index: int,
    ready: bool,
    found: bool,
    // Investigation tracks the integer goal cell so we can avoid
    // replanning when the target cell has not changed.
    goal_x: int,
    goal_y: int,
}

Guard_Patrol :: struct {
    points:         []geom.Point, // the authored route
    target_index:   int,
    pause_duration: f32,
    pause_remaining: f32,
    route:          Path_Follower,   // current path to the next waypoint
}

Guard_Search :: struct {
    active:            bool,
    complete:          bool,
    pause_remaining:   f32,
    base_facing:       geom.Point,
    angle:             f32,
    direction:         f32,
    sweeps_completed:  int,
}

Guard :: struct {
    id:                 string,
    position:           geom.Point,
    facing:             geom.Point,
    awareness:          Guard_Awareness,
    behaviour:          Guard_Behaviour,
    speed:              f32,
    radius:             f32,
    hearing_threshold:  f32,
    player_visible:     bool,
    pause_duration:     f32 `json:"pauseDuration"`,
    patrol:             Guard_Patrol,
    search:             Guard_Search,
    investigation:      Path_Follower,
}

GUARD_DEFAULT_SPEED :: 3.5
GUARD_DEFAULT_PAUSE :: 1.0
GUARD_RADIUS :: 0.8
GUARD_DEFAULT_HEARING_THRESHOLD :: 0.2
GUARD_SEARCH_PAUSE :: 0.75
GUARD_SEARCH_HALF_ANGLE :: 1.2217305
GUARD_SEARCH_ANGULAR_SPEED :: 1.5707963
GUARD_SEARCH_SWEEPS :: 2

// ---------------------------------------------------------------------------
// Path_Follower helpers
// ---------------------------------------------------------------------------

path_follower_clear :: proc(f: ^Path_Follower) {
    delete(f.path)
    f.path = nil
    f.index = 0
    f.ready = false
    f.found = false
    f.goal_x = 0
    f.goal_y = 0
}

// Advance the guard along the follower for up to `dt` seconds.
// Returns the unused time and whether the path was fully consumed.
// On collision the path is cleared and remaining time is returned.
follow_path :: proc(
    guard: ^Guard,
    follower: ^Path_Follower,
    lvl: ^mission.Mission,
    dt: f32,
) -> (remaining: f32, arrived: bool) {
    remaining = dt
    arrived = false

    if dt <= 0 || guard.speed <= 0 {
        return
    }

    for remaining > 0 {
        if follower.index >= len(follower.path) {
            arrived = true
            return
        }

        target := follower.path[follower.index]
        dx := target.x - guard.position.x
        dy := target.y - guard.position.y
        distance := math.sqrt(dx*dx + dy*dy)

        if distance <= 0.0001 {
            follower.index += 1
            continue
        }

        step := min(guard.speed * remaining, distance)
        direction := geom.Point{
            x = dx / distance,
            y = dy / distance,
        }

        candidate := geom.Point{
            x = guard.position.x + direction.x * step,
            y = guard.position.y + direction.y * step,
        }

        // Final collision safety check. If the route is no longer
        // usable, discard it and let the next update replan.
        if geom.point_collides(lvl, candidate, guard.radius) {
            path_follower_clear(follower)
            return remaining, false
        }

        guard.position = candidate
        guard.facing = direction
        remaining -= step / guard.speed

        if step >= distance {
            follower.index += 1
        }
    }
    return
}

// ---------------------------------------------------------------------------
// Path preparation
// ---------------------------------------------------------------------------

guard_investigation_path_prepare :: proc(
    guard: ^Guard,
    level: ^mission.Mission,
    target: geom.Point,
) {
    // During visible pursuit, finish the current route before
    // considering a new target position.
    if guard.player_visible && guard.investigation.ready {
        return
    }
    goal_x := int(target.x)
    goal_y := int(target.y)

    if guard.investigation.ready &&
       guard.investigation.goal_x == goal_x &&
       guard.investigation.goal_y == goal_y {
        return
    }

    path_follower_clear(&guard.investigation)

    guard.investigation.goal_x = goal_x
    guard.investigation.goal_y = goal_y
    guard.investigation.ready = true

    path := nav.find_path(
        level,
        guard.position,
        target,
        guard.radius,
    )

    guard.investigation.path = path.points
    guard.investigation.index = 0
    guard.investigation.found = path.found
}

guard_patrol_path_prepare :: proc(
    guard: ^Guard,
    level: ^mission.Mission,
) {
    if guard.patrol.route.ready &&
       guard.patrol.route.goal_x == guard.patrol.target_index {
        // We reuse goal_x to store the target_index we planned for.
        return
    }

    path_follower_clear(&guard.patrol.route)

    if guard.patrol.target_index < 0 ||
       guard.patrol.target_index >= len(guard.patrol.points) {
        return
    }

    path := nav.find_path(
        level,
        guard.position,
        guard.patrol.points[guard.patrol.target_index],
        guard.radius,
    )

    guard.patrol.route.path = path.points
    guard.patrol.route.index = 0
    guard.patrol.route.goal_x = guard.patrol.target_index
    guard.patrol.route.ready = true
    guard.patrol.route.found = path.found
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

guard_search_begin :: proc(guard: ^Guard) {
    guard.search.active = true
    guard.search.complete = false
    guard.search.pause_remaining = GUARD_SEARCH_PAUSE
    guard.search.base_facing = guard.facing
    guard.search.angle = 0
    guard.search.direction = -1
    guard.search.sweeps_completed = 0
    guard.behaviour = .SEARCH
}

guard_search_update :: proc(guard: ^Guard, dt: f32) {
    if !guard.search.active || dt <= 0 {
        return
    }

    if guard.search.pause_remaining > 0 {
        guard.search.pause_remaining = max(
            0,
            guard.search.pause_remaining - dt,
        )
        return
    }

    guard.search.angle +=
        guard.search.direction * GUARD_SEARCH_ANGULAR_SPEED * dt

    if guard.search.angle <= -GUARD_SEARCH_HALF_ANGLE {
        guard.search.angle = -GUARD_SEARCH_HALF_ANGLE
        guard.search.direction = 1
    } else if guard.search.angle >= GUARD_SEARCH_HALF_ANGLE {
        guard.search.angle = GUARD_SEARCH_HALF_ANGLE
        guard.search.direction = -1
        guard.search.sweeps_completed += 1

        if guard.search.sweeps_completed >= GUARD_SEARCH_SWEEPS {
            guard.search.active = false
            guard.search.complete = true
            guard.facing = guard.search.base_facing
            return
        }
    }

    c := math.cos(guard.search.angle)
    s := math.sin(guard.search.angle)
    guard.facing = {
        guard.search.base_facing.x*c - guard.search.base_facing.y*s,
        guard.search.base_facing.x*s + guard.search.base_facing.y*c,
    }
}

// ---------------------------------------------------------------------------
// Behaviour transitions
// ---------------------------------------------------------------------------

// Derive (or force) the correct behaviour from awareness + search state.
// Called at the start of each guard_update so the rest of the code can
// switch on a single enum instead of a nest of flags.
guard_sync_behaviour :: proc(guard: ^Guard) {
    if guard.awareness.state == .RECOVERING {
        guard.behaviour = .RECOVER
        return
    }

    if guard.search.active {
        guard.behaviour = .SEARCH
        return
    }

    if guard.awareness.state == .ALERTED {
        if guard.player_visible {
            guard.behaviour = .PURSUE
        } else {
            guard.behaviour = .INVESTIGATE
        }
        return
    }

    if guard.awareness.state == .SUSPICIOUS &&
       guard.awareness.last_known_source == .SOUND {
        guard.behaviour = .INVESTIGATE
        return
    }

    guard.behaviour = .PATROL
}

guard_recovery_begin :: proc(guard: ^Guard) {
    path_follower_clear(&guard.investigation)

    if len(guard.patrol.points) == 0 {
        guard.awareness.state = .UNAWARE
        guard.awareness.suspicion = 0
        guard.awareness.last_known_source = .NONE
        guard.search.complete = false
        guard.behaviour = .PATROL
        return
    }

    dx := guard.patrol.points[0].x - guard.position.x
    dy := guard.patrol.points[0].y - guard.position.y
    nearest_distance := dx*dx + dy*dy
    nearest_index := 0

    for i in 1..<len(guard.patrol.points) {
        dx = guard.patrol.points[i].x - guard.position.x
        dy = guard.patrol.points[i].y - guard.position.y
        distance := dx*dx + dy*dy
        if distance < nearest_distance {
            nearest_distance = distance
            nearest_index = i
        }
    }

    guard.patrol.target_index = nearest_index
    path_follower_clear(&guard.patrol.route)
    guard.search.complete = false
    guard.behaviour = .RECOVER
}

// ---------------------------------------------------------------------------
// Init / destroy
// ---------------------------------------------------------------------------

guards_init :: proc(lvl: ^mission.Mission) -> []Guard {
    guards := make([]Guard, len(lvl.guards), context.allocator)
    for definition, i in lvl.guards {
        speed := definition.speed
        if speed <= 0 {
            speed = GUARD_DEFAULT_SPEED
        }
        pause := definition.pause_duration
        if pause < 0 {
            pause = GUARD_DEFAULT_PAUSE
        }
        position := geom.Point{}
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
            awareness = guard_awareness_init(),
            behaviour = .PATROL,
            speed = speed,
            radius = GUARD_RADIUS,
            hearing_threshold = GUARD_DEFAULT_HEARING_THRESHOLD,
            patrol = Guard_Patrol{
                points = definition.patrol,
                target_index = target_index,
                pause_duration = pause,
            },
        }
    }
    return guards
}

guards_destroy :: proc(guards: []Guard) {
    for guard in guards {
        delete(guard.patrol.route.path)
        delete(guard.investigation.path)
    }
    delete(guards)
}

// ---------------------------------------------------------------------------
// Per-behaviour updates
// ---------------------------------------------------------------------------

guard_arrive :: proc(guard: ^Guard) {
    if len(guard.patrol.points) == 0 {
        return
    }
    path_follower_clear(&guard.patrol.route)
    guard.patrol.target_index =
        (guard.patrol.target_index + 1) % len(guard.patrol.points)
    guard.patrol.pause_remaining = guard.patrol.pause_duration
}

guard_patrol_update :: proc(
    guard: ^Guard,
    lvl: ^mission.Mission,
    dt: f32,
) {
    if dt <= 0 || guard.speed <= 0 {
        return
    }

    remaining_time := dt

    for remaining_time > 0 {
        if guard.patrol.pause_remaining > 0 {
            consumed := min(remaining_time, guard.patrol.pause_remaining)
            guard.patrol.pause_remaining -= consumed
            remaining_time -= consumed
            if remaining_time <= 0 {
                break
            }
        }

        guard_patrol_path_prepare(guard, lvl)

        if !guard.patrol.route.found {
            return
        }

        left, arrived := follow_path(
            guard,
            &guard.patrol.route,
            lvl,
            remaining_time,
        )
        remaining_time = left

        if arrived {
            guard_arrive(guard)
            // continue the loop so any leftover time is spent on the
            // next leg / pause
        } else if !guard.patrol.route.ready {
            // path was cleared by a collision
            return
        }
    }
}

guard_investigate_update :: proc(
    guard: ^Guard,
    lvl: ^mission.Mission,
    dt: f32,
) {
    if dt <= 0 || guard.speed <= 0 {
        return
    }

    target := guard.awareness.last_known_position

    // Visible pursuit uses direct steering when unobstructed.
    if guard.player_visible && !guard.investigation.ready {
        guard.search.active = false
        guard.search.complete = false
        guard.search.pause_remaining = 0
        guard.search.sweeps_completed = 0
        guard.behaviour = .PURSUE

        dx := target.x - guard.position.x
        dy := target.y - guard.position.y
        distance := math.sqrt(dx*dx + dy*dy)

        if distance <= 0.0001 {
            return
        }

        direction := geom.Point{
            x = dx / distance,
            y = dy / distance,
        }
        step := min(guard.speed * dt, distance)
        candidate := geom.Point{
            x = guard.position.x + direction.x * step,
            y = guard.position.y + direction.y * step,
        }

        if !geom.point_collides(lvl, candidate, guard.radius) {
            guard.position = candidate
            guard.facing = direction
            return
        }
        // Blocked → fall through to A* below.
    }

    guard_investigation_path_prepare(guard, lvl, target)

    dx_to_target := target.x - guard.position.x
    dy_to_target := target.y - guard.position.y
    distance_to_target := math.sqrt(
        dx_to_target*dx_to_target +
        dy_to_target*dy_to_target,
    )

    // Snap the path index to the end once we are close enough to the
    // investigation target (A* terminates at cell centres).
    if distance_to_target <= 0.15 {
        guard.investigation.index = len(guard.investigation.path)
    }

    if !guard.investigation.found {
        return
    }

    remaining_time := dt

    for remaining_time > 0 {
        if guard.investigation.index >= len(guard.investigation.path) {
            if guard.player_visible {
                path_follower_clear(&guard.investigation)
                return
            }

            if !guard.search.active && !guard.search.complete {
                guard_search_begin(guard)
            }

            if guard.search.active {
                guard_search_update(guard, remaining_time)

                if guard.search.complete &&
                   guard.awareness.state == .SUSPICIOUS &&
                   guard.awareness.last_known_source == .SOUND {
                    guard.awareness.state = .UNAWARE
                    guard.awareness.suspicion = 0
                    guard.awareness.last_known_source = .NONE
                    guard.search.complete = false
                    path_follower_clear(&guard.investigation)
                    guard.behaviour = .PATROL
                } else if guard.search.complete &&
                          guard.awareness.state == .ALERTED {
                    guard.awareness.state = .RECOVERING
                    guard_recovery_begin(guard)
                    path_follower_clear(&guard.investigation)
                }
            }
            return
        }

        left, _ := follow_path(
            guard,
            &guard.investigation,
            lvl,
            remaining_time,
        )
        remaining_time = left

        if !guard.investigation.ready {
            // cleared by collision
            return
        }
    }
}

guard_recover_update :: proc(
    guard: ^Guard,
    lvl: ^mission.Mission,
    dt: f32,
) {
    if dt <= 0 || guard.speed <= 0 {
        return
    }

    if len(guard.patrol.points) == 0 {
        guard.awareness.state = .UNAWARE
        guard.awareness.suspicion = 0
        guard.awareness.last_known_source = .NONE
        path_follower_clear(&guard.patrol.route)
        guard.behaviour = .PATROL
        return
    }

    guard_patrol_path_prepare(guard, lvl)

    if !guard.patrol.route.found {
        return
    }

    remaining_time := dt

    for remaining_time > 0 {
        if guard.patrol.route.index >= len(guard.patrol.route.path) {
            // Snap onto the patrol point (preserves previous behaviour).
            target := guard.patrol.points[guard.patrol.target_index]
            guard.position = target
            guard.patrol.target_index =
                (guard.patrol.target_index + 1) % len(guard.patrol.points)
            guard.patrol.pause_remaining = guard.patrol.pause_duration

            guard.awareness.state = .UNAWARE
            guard.awareness.suspicion = 0
            guard.awareness.last_known_source = .NONE

            path_follower_clear(&guard.patrol.route)
            guard.behaviour = .PATROL
            return
        }

        left, _ := follow_path(
            guard,
            &guard.patrol.route,
            lvl,
            remaining_time,
        )
        remaining_time = left

        if !guard.patrol.route.ready {
            return
        }
    }
}

// ---------------------------------------------------------------------------
// Hearing
// ---------------------------------------------------------------------------

guard_hear_noise :: proc(guard: ^Guard, noise: Noise_Event) {
    if guard.awareness.state == .ALERTED {
        return
    }

    if !guard_can_hear(guard.position, noise, guard.hearing_threshold) {
        return
    }

    previous_source := guard.awareness.last_known_source

    guard_awareness_hear_noise(&guard.awareness, noise.position)

    // Only face the noise if it became the active investigation target.
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

    // A new audible event restarts an unfinished sound search.
    // A visual last-known position is never replaced by a later noise event.
    if guard.awareness.last_known_source == .SOUND &&
       (previous_source != .SOUND ||
        guard.awareness.last_known_position.x != noise.position.x ||
        guard.awareness.last_known_position.y != noise.position.y) {

        guard.search.active = false
        guard.search.complete = false
        guard.search.pause_remaining = 0
        guard.search.sweeps_completed = 0
    }
}

// ---------------------------------------------------------------------------
// Top-level update
// ---------------------------------------------------------------------------

guard_update :: proc(guards: []Guard, lvl: ^mission.Mission, dt: f32) {
    if dt <= 0 {
        return
    }

    for i in 0..<len(guards) {
        guard := &guards[i]
        guard_sync_behaviour(guard)

        switch guard.behaviour {
        case .RECOVER:
            guard_recover_update(guard, lvl, dt)
        case .PURSUE, .INVESTIGATE, .SEARCH:
            guard_investigate_update(guard, lvl, dt)
        case .PATROL:
            if len(guard.patrol.points) < 2 || guard.speed <= 0 {
                continue
            }
            guard_patrol_update(guard, lvl, dt)
        }
    }
}
