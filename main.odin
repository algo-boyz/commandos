package main

import rl "vendor:raylib"

main :: proc() {
    rl.InitWindow(1280, 720, "Commandos - Iso Camera")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.DrawText("Commandos - Camera Prototype", 20, 20, 24, rl.DARKGRAY)

        rl.EndDrawing()
    }
}