
package actors

import "core:testing"

@(test)
test_guard_vision_range :: proc(t: ^testing.T) {
    mission := Mission{}

    visible := guard_can_see(
        {0, 0},
        {1, 0},
        {20, 0},
        &mission,
        VISION_DEFAULT,
    )

    outside_range := guard_can_see(
        {0, 0},
        {1, 0},
        {25, 0},
        &mission,
        VISION_DEFAULT,
    )

    testing.expect(t, visible)
    testing.expect(t, !outside_range)
}

@(test)
test_guard_vision_fov :: proc(t: ^testing.T) {
    mission := Mission{}

    directly_ahead := guard_can_see(
        {0, 0},
        {1, 0},
        {10, 0},
        &mission,
        VISION_DEFAULT,
    )

    behind := guard_can_see(
        {0, 0},
        {1, 0},
        {-10, 0},
        &mission,
        VISION_DEFAULT,
    )

    outside_cone := guard_can_see(
        {0, 0},
        {1, 0},
        {5, 8},
        &mission,
        VISION_DEFAULT,
    )

    testing.expect(t, directly_ahead)
    testing.expect(t, !behind)
    testing.expect(t, !outside_cone)
}

@(test)
test_guard_vision_building_occlusion :: proc(t: ^testing.T) {
    mission := Mission{
        buildings = {
            Mission_Rect{
                x = 4,
                y = -2,
                w = 2,
                h = 4,
            },
        },
    }

    blocked := guard_can_see(
        {0, 0},
        {1, 0},
        {10, 0},
        &mission,
        VISION_DEFAULT,
    )

    testing.expect(t, !blocked)
}

@(test)
test_guard_vision_wall_opening :: proc(t: ^testing.T) {
    mission := Mission{
        walls = {
            Mission_Wall{
                x = 10,
                y = 0,
                w = 1,
                h = 20,
                openings = {
                    Mission_Opening{
                        y = 8,
                        h = 4,
                    },
                },
            },
        },
    }

    through_opening := guard_can_see(
        {5, 10},
        {1, 0},
        {15, 10},
        &mission,
        VISION_DEFAULT,
    )

    through_solid_wall := guard_can_see(
        {5, 5},
        {1, 0},
        {15, 5},
        &mission,
        VISION_DEFAULT,
    )

    testing.expect(t, through_opening)
    testing.expect(t, !through_solid_wall)
}
