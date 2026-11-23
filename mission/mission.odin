package mission

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"

import "../geom"

MISSION_DEFAULT_BOUNDS :: geom.Bounds{width = 100, height = 100}

Outcome :: enum u8 {
    PLAYING,
    SUCCESS,
    // A guard touched the player.
    FAILED,
}

// A retrieve-style objective: the player completes it by interacting while
// within OBJECTIVE_INTERACT_RADIUS of (x, y). An empty id means the mission
// has no objective and extraction is available from the start.
Objective :: struct {
    id: string,
    kind: string `json:"type"`,
    x: f32,
    y: f32,
    building: string,
}

Mission :: struct {
    bounds:       geom.Bounds `json:"coordinateSpace"`,
    player_spawn: geom.Point `json:"playerSpawn"`,
    extraction: geom.Point,
    objective: Objective,
    buildings: []geom.Rect,
    walls: []geom.Wall,
    cover: []geom.Cover,
    guards: []actors.Guard,
    // Filled by mission_bake / mission_ensure_baked. Not present in JSON.
    geometry: geom.Geometry,
}

mission_bounds :: proc(lvl: ^Mission) -> geom.Bounds {
    b := lvl.bounds
    if b.width <= 0 do b.width = MISSION_DEFAULT_BOUNDS.width
    if b.height <= 0 do b.height = MISSION_DEFAULT_BOUNDS.height
    return b
}

load :: proc(path: string) -> (Mission, bool) {
    data, read_err := os.read_entire_file(path, context.allocator)
    if read_err != nil {
        fmt.eprintfln("mission: could not read %s: %v", path, read_err)
        return {}, false
    }
    defer delete(data)

    lvl: Mission
    if err := json.unmarshal(data, &lvl); err != nil {
        fmt.eprintfln("mission: invalid JSON in %s: %v", path, err)
        return {}, false
    }
    if lvl.bounds.width <= 0 {
        lvl.bounds.width = MISSION_DEFAULT_BOUNDS.width
    }
    if lvl.bounds.height <= 0 {
        lvl.bounds.height = MISSION_DEFAULT_BOUNDS.height
    }
    lvl.geometry = mission_bake(&lvl)
    return lvl, true
}

// Expand walls (both orientations), buildings and cover into a single list of
// solid rects and circles. Openings become gaps between solid segments.
// The opening coordinate (Point.y / .h) is treated as an interval
// along the wall's long axis.
mission_bake :: proc(lvl: ^Mission, allocator := context.allocator) -> geom.Geometry {
    solids:  [dynamic]geom.Rect
    circles: [dynamic]geom.Circle
    solids.allocator  = allocator
    circles.allocator = allocator

    for b in lvl.buildings {
        append(&solids, geom.Rect{x = b.x, y = b.y, w = b.w, h = b.h, kind = .BUILDING})
    }

    for wall in lvl.walls {
        if len(wall.openings) == 0 {
            append(&solids, geom.Rect{x = wall.x, y = wall.y, w = wall.w, h = wall.h, kind = .WALL})
            continue
        }

        vertical := wall.h >= wall.w
        if vertical {
            cursor := wall.y
            end := wall.y + wall.h
            for op in wall.openings {
                start := math.clamp(op.y, wall.y, end)
                stop  := math.clamp(op.y + op.h, wall.y, end)
                if start > cursor {
                    append(&solids, Solid_Rect{x = wall.x, y = cursor, w = wall.w, h = start - cursor, kind = .WALL})
                }
                cursor = max(cursor, stop)
            }
            if cursor < end {
                append(&solids, Solid_Rect{x = wall.x, y = cursor, w = wall.w, h = end - cursor, kind = .WALL})
            }
        } else {
            // Horizontal wall: openings measured along x.
            cursor := wall.x
            end := wall.x + wall.w
            for op in wall.openings {
                start := math.clamp(op.y, wall.x, end)
                stop  := math.clamp(op.y + op.h, wall.x, end)
                if start > cursor {
                    append(&solids, geom.Rect{x = cursor, y = wall.y, w = start - cursor, h = wall.h, kind = .WALL})
                }
                cursor = max(cursor, stop)
            }
            if cursor < end {
                append(&solids, geom.Rect{x = cursor, y = wall.y, w = end - cursor, h = wall.h, kind = .WALL})
            }
        }
    }

    for item in lvl.cover {
        switch item.kind {
        case "crate":
            append(&solids, geom.Rect{x = item.x, y = item.y, w = item.w, h = item.h, kind = .CRATE})
        case "barrel":
            append(&circles, geom.Circle{x = item.x, y = item.y, r = item.r, kind = .BARREL})
        case "tree":
            append(&circles, geom.Circle{x = item.x, y = item.y, r = item.r, kind = .TREE})
        }
    }

    return geom.Geometry{
        solids  = solids[:],
        circles = circles[:],
        baked   = true,
    }
}

// Ensures geometry is present. Safe to call repeatedly; used so hand-built
// Mission values in tests still work without an explicit bake step.
mission_ensure_baked :: proc(lvl: ^Mission) {
    if lvl.geometry.baked {
        return
    }
    lvl.geometry = mission_bake(lvl)
}