package main

// Everything the simulation owns while a mission is running.
// Rendering reads from a World; it never mutates one.
World :: struct {
    mission: Mission,
    player: Player,
    guards: []Guard,
}

// Builds a World from a loaded mission. The World takes the mission by
// value; guards keep slice views into the mission's patrol data.
world_init :: proc(mission: Mission) -> World {
    world := World{mission = mission}

    world.player = player_init({
        world.mission.player_spawn.x,
        1,
        world.mission.player_spawn.y,
    })
    world.guards = guards_init(&world.mission)

    return world
}

world_destroy :: proc(world: ^World) {
    guards_destroy(world.guards)
    world.guards = nil
}
