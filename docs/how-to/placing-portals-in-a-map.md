# Placing portals in a map

A [placed portal](../glossary.md#placed-portal)'s two ends are put in the map by its author. Each [end](../glossary.md#portal-end) is an [`info_portal_end`](../../code/game/bg_portal.c) entity, with a [plug](../glossary.md#plug) brush filling its opening. This how-to sets up NetRadiant-custom, which quortal's test maps are made in, or TrenchBroom, and says how to copy a finished end into a map, and where to place it so that its portal works and looks right.

For now, every end shows its shader, as a [sealed](../glossary.md#sealed-portal) end always does, and stops the player like the wall around it: the steps that draw portal views and let the player through are still to come. The advice on where to place an end is for them.

## What an end is

An `info_portal_end` has these keys, which [`BG_ReadPortalEnd`](../../code/game/bg_portal.c) reads:

- `origin`: the centre of the opening, on the surface it lies on;
- `angles`: pitch, yaw and roll, which set which way the end faces and which way its height runs, as for a `misc_model`. `angle` gives the yaw alone, for an upright end. An end with both is skipped;
- `width` and `height`: the opening's size, which both ends of a portal must give, and give alike;
- `targetname` and `target`: the end's own name, and its partner's. Each end of a portal targets the other;
- `shader`: optional, what the end shows when its portal is sealed, or when it's past the nesting limit of views inside views, by the shader's full name, such as `textures/quortal/wall_gray`. Without one, it shows black.

The plug is a brush in the world, with `textures/quortal/plug` on every face, filling the opening 64 units deep behind the surface, with solid world behind it and around it. Its shader, in [quortal.shader](../../data/scripts/quortal.shader), shows see-through in both editors, and gives the plug quortal's own contents bit, `plug`, which [custinfoparms.txt](../../data/scripts/custinfoparms.txt) declares. q3map2 only reads it when given `-custinfoparms`, which both editors' compile commands below pass. A map compiled without it has nothing in its openings, and every portal in it is sealed.

The editor's box for an end is a fixed size, so the plug is what shows the opening. Keep the two together: move and turn them as one, and when you change `width` or `height`, resize the plug to match.

When a map loads, the server checks every end, and seals a portal that breaks a rule, printing a warning that names the end, where it is, and the rule:

```
WARNING: portal end "a" at (0 -128 64) isn't filled by a plug 64 units deep, flush with its surface
```

## Setting up NetRadiant-custom

quortal's gamepack is for NetRadiant-custom 20260114, the [release](https://github.com/Garux/netradiant-custom/releases/tag/20260114) quortal's q3map2 comes from. NetRadiant-custom reads gamepacks only from its own `gamepacks` folder:

- on Windows, extract the release's zip, and it's the `gamepacks` folder in it;
- on Linux, the AppImage in the release's `.7z` can't be written to, so extract what it holds with `./NetRadiant-Custom-x86_64.AppImage --appimage-extract`, and from then on start NetRadiant-custom with `squashfs-root/AppRun`. Its gamepacks are in `squashfs-root/usr/bin/gamepacks`.

Copy the two things in [misc/editors/netradiant-custom](../../misc/editors/netradiant-custom), the `games` folder, holding [quortal.game](../../misc/editors/netradiant-custom/games/quortal.game), and the `quortal.game` folder, into that `gamepacks` folder. The `quortal.game` folder holds the gamepack's [build menu](../../misc/editors/netradiant-custom/quortal.game/default_build_menu.xml), and quortal's entity definitions, in [entities.ent](../../misc/editors/netradiant-custom/quortal.game/quortal/entities.ent). They're the OpenArena gamepack's, with the entities quortal's game doesn't spawn taken out, and `info_portal_end` added.

Start NetRadiant-custom, and choose quortal as the game. When it asks for the engine path, choose the folder that holds quortal and its game folder: `build/Release` in quortal's source, once you've built quortal as [Building and running](building-and-running.md) says. The editor reads the textures and shaders in its game folder's paks, OpenArena's and `quortal.pk3`, so build quortal before you start the editor, and again when quortal's own textures change.

The test maps are in [data/maps](../../data/maps), and open from there.

## Setting up TrenchBroom

TrenchBroom's support for Quake 3 is experimental, and none of quortal's checks covers it, so quortal supports TrenchBroom but doesn't test it. It's the one editor with current builds for macOS.

Copy [misc/editors/trenchbroom/quortal](../../misc/editors/trenchbroom/quortal) into TrenchBroom's `games` folder, which you may have to make: `~/.TrenchBroom/games` on Linux, `%APPDATA%\TrenchBroom\games` on Windows, or `~/Library/Application Support/TrenchBroom/games` on macOS. Then copy quortal's entity definitions, [entities.ent](../../misc/editors/netradiant-custom/quortal.game/quortal/entities.ent), kept in the NetRadiant-custom gamepack, into the `quortal` folder you copied, beside its [GameConfig.cfg](../../misc/editors/trenchbroom/quortal/GameConfig.cfg).

In TrenchBroom's preferences, under Games, choose quortal, and set its game path to `build/Release` in quortal's source, and q3map2's path to NetRadiant-custom's q3map2, such as the `build/q3map2/bin/q3map2` that quortal's build fetches. On macOS, build q3map2 as [Building and running](building-and-running.md#on-macos-and-anywhere-else) says.

A new map is in the Valve 220 format, "Quake3 (Valve)", which keeps a texture's alignment as its brush turns, and which NetRadiant-custom's q3map2 reads. The test maps are in Quake 3's own format, which TrenchBroom also opens.

## Compiling a map, and running it

Each editor compiles a map as quortal's build compiles the test maps, with `-custinfoparms` given to the BSP and light stages:

- in NetRadiant-custom, with Build › quortal: bsp, vis and light;
- in TrenchBroom, with Run › Compile Map, and the profile quortal: bsp, vis and light, from [CompilationProfiles.cfg](../../misc/editors/trenchbroom/quortal/CompilationProfiles.cfg). It compiles a copy of the map as it stands in the editor, saved or not.

When you've only changed keys, such as an end's `target` or `shader`, NetRadiant-custom's Build › quortal: only entities writes the map's entities into its compiled `.bsp` again, without compiling the rest.

Both leave the compiled `.bsp` beside the `.map`, with a `.prt` file, which [Keep each end within one cluster](#keep-each-end-within-one-cluster) uses. So save your map in the game folder's `maps` folder, `build/Release/quortal/maps`, where the game finds what's compiled. That's where NetRadiant-custom saves a map by default. The build never touches that folder, but it's still in the build tree, so keep the `.map` somewhere safe as well.

Then start the game on it:

```sh
build/Release/quortal.x86_64 +set sv_pure 0 +devmap mymap
```

A loose `.bsp` isn't in a pak, and a pure server's clients load only from paks, as [Stepping through the game code](stepping-through-the-game-code.md#why-sv_pure-has-to-be-0) explains, so [`sv_pure`](../../code/server/sv_init.c) has to be 0. In the console, [`g_listPortalEnds`](../../code/game/g_main.c) 1 lists every end once, with its verdict:

```
2 portal ends:
  0: "a" at (0 -128 64): open, paired with "b"
  1: "b" at (0 128 64): open, paired with "a"
```

## Copying an end

[portal_end.map](../../misc/editors/portal_end.map) holds one finished end: an upright `info_portal_end`, 64 units wide and 128 high, facing east from x = 0, and its plug, which fills the opening behind it. Copy it into your map twice, once for each end of the portal:

- in NetRadiant-custom, with File › Import, which adds what's in the sample to your map, where it is in the sample, and renames a copy's `targetname` and `target` if your map already uses them;
- in TrenchBroom, by opening the sample beside your map, selecting all of it, and copying it into your map with Edit › Paste at Original Position.

Select the end and its plug together, and move and turn them into place. For each copy:

1. Cut a hole for the plug into solid world, 64 units deep, exactly the size of the opening, so that solid world lies behind the plug and around its edges. The end's `origin` lies on the surface, at the centre of the hole's mouth.
2. Name the two ends, and make each target the other: the sample's end is named `a`, and targets `b`.
3. Set `shader` to the full name of the shader on the wall around the end, such as `textures/quortal/wall_gray`, so that if the portal is ever sealed, the end looks like the wall.

NetRadiant-custom writes only `angle` for an upright end, and only `angles` for a tilted one. TrenchBroom turns an end through whichever of the two it has, and through `angles` if it has neither. With `angle`, it can only turn an end about the vertical, or make it face straight up or down by setting `angle` to -1 or -2, which quortal reads as a yaw. So before tilting an end in TrenchBroom, give it `angles` in place of its `angle`. The sample's end already has them.

## Where to place an end

### Keep each end within one cluster

q3map2 cuts a map's open space into clusters, and works out which clusters can be seen from each. What's seen through an end will be worked out from one point, 8 units in front of its partner: the game will send, and the renderer draw, what can be seen from that point's cluster. If the partner's opening spans two clusters, what can only be seen from the other cluster will go missing from the view.

The `.prt` file that each editor's compile leaves beside the map holds the openings between clusters, its [vis portals](../glossary.md#vis-portal). In NetRadiant-custom, Plugins › prtview › Load .prt file shows them, and in TrenchBroom, File › Load Portal File. None should cross an end's opening, or the space in front of it. In the game, [`r_showcluster`](../../code/renderergl1/tr_world.c) 1 prints the number of the cluster you're in each time it changes.

Clusters are cut along structural brushes, so make the trim and clutter near an end detail. q3map2 also cuts the map on a grid, wherever x, y or z is a multiple of 1024, so keep an end clear of those lines, or set worldspawn's `_blocksize` key to 0, which turns the grid off. Hint brushes put a cut where you choose, away from the end.

### Keep clear space in front

The checks only make sure there's no solid world just in front of an end, nor 8 units out, at its partner's visibility point. But the player will come out of an end into the space in front of it, and a [crossing](../glossary.md#crossing) that wouldn't leave them room there will be refused. So keep the space in front of each end clear, across its whole opening, for at least as deep as the player is wide: 30 units. The checks see the world only, so keep anything that moves out of that space too.

An end smaller than the player, who is 30 units wide and 56 tall, or 40 crouching, will be one to look through, but not to pass through.

### Keep doors, liquids, mirrors and portal surfaces away

- **Doors**: quortal will draw every view, the main one and each through a portal, with the one set of areas the snapshot holds, which doors open and close. A door near an end could hide what should be seen through it, or show what shouldn't.
- **Liquids**: water, slime and lava won't be felt through an end. While the player is in an opening, how deep they are in a liquid will be worked out on one side of it only.
- **Mirrors and portal surfaces**: seen through an end, a mirror, or one of ioquake3's [portal surfaces](../glossary.md#portal-surface), will show only its shader.

### Avoid lighting seams

Light doesn't pass through a portal: each end's surroundings are lit by the lights on its own side. Through an end, you'll see what lies in front of its partner, lit by the lights there, framed by what's around the end you're looking through, lit by the lights on your side. Where the two are lit differently, a [lighting seam](../glossary.md#seam) will show at the edges of the opening.

So light the space around both ends of a portal alike: the same lights, at the same places as seen from each end, with nothing casting a shadow near one end that it doesn't near the other. Lay the same textures around both ends too, aligned alike as seen from each, so that they carry on across the opening. [test_first](../../data/maps/test_first.map)'s two rooms are textured and lit alike in this way.
