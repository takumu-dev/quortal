# Stepping through the game code

The game code is the part of quortal that isn't the engine: qagame, the server's game, cgame, the client's view of it, and ui, its menus. It normally runs as QVMs, bytecode that the engine compiles as it loads them from `quortal.pk3`, and a debugger can't step through a QVM. The build also makes the game code as native libraries, though, which a debugger steps through like any other code. This how-to says how to run those instead, in a build with debug information.

## The native libraries

They're built beside `quortal.pk3`, in the game folder: `qagame`, `cgame` and `ui`, as `.so` files on Linux, `.dll` files on Windows and `.dylib` files on macOS. Three cvars choose how each module runs, and [`VM_Init`](../../code/qcommon/vm.c) sets their defaults, in [vm.c](../../code/qcommon/vm.c):

```c
	Cvar_Get( "vm_cgame", "2", CVAR_ARCHIVE );	// !@# SHIP WITH SET TO 2
	Cvar_Get( "vm_game", "2", CVAR_ARCHIVE );	// !@# SHIP WITH SET TO 2
	Cvar_Get( "vm_ui", "2", CVAR_ARCHIVE );		// !@# SHIP WITH SET TO 2
```

2 compiles the QVM as it loads, 1 interprets it, and 0 loads the native library. So `vm_game 0`, `vm_cgame 0` and `vm_ui 0` run all three natively.

They're archived cvars, so they're saved in your config and stay 0 for every later run, until you set them back to 2.

## Why sv_pure has to be 0

A pure server tells its clients which paks they may load from, and [`sv_pure`](../../code/server/sv_init.c) is 1 by default. A native library is never in a pak, and [`FS_FindVM`](../../code/qcommon/files.c), which finds a module's file, only looks in folders while no paks have been named, in [files.c](../../code/qcommon/files.c):

```c
	while(search)
	{
		if(search->dir && !fs_numServerPaks)
		{
```

In single player, the server and the client share one filesystem. So once the client has connected to its pure local server, ui and cgame are loaded as QVMs from `quortal.pk3` whatever `vm_ui` and `vm_cgame` say, and qagame is too at the next `map_restart`. With `sv_pure 0`, no paks are named, and the native libraries stay.

## Running them

```sh
build/Release/quortal.x86_64 +set sv_pure 0 +set vm_game 0 +set vm_cgame 0 +set vm_ui 0 +devmap test_first
```

To see where each module came from, add `+set vm_showLoad 1`. [`vm_showLoad`](../../code/qcommon/vm.c) prints a line as each one loads:

```
qagame loaded from "build/Release/quortal/qagame.so"
```

## A build with debug information

A Release build is optimised, and has no debug information. Build a Debug one in its own build tree:

```sh
cmake -S . -B build-debug -DCMAKE_BUILD_TYPE=Debug
cmake --build build-debug --target openarena q3map2
cmake --build build-debug
```

It's built as in [Building and running](building-and-running.md), into `build-debug/Debug`. OpenArena's zip and q3map2 are in your cache folder by now, so nothing is downloaded again.

With Visual Studio, one build tree holds both, so build the Debug configuration beside Release instead:

```sh
cmake --build build --config Debug --target openarena
cmake --build build --config Debug
```

which builds into `build/Debug`.

## In a debugger

Start the game in the debugger with the same arguments, and two more: `r_fullscreen 0` keeps the game in a window, and [`in_nograb`](../../code/sdl/sdl_input.c) 1 leaves the mouse free, so you can use the debugger while the game is stopped. Both are saved in your config too.

The game code's libraries are only loaded once the game starts a map, so a breakpoint in them waits until then. [`PmoveSingle`](../../code/game/bg_pmove.c), which moves the player, is a good first one. It's built into both qagame and cgame, since the server moves the player, and the client predicts the same moves, so it stops in both libraries.

### gdb, on Linux

```sh
gdb --args build-debug/Debug/quortal.x86_64 +set r_fullscreen 0 +set in_nograb 1 \
    +set sv_pure 0 +set vm_game 0 +set vm_cgame 0 +set vm_ui 0 +devmap test_first
```

gdb asks whether to make the breakpoint pending, since the library isn't loaded yet. Say yes:

```
(gdb) break PmoveSingle
Function "PmoveSingle" not defined.
Make breakpoint pending on future shared library load? (y or [n]) y
Breakpoint 1 (PmoveSingle) pending.
(gdb) run
```

### Visual Studio, on Windows

CMake writes `build\quortal.sln`. Open it, and in the Solution Explorer set `quortal` as the startup project. In its properties, under Debugging, set the command arguments to the same ones. Then choose the Debug configuration, open [bg_pmove.c](../../code/game/bg_pmove.c), set a breakpoint in `PmoveSingle`, and start debugging.

### lldb, on macOS

```sh
lldb -- build-debug/Debug/quortal.app/Contents/MacOS/quortal +set r_fullscreen 0 +set in_nograb 1 \
    +set sv_pure 0 +set vm_game 0 +set vm_cgame 0 +set vm_ui 0 +devmap test_first
```

lldb makes a breakpoint pending on its own:

```
(lldb) breakpoint set --name PmoveSingle
(lldb) run
```

macOS has no q3map2 release, so build one first, as [Building and running](building-and-running.md) says, or there's no `test_first` to run.
