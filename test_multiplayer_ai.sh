#!/bin/bash

# Paths to exported console executables
HOST_EXE="/c/Users/claym/Games/snake-spell/Host/Snake Spell.console.exe"
CLIENT_EXE="/c/Users/claym/Games/Snake Spell.console.exe"

echo "🐍 Snake Spell Multiplayer AI Test - 8 Player Arena"
echo "================================================="
echo
echo "This will launch:"
echo "✅ Host (with console debug output)"
echo "✅ Client (with console debug output)"
echo "🤖 AI will control one snake automatically"
echo "🏟️ Bigger 30x30 arena (was 20x20)"
echo "👥 Supports up to 8 players total"
echo
echo "Instructions:"
echo "1. Host window: Enter name 'Host' → Click 'Host Game'"
echo "2. Client window: Enter name 'AIBot' → Join 127.0.0.1:7000"
echo "3. Host clicks 'Start Game'"
echo "4. Host controls green snake (WASD)"
echo "5. AI controls blue snake (automatic circles)"
echo
read -p "Press Enter to start testing..."

# Create Client folder if it doesn't exist
mkdir -p "/c/Users/claym/Games/snake-spell/Client"

# Copy the executable for client if needed
if [ ! -f "/c/Users/claym/Games/snake-spell/Client/Snake Spell.console.exe" ]; then
    echo "📋 Copying client executable..."
    cp "$CLIENT_EXE" "/c/Users/claym/Games/snake-spell/Client/"
fi

echo
echo "🚀 Starting Host instance..."
cd "/c/Users/claym/Games/snake-spell/Host"
"./Snake Spell.console.exe" &
HOST_PID=$!

sleep 3

echo "🤖 Starting AI Client instance..."
cd "/c/Users/claym/Games/snake-spell/Client"  
"./Snake Spell.console.exe" &
CLIENT_PID=$!

echo
echo "🎮 Both instances are running!"
echo "📺 You should see two game windows with console output"
echo
echo "🎯 Test Instructions:"
echo "Host Window: Host game → Start when client joins"
echo "Client Window: Join 127.0.0.1:7000"
echo
echo "🐍 Controls:"
echo "- Host (Green): WASD keys"
echo "- Client (Blue): Will move automatically in circles"
echo
echo "📊 Watch console output for network debug info!"
echo
echo "Press Ctrl+C to stop both instances"

# Wait for user interrupt
trap "echo 'Stopping game instances...'; kill $HOST_PID $CLIENT_PID 2>/dev/null; exit" INT

wait 