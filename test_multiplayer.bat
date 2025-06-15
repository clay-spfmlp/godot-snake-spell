@echo off
echo Starting Snake Spell Multiplayer Test...
echo.
echo This will open two game windows:
echo - First window: Host a game
echo - Second window: Join with 127.0.0.1:7000
echo.
pause

echo Starting Host instance...
start "" "godot.exe" --path "%cd%" 

timeout /t 3 /nobreak > nul

echo Starting Client instance...
start "" "godot.exe" --path "%cd%"

echo.
echo Both instances should now be running!
echo In the first window: Host Game
echo In the second window: Join Game (127.0.0.1:7000)
pause 