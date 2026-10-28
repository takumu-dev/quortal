# quortal's docs

quortal is ioquake3 with seamless portals, built one step at a time so that you can read how they're made. These docs are its teaching: a chapter for each step, and how-tos for building, running and debugging it. The words they use are in the [glossary](glossary.md).

## Portals, and milestone 1

A [portal](glossary.md#portal) is two linked openings through which space carries on: you see what lies beyond one through the other, and walk through it as if the wall weren't there, as in Portal.

quortal's first milestone is walking through a [placed portal](glossary.md#placed-portal). A map's author places a portal's two [ends](glossary.md#portal-end) on the map's walls, floors or ceilings. Then in single player, on Linux and Windows, you see through each end live, with no [seam](glossary.md#seam) where the [portal view](glossary.md#portal-view) meets the wall around it. And you walk through, keeping your speed, with your direction and your view turned by the portal.

## Start here, at test_first

Build quortal and fetch OpenArena's data, as [Building and running](how-to/building-and-running.md) says, then start the first test map:

```sh
build/Release/quortal.x86_64 +devmap test_first
```

`test_first` is two rooms, textured and lit alike, so that a portal between them can show no seam. Its source is [test_first.map](../data/maps/test_first.map), and [chapter 1](01-quortal-on-ioquake3.md) starts there.

## The chapters

There's one chapter for each step, in the order the history builds them. Each opens at the [station](glossary.md#station) where you see what its step makes possible, then tells you what you need to know of ioquake3, the problem the step solves, the choice it makes (and how Portal, Doom 3 or Source made it), and the code. It ends with what to try at the station, the step's limits, and its commits, under "How it was built".

Each identifier a chapter names links to the file it's in, and each excerpt is quoted whole from the file linked just above it. The docs check, which CI and `ctest` run, keeps both true as the code changes, and keeps each chapter's commits in the history.

1. [quortal on ioquake3](01-quortal-on-ioquake3.md): ioquake3 made into a standalone game, quortal, that runs on OpenArena's free data, with its own game code in `quortal.pk3`, and GL1 as its only renderer, keeping the 8 stencil bits that portal views need.

The rest each come as the last commit of their step.

## The how-tos

- [Building and running](how-to/building-and-running.md): what you need, building and running quortal, running its checks, fetching OpenArena's data by hand, and where q3map2 comes from on each platform.
- [Stepping through the game code](how-to/stepping-through-the-game-code.md): running the game code's native libraries in place of its QVMs, in a debugger.

## Reading alongside the history

Each [step](glossary.md#step) is one feature branch, merged into develop as one merge commit, so

```sh
git log --first-parent develop
```

lists the steps, newest first. Below them is ioquake3's own history, from 87a99d1 down. To read a step's code:

```sh
git checkout <the merge>                         # the code as the step left it
git log --reverse <the merge>^1..<the merge>^2   # the step's commits, oldest first
```

Each chapter ends with the same commits, linked. The chapters are kept true to the code as it is: a later step that changes code a chapter explains rewrites that chapter too. To read a chapter as its step left it, check out the step's merge.

## Which files are ioquake3's

quortal is ioquake3 at 87a99d1, with quortal's commits on top, so every file that quortal didn't add is ioquake3's, changed where quortal needed it to be.

```sh
git diff --stat --diff-filter=A 87a99d1 HEAD   # the files quortal added
git diff 87a99d1 HEAD -- code/qcommon/vm.c     # what quortal changed in one of ioquake3's
```

In this folder, this index, the glossary, the chapters, the how-tos and the [screenshots](screenshots) are quortal's. The rest are ioquake3's: its own [readme](ioquake3-readme.md), id's [readme](id-readme.txt) for the Quake III Arena source, and its readmes on the [GL2 renderer](opengl2-readme.md), which quortal doesn't build, on [VoIP](voip-readme.txt), on [MD4 models](md4-readme.txt) and on [signing for macOS](macos-codesign-notarization.txt).

## Licence

quortal's own prose and diagrams are under the Creative Commons Attribution 4.0 International licence, [CC BY 4.0](../CC-BY-4.0.txt), so that you can reuse them, in a course, a book or a slide, as long as you credit quortal. They're the `README.md` at the top of the source, this index, the glossary, the chapters, the how-tos, and their figures.

Everything else is under the GNU General Public License, version 2 or (at your option) any later version, whose text is in [COPYING.txt](../COPYING.txt). That's the code, including any code the docs quote, quortal's game data, which [CREDITS.txt](../data/CREDITS.txt) credits, the screenshots, which show the game's data, and ioquake3's readmes. The libraries in `code/thirdparty`, and the lcc compiler in `code/tools/lcc`, keep their own licences.

A change to a file takes that file's licence.
