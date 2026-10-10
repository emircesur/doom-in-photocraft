PLAY DOOM IN PHOTOCRAFT

Doom (Freedoom: Phase 1, episode 1) played on a PhotoCraft canvas, one move per key press.

1. File > New: 640 x 400 pixels, RGB (320 x 200 works too; at most 1024 x 512).
2. Window > Actions: double-click "Doom: Forward" (or any Doom move). The first one starts a game.
   PhotoCraft versions that bind keys to actions (after 0.5.0) play them with the keys below.
3. Edit > Undo takes a move back.

  Alt+Shift+W / S      forward / back
  Alt+Shift+A / D      turn left / right
  Alt+Shift+Q / E      strafe left / right
  Alt+Shift+F          fire          Alt+Shift+R   forward and fire
  Alt+Shift+Space      use (doors, switches; respawn after dying)
  Alt+Shift+X          turn around   Alt+Shift+.   wait
  Alt+Shift+1 ... 5    weapons       Alt+Shift+N   new game

The moves are in Window > Actions ("Doom: ..."), where newer PhotoCraft versions let you change
their keys.
Filter > Plug-ins > Doom... plays any move with a chosen length and starts games at other
skills or maps.

The game is kept in the picture itself: the lowest two bits of each pixel's red, green and
blue hold the saved game. Painting over the canvas or resizing it starts a new game. Save
the document as .pcraft or PNG to keep a game for later.

Doom's engine is doomgeneric (GPL-2.0-or-later; see LICENSE-doomgeneric.txt), changed to run
as a PhotoCraft plug-in; the game data is Freedoom (BSD-3-Clause; see LICENSE-freedoom.txt).
Source: https://github.com/emircesur/doom-in-photocraft
