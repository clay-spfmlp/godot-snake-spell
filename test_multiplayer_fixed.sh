#!/bin/bash

GODOT_PATH="/c/Users/claym/Downloads/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"

echo "Starting Snake Spell Multiplayer Test..."
echo
echo "This will open two game windows:"
echo "- First window: Host a game"
echo "- Second window: Join with 127.0.0.1:7000"
echo
read -p "Press Enter to continue..."

echo "Starting Host instance..."
"$GODOT_PATH" --path "$(pwd)" &

sleep 3

echo "Starting Client instance..."
"$GODOT_PATH" --path "$(pwd)" &

echo
echo "Both instances should now be running!"
echo "In the first window: Host Game"
echo "In the second window: Join Game (127.0.0.1:7000)"
echo
echo "Controls: Both players use WASD keys"
echo "- Green snake = Host"  
echo "- Blue snake = Client"
echo
read -p "Press Enter to exit..." 