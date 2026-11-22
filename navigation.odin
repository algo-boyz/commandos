
package main

NAV_GRID_SIZE :: 100
NAV_CELL_COUNT :: NAV_GRID_SIZE * NAV_GRID_SIZE
NAV_DIAGONAL_COST :: 1.41421356237

Navigation_Path_Result :: struct {
    points: []Mission_Point,
    found: bool,
}

nav_index :: proc(x, z: int) -> int {
    return z * NAV_GRID_SIZE + x
}

nav_in_bounds :: proc(x, z: int) -> bool {
    return x >= 0 && x < NAV_GRID_SIZE &&
           z >= 0 && z < NAV_GRID_SIZE
}

nav_cell_center :: proc(x, z: int) -> Mission_Point {
    return Mission_Point{
        x = f32(x) + 0.5,
        y = f32(z) + 0.5,
    }
}

nav_heuristic :: proc(x, z, goal_x, goal_z: int) -> f32 {
    dx := abs(goal_x - x)
    dz := abs(goal_z - z)

    diagonal := min(dx, dz)
    straight := max(dx, dz) - diagonal

    return f32(diagonal) * NAV_DIAGONAL_COST + f32(straight)
}

nav_find_path :: proc(
    mission: ^Mission,
    start: Mission_Point,
    goal: Mission_Point,
    radius: f32,
) -> Navigation_Path_Result {
    result := Navigation_Path_Result{}

    if start.x < 0 || start.x >= f32(NAV_GRID_SIZE) ||
       start.y < 0 || start.y >= f32(NAV_GRID_SIZE) ||
       goal.x < 0 || goal.x >= f32(NAV_GRID_SIZE) ||
       goal.y < 0 || goal.y >= f32(NAV_GRID_SIZE) {
        return result
    }
    start_x := int(start.x)
    start_z := int(start.y)
    goal_x := int(goal.x)
    goal_z := int(goal.y)

    if !nav_in_bounds(start_x, start_z) ||
       !nav_in_bounds(goal_x, goal_z) {
        return result
    }

    if mission_point_collides(mission, start, radius) ||
       mission_point_collides(mission, goal, radius) {
        return result
    }

    start_idx := nav_index(start_x, start_z)
    goal_idx := nav_index(goal_x, goal_z)

    costs := make([]f32, NAV_CELL_COUNT)
    defer delete(costs)

    parents := make([]int, NAV_CELL_COUNT)
    defer delete(parents)

    open := make([]bool, NAV_CELL_COUNT)
    defer delete(open)

    closed := make([]bool, NAV_CELL_COUNT)
    defer delete(closed)

    for i in 0..<NAV_CELL_COUNT {
        costs[i] = 1e30
        parents[i] = -1
    }

    costs[start_idx] = 0
    open[start_idx] = true

    offsets := [8][2]int{
        {-1,  0},
        { 1,  0},
        { 0, -1},
        { 0,  1},
        {-1, -1},
        { 1, -1},
        {-1,  1},
        { 1,  1},
    }

    for {
        current_idx := -1
        lowest_score: f32 = 1e30

        // Select the open node with the lowest estimated total cost.
        for i in 0..<NAV_CELL_COUNT {
            if !open[i] do continue

            x := i % NAV_GRID_SIZE
            z := i / NAV_GRID_SIZE

            score := costs[i] + nav_heuristic(
                x, z, goal_x, goal_z,
            )

            if score < lowest_score {
                lowest_score = score
                current_idx = i
            }
        }

        if current_idx == -1 {
            break
        }

        if current_idx == goal_idx {
            // Reconstruct goal -> start, then reverse.
            reverse_path := make([dynamic]Mission_Point)
            defer delete(reverse_path)

            current := current_idx
            for current >= 0 {
                x := current % NAV_GRID_SIZE
                z := current / NAV_GRID_SIZE
                append(&reverse_path, nav_cell_center(x, z))
                current = parents[current]
            }

            result.points = make([]Mission_Point, len(reverse_path))
            for i in 0..<len(reverse_path) {
                result.points[i] = reverse_path[len(reverse_path)-1-i]
            }

            // Preserve the exact starting position. The A* search operates on
            // grid cells, but movement must not snap the guard back to the
            // centre of its current cell after a route is recalculated.
            if len(result.points) > 0 {
                result.points[0] = start
            }

            result.found = true
            return result
        }

        open[current_idx] = false
        closed[current_idx] = true

        current_x := current_idx % NAV_GRID_SIZE
        current_z := current_idx / NAV_GRID_SIZE

        for offset in offsets {
            dx := offset[0]
            dz := offset[1]

            next_x := current_x + dx
            next_z := current_z + dz

            if !nav_in_bounds(next_x, next_z) do continue

            next_idx := nav_index(next_x, next_z)
            if closed[next_idx] do continue

            next_point := nav_cell_center(next_x, next_z)

            if mission_point_collides(mission, next_point, radius) {
                continue
            }

            // Prevent diagonal movement through blocked corners.
            if dx != 0 && dz != 0 {
                side_x := nav_cell_center(current_x + dx, current_z)
                side_z := nav_cell_center(current_x, current_z + dz)

                if mission_point_collides(mission, side_x, radius) ||
                   mission_point_collides(mission, side_z, radius) {
                    continue
                }
            }

            move_cost := f32(1)
            if dx != 0 && dz != 0 {
                move_cost = NAV_DIAGONAL_COST
            }

            tentative_cost := costs[current_idx] + move_cost

            if tentative_cost < costs[next_idx] {
                costs[next_idx] = tentative_cost
                parents[next_idx] = current_idx
                open[next_idx] = true
            }
        }
    }

    return result
}
