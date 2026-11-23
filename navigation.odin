package main

NAV_DIAGONAL_COST :: 1.41421356237

Navigation_Path_Result :: struct {
    points: []Mission_Point,
    found: bool,
}

// Integer grid covering the mission plane. One cell = one world unit.
nav_grid_dims :: proc(mission: ^Mission) -> (width: int, height: int) {
    bounds := mission_bounds(mission)
    width = int(bounds.width)
    height = int(bounds.height)
    if width < 1 do width = 1
    if height < 1 do height = 1
    return
}

nav_index :: proc(x, y, grid_width: int) -> int {
    return y * grid_width + x
}

nav_in_bounds :: proc(x, y, grid_width, grid_height: int) -> bool {
    return x >= 0 && x < grid_width &&
           y >= 0 && y < grid_height
}

nav_cell_center :: proc(x, y: int) -> Mission_Point {
    return Mission_Point{
        x = f32(x) + 0.5,
        y = f32(y) + 0.5,
    }
}

nav_heuristic :: proc(x, y, goal_x, goal_y: int) -> f32 {
    dx := abs(goal_x - x)
    dy := abs(goal_y - y)

    diagonal := min(dx, dy)
    straight := max(dx, dy) - diagonal

    return f32(diagonal) * NAV_DIAGONAL_COST + f32(straight)
}

nav_find_path :: proc(
    mission: ^Mission,
    start: Mission_Point,
    goal: Mission_Point,
    radius: f32,
) -> Navigation_Path_Result {
    result := Navigation_Path_Result{}
    grid_w, grid_h := nav_grid_dims(mission)
    cell_count := grid_w * grid_h

    if start.x < 0 || start.x >= f32(grid_w) ||
       start.y < 0 || start.y >= f32(grid_h) ||
       goal.x < 0 || goal.x >= f32(grid_w) ||
       goal.y < 0 || goal.y >= f32(grid_h) {
        return result
    }
    start_x := int(start.x)
    start_y := int(start.y)
    goal_x := int(goal.x)
    goal_y := int(goal.y)

    if !nav_in_bounds(start_x, start_y, grid_w, grid_h) ||
       !nav_in_bounds(goal_x, goal_y, grid_w, grid_h) {
        return result
    }

    if mission_point_collides(mission, start, radius) ||
       mission_point_collides(mission, goal, radius) {
        return result
    }

    start_idx := nav_index(start_x, start_y, grid_w)
    goal_idx := nav_index(goal_x, goal_y, grid_w)

    costs := make([]f32, cell_count)
    defer delete(costs)

    parents := make([]int, cell_count)
    defer delete(parents)

    open := make([]bool, cell_count)
    defer delete(open)

    closed := make([]bool, cell_count)
    defer delete(closed)

    for i in 0..<cell_count {
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

        for i in 0..<cell_count {
            if !open[i] do continue

            x := i % grid_w
            y := i / grid_w

            score := costs[i] + nav_heuristic(x, y, goal_x, goal_y)

            if score < lowest_score {
                lowest_score = score
                current_idx = i
            }
        }

        if current_idx == -1 {
            break
        }

        if current_idx == goal_idx {
            reverse_path := make([dynamic]Mission_Point)
            defer delete(reverse_path)

            current := current_idx
            for current >= 0 {
                x := current % grid_w
                y := current / grid_w
                append(&reverse_path, nav_cell_center(x, y))
                current = parents[current]
            }

            result.points = make([]Mission_Point, len(reverse_path))
            for i in 0..<len(reverse_path) {
                result.points[i] = reverse_path[len(reverse_path)-1-i]
            }

            if len(result.points) > 0 {
                result.points[0] = start
            }

            result.found = true
            return result
        }

        open[current_idx] = false
        closed[current_idx] = true

        current_x := current_idx % grid_w
        current_y := current_idx / grid_w

        for offset in offsets {
            dx := offset[0]
            dy := offset[1]

            next_x := current_x + dx
            next_y := current_y + dy

            if !nav_in_bounds(next_x, next_y, grid_w, grid_h) do continue

            next_idx := nav_index(next_x, next_y, grid_w)
            if closed[next_idx] do continue

            next_point := nav_cell_center(next_x, next_y)

            if mission_point_collides(mission, next_point, radius) {
                continue
            }

            if dx != 0 && dy != 0 {
                side_x := nav_cell_center(current_x + dx, current_y)
                side_y := nav_cell_center(current_x, current_y + dy)

                if mission_point_collides(mission, side_x, radius) ||
                   mission_point_collides(mission, side_y, radius) {
                    continue
                }
            }

            move_cost := f32(1)
            if dx != 0 && dy != 0 {
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
