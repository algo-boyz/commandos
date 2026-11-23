package mission

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"

Mission_Outcome :: enum u8 {
    PLAYING,
    SUCCESS,
    // A guard touched the player.
    FAILED,
}

// Single simulation coordinate type. The whole gameplay layer works in this
// 2D top-down space. Mapping to 3D (x, height, y) happens only in the renderer.
Mission_Point :: struct {
    x: f32,
    y: f32,
}

// Authoring bounds of the mission plane. Loaded from coordinateSpace in JSON;
// defaults keep older missions working.
Mission_Bounds :: struct {
    width:  f32,
    height: f32,
}

MISSION_DEFAULT_BOUNDS :: Mission_Bounds{width = 100, height = 100}

Mission_Rect :: struct {
    id: string,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
}

Mission_Opening :: struct {
    id: string,
    y: f32,
    h: f32,
}

Mission_Wall :: struct {
    id: string,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    openings: []Mission_Opening,
}

Mission_Cover :: struct {
    kind: string `json:"type"`,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    r: f32,
}

Mission_Guard :: struct {
    id: string,
    patrol: []Mission_Point,
    speed: f32,
    pause_duration: f32 `json:"pauseDuration"`,
}

Mission_Extraction :: struct {
    x: f32,
    y: f32,
    radius: f32,
}

// A retrieve-style objective: the player completes it by interacting while
// within OBJECTIVE_INTERACT_RADIUS of (x, y). An empty id means the mission
// has no objective and extraction is available from the start.
Mission_Objective :: struct {
    id: string,
    kind: string `json:"type"`,
    x: f32,
    y: f32,
    building: string,
}

// Runtime collision / LOS geometry produced by mission_bake.
// Openings are expanded into solid segments so every consumer sees the same
// shape. Horizontal and vertical walls are both supported.
// What a baked solid was authored as. Collision and line of sight ignore it;
// the renderer uses it to pick a height and colour, so it can draw straight
// from the baked list instead of re-deriving wall openings from the JSON.
Solid_Kind :: enum u8 {
    BUILDING,
    WALL,
    CRATE,
    BARREL,
    TREE,
}

Solid_Rect :: struct {
    x, y, w, h: f32,
    kind: Solid_Kind,
}

Solid_Circle :: struct {
    x, y, r: f32,
    kind: Solid_Kind,
}

Mission_Geometry :: struct {
    solids:  []Solid_Rect,   // buildings, wall segments, crates
    circles: []Solid_Circle, // barrels, trees (collision only)
    baked:   bool,
}

Mission :: struct {
    bounds:       Mission_Bounds `json:"coordinateSpace"`,
    player_spawn: Mission_Point `json:"playerSpawn"`,
    extraction: Mission_Extraction,
    objective: Mission_Objective,
    buildings: []Mission_Rect,
    walls: []Mission_Wall,
    cover: []Mission_Cover,
    guards: []Mission_Guard,
    // Filled by mission_bake / mission_ensure_baked. Not present in JSON.
    geometry: Mission_Geometry,
}

mission_bounds :: proc(lvl: ^Mission) -> Mission_Bounds {
    b := lvl.bounds
    if b.width <= 0 do b.width = MISSION_DEFAULT_BOUNDS.width
    if b.height <= 0 do b.height = MISSION_DEFAULT_BOUNDS.height
    return b
}

mission_load :: proc(path: string) -> (Mission, bool) {
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
// The opening coordinate (Mission_Opening.y / .h) is treated as an interval
// along the wall's long axis.
mission_bake :: proc(lvl: ^Mission, allocator := context.allocator) -> Mission_Geometry {
    solids:  [dynamic]Solid_Rect
    circles: [dynamic]Solid_Circle
    solids.allocator  = allocator
    circles.allocator = allocator

    for b in lvl.buildings {
        append(&solids, Solid_Rect{x = b.x, y = b.y, w = b.w, h = b.h, kind = .BUILDING})
    }

    for wall in mission.walls {
        if len(wall.openings) == 0 {
            append(&solids, Solid_Rect{x = wall.x, y = wall.y, w = wall.w, h = wall.h, kind = .WALL})
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
                    append(&solids, Solid_Rect{x = cursor, y = wall.y, w = start - cursor, h = wall.h, kind = .WALL})
                }
                cursor = max(cursor, stop)
            }
            if cursor < end {
                append(&solids, Solid_Rect{x = cursor, y = wall.y, w = end - cursor, h = wall.h, kind = .WALL})
            }
        }
    }

    for item in mission.cover {
        switch item.kind {
        case "crate":
            append(&solids, Solid_Rect{x = item.x, y = item.y, w = item.w, h = item.h, kind = .CRATE})
        case "barrel":
            append(&circles, Solid_Circle{x = item.x, y = item.y, r = item.r, kind = .BARREL})
        case "tree":
            append(&circles, Solid_Circle{x = item.x, y = item.y, r = item.r, kind = .TREE})
        }
    }

    return Mission_Geometry{
        solids  = solids[:],
        circles = circles[:],
        baked   = true,
    }
}

mission_geometry_destroy :: proc(geo: ^Mission_Geometry) {
    delete(geo.solids)
    delete(geo.circles)
    geo^ = {}
}

// Ensures geometry is present. Safe to call repeatedly; used so hand-built
// Mission values in tests still work without an explicit bake step.
mission_ensure_baked :: proc(lvl: ^Mission) {
    if lvl.geometry.baked {
        return
    }
    lvl.geometry = mission_bake(lvl)
}

circle_hits_box :: proc(
    x, z, radius: f32,
    min_x, min_z, max_x, max_z: f32,
) -> bool {
    closest_x := math.clamp(x, min_x, max_x)
    closest_z := math.clamp(z, min_z, max_z)
    dx := x - closest_x
    dz := z - closest_z
    return dx*dx + dz*dz < radius*radius
}

circle_hits_circle :: proc(
    x, z, radius: f32,
    cx, cz, other_radius: f32,
) -> bool {
    dx := x - cx
    dz := z - cz
    combined := radius + other_radius
    return dx*dx + dz*dz < combined*combined
}

point_collides :: proc(
    lvl: ^Mission,
    point: Mission_Point,
    radius: f32,
) -> bool {
    mission_ensure_baked(lvl)

    for s in lvl.geometry.solids {
        if circle_hits_box(point.x, point.y, radius, s.x, s.y, s.x + s.w, s.y + s.h) {
            return true
        }
    }
    for c in lvl.geometry.circles {
        if circle_hits_circle(point.x, point.y, radius, c.x, c.y, c.r) {
            return true
        }
    }
    return false
}

// Thin alias: simulation uses Mission_Point only.
mission_collides :: proc(
    lvl: ^Mission,
    point: Mission_Point,
    radius: f32,
) -> bool {
    return mission.point_collides(lvl, point, radius)
}
