#!/bin/bash

echo "Starting Snake Spell Multiplayer Test..."
echo
echo "This will open two game windows:"
echo "- First window: Host a game"
echo "- Second window: Join with 127.0.0.1:7000"
echo
read -p "Press Enter to continue..."

echo "Starting Host instance..."
godot --path "$(pwd)" &

sleep 3

echo "Starting Client instance..."
godot --path "$(pwd)" &

echo
echo "Both instances should now be running!"
echo "In the first window: Host Game"
echo "In the second window: Join Game (127.0.0.1:7000)"
read -p "Press Enter to exit..." 