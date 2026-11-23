package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:testing"
import "core:time"

// Navigation timing harness. It is a no-op in a normal `odin test .` run, so
// it adds nothing to the suite. Switch it on to measure nav_find_path before
// deciding whether to optimise it:
//
//   odin test . -o:speed -define:NAV_BENCH=true -define:ODIN_TEST_NAMES=main.bench_navigation -define:ODIN_TEST_THREADS=1
//
// Run it from the repository root so mission.json is found. Use the same -o:
// level you build the game with; unoptimised numbers are several times worse.
//
// Timings are logged, not asserted: this is for reading, not for failing CI.
// Budget to compare against: one frame at 60 FPS is 16.6 ms, and A* is only
// one of several things that share it.
NAV_BENCH :: #config(NAV_BENCH, false)

BENCH_BURST_GUARDS :: 8
BENCH_BURST_FRAMES :: 20

bench_path :: proc(
    t: ^testing.T,
    label: string,
    mission: ^Mission,
    start, goal: Mission_Point,
    radius: f32,
    iterations: int,
) {
    // Warm-up call: bakes lazily-built geometry and touches the allocator, so
    // neither lands in the first measured run.
    warm := nav_find_path(mission, start, goal, radius)
    found := warm.found
    delete(warm.points)

    total_us: f64
    min_us: f64 = 1e18
    max_us: f64

    for _ in 0..<iterations {
        began := time.tick_now()
        path := nav_find_path(mission, start, goal, radius)
        us := time.duration_microseconds(time.tick_since(began))

        total_us += us
        min_us = min(min_us, us)
        max_us = max(max_us, us)
        delete(path.points)
    }

    fmt.printf(
        "nav bench | %s | found=%v | avg %.1f us | min %.1f us | max %.1f us | %d runs\n",
        label, found, total_us / f64(iterations), min_us, max_us, iterations,
    )
}

// Several guards replanning in the same frame, repeated over several frames.
// This is the situation the README's "optimise only if profiling shows it"
// caveat is really about, so report it as milliseconds per frame.
bench_burst :: proc(
    t: ^testing.T,
    label: string,
    mission: ^Mission,
    start, goal: Mission_Point,
    radius: f32,
) {
    total_ms: f64
    worst_ms: f64

    for _ in 0..<BENCH_BURST_FRAMES {
        began := time.tick_now()
        for _ in 0..<BENCH_BURST_GUARDS {
            path := nav_find_path(mission, start, goal, radius)
            delete(path.points)
        }
        ms := time.duration_milliseconds(time.tick_since(began))

        total_ms += ms
        worst_ms = max(worst_ms, ms)
    }

    fmt.printf(
        "nav bench | %s | %d paths per frame | avg %.2f ms/frame | worst %.2f ms/frame | budget 16.6 ms\n",
        label, BENCH_BURST_GUARDS,
        total_ms / f64(BENCH_BURST_FRAMES), worst_ms,
    )
}

bench_nearest_open_cell :: proc(
    mission: ^Mission,
    target: Mission_Point,
    radius: f32,
) -> (Mission_Point, bool) {
    grid_w, grid_h := nav_grid_dims(mission)
    best := target
    best_dist_sq: f32 = 1e30
    found := false

    for y in 0..<grid_h {
        for x in 0..<grid_w {
            candidate := nav_cell_center(x, y)

            if mission_point_collides(mission, candidate, radius) {
                continue
            }

            dx := candidate.x - target.x
            dy := candidate.y - target.y
            dist_sq := dx*dx + dy*dy

            if dist_sq < best_dist_sq {
                best_dist_sq = dist_sq
                best = candidate
                found = true
            }
        }
    }

    return best, found
}

@(test)
bench_navigation :: proc(t: ^testing.T) {
    if !NAV_BENCH {
        return
    }

    agent_radius := player_init({}).radius

    // Real mission. Loaded into a scratch arena so the runner's leak tracker
    // stays quiet; the searches themselves run on the normal allocator,
    // because every A* call allocates and then frees about 140 KB.
    outer := context.allocator
    backing := make([]byte, 8 * 1024 * 1024, outer)
    defer delete(backing, outer)

    arena: mem.Arena
    mem.arena_init(&arena, backing)
    context.allocator = mem.arena_allocator(&arena)

    mission, loaded := mission_load("mission.json")
    context.allocator = outer

    testing.expect(
        t,
        loaded,
        "could not load mission.json; run the tests from the repository root",
    )
    if !loaded {
        return
    }

    grid_w, grid_h := nav_grid_dims(&mission)
    fmt.printf(
        "nav bench | mission.json | grid %dx%d = %d cells | %d solid rects | %d solid circles\n",
        grid_w, grid_h, grid_w * grid_h,
        len(mission.geometry.solids), len(mission.geometry.circles),
    )

    extraction_center := Mission_Point{
        mission.extraction.x,
        mission.extraction.y,
    }

    extraction_target, target_valid := bench_nearest_open_cell(
        &mission,
        extraction_center,
        agent_radius,
    )

    testing.expect(t, target_valid, "no open cell found near extraction")
    if !target_valid {
        return
    }

    target_dx := extraction_target.x - extraction_center.x
    target_dy := extraction_target.y - extraction_center.y
    target_distance := math.sqrt(target_dx*target_dx + target_dy*target_dy)

    fmt.printf(
        "nav bench | mission.json | grid %dx%d = %d cells | %d solid rects | %d solid circles\n",
        grid_w, grid_h, grid_w * grid_h,
        len(mission.geometry.solids), len(mission.geometry.circles),
    )

    bench_path(
        t, "mission.json spawn -> extraction (long route)",
        &mission, mission.player_spawn, extraction_target, agent_radius, 20,
    )

    // A guard's short patrol leg, which is the common replan.
    for guard_def in mission.guards {
        if len(guard_def.patrol) >= 2 {
            bench_path(
                t, "mission.json first guard patrol leg (short route)",
                &mission, guard_def.patrol[0], guard_def.patrol[1], agent_radius, 50,
            )
            break
        }
    }

    bench_burst(
        t, "mission.json burst, spawn -> extraction",
        &mission, mission.player_spawn, extraction_target, agent_radius,
    )

    // Empty 100x100 map, opposite corners: no obstacles, so this isolates
    // the cost of the open-set scan from the cost of collision queries.
    {
        empty := Mission{}
        defer mission_geometry_destroy(&empty.geometry)

        bench_path(
            t, "empty map corner -> corner",
            &empty, {0.5, 0.5}, {99.5, 99.5}, agent_radius, 20,
        )
    }

    // Worst case for any A*: the goal is open but walled in, so the search
    // cannot find it and expands every reachable cell before giving up.
    // Guards hit this when a target is unreachable.
    {
        sealed := Mission{
            walls = {
                Mission_Wall{x = 85, y = 85, w = 10, h = 1},
                Mission_Wall{x = 85, y = 94, w = 10, h = 1},
                Mission_Wall{x = 85, y = 85, w = 1,  h = 10},
                Mission_Wall{x = 94, y = 85, w = 1,  h = 10},
            },
        }
        defer mission_geometry_destroy(&sealed.geometry)

        bench_path(
            t, "sealed goal (unreachable, full-grid expansion)",
            &sealed, {5.5, 5.5}, {90.5, 90.5}, agent_radius, 10,
        )
    }
}
