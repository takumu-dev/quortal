# Glossary

The words the docs use for portals, for how they're taught, and for the parts of ioquake3 that the chapters build on. ioquake3 already has three things it calls portals, and none of them is a portal in the docs' sense, so they're listed at the end, each marked as not a portal.

## Portals

### Portal

Two linked openings, through which space carries on as if they were one: what lies beyond one is seen, and reached, through the other. In the docs, a portal is always this, and never one of ioquake3's three.

### Portal end

One of a portal's two openings. It's a rectangle lying flat on a solid surface, such as a wall, a floor or a ceiling, at any angle, and it's seen and entered from its front only. A portal's two ends are the same size.

### Portal transform

The rigid movement that carries whatever goes into one portal end out of the other: a turn and a move, and never a change of size.

### Portal view

What you see through a portal end: the far side, as it would look from where your eye would be had it passed through the portal. A portal view can hold more portal views, down to a nesting limit.

### Seam

A visible break where a portal view meets the world around its portal end. A seam that comes from the map's light falling differently on the two ends is a lighting seam.

### Plug

What fills a portal end's opening, flush with the surface around it. It stops everything but the player, so that the player can step into the opening.

### Crossing

The moment the player passes through a portal: when their eye passes the surface of a portal end, inside its opening. A crossing that wouldn't leave the player room on the far side is refused, and the end then stops them, as the surface around it would.

### Placed portal

A portal whose ends the map's author put in the map.

### Sealed portal

A placed portal its map got wrong. Each of its ends shows as a painted wall, and nothing is seen or passes through it.

## Teaching

### Step

One stage of building quortal, which ends in something you can build and see at a station. Each step is one feature branch, and a milestone is a run of steps.

### Chapter

The docs' explanation of one step: what it makes possible, why it's built the way it is, and how. Each step has one chapter.

### Station

One labelled spot in a test map, which shows one case.

### Walk

A scripted run of the player through one station's case, which says what must come of it: which crossings happen, and how the player's speed and view come out of them.

## ioquake3's words

### Game code

The part of the game that isn't the engine, in three modules: qagame, the game as the server runs it, cgame, the client's side of it, which predicts the player's movement and decides what to draw, and ui, the menus. Each is built both as a QVM and as a native library.

### QVM

The game code compiled to bytecode for the engine's virtual machine, which the engine compiles to the machine's own code as it loads it, or interprets on a machine it has no compiler for. A QVM can reach nothing outside its own memory but through the engine's calls, and is the same file on every platform. [`VM_Create`](../code/qcommon/vm.c) loads one.

### pk3

A zip file of game data, such as maps, textures, shaders and QVMs, in a game folder. A file is looked for first in the pk3 whose name sorts last, so a pk3 overrides those whose names sort before it.

### Pure server

A server that gives its clients the list of the pk3s it has loaded, so that they load only from those, and everyone plays the same data and game code. [`sv_pure`](../code/server/sv_init.c) is 1 by default, in single player too.

### Stencil buffer

A few bits that an OpenGL window keeps for each pixel, beside its colour and depth, which drawing can set and test, so that later drawing lands only where earlier drawing marked. quortal's portal views use all 8 of its bits.

## ioquake3's own portals, which aren't portals

### Portal surface

**Not a portal.** ioquake3's [`misc_portal_surface`](../code/game/g_misc.c): a surface showing the picture from a fixed camera elsewhere in the map, a [`misc_portal_camera`](../code/game/g_misc.c), like a screen. Nothing passes through it.

### Area portal

**Not a portal.** A cut between two areas of a map, which a door opens and closes, so that while the door is shut, nothing behind it is drawn or sent. [`CM_AdjustAreaPortalState`](../code/qcommon/cm_test.c) opens and closes one.

### Vis portal

**Not a portal.** An opening between two leaves of a compiled map, from which the map compiler works out what can be seen from where.
