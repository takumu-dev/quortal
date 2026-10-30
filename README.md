# quortal

quortal is a fork of [ioquake3](https://ioquake3.org) with seamless portals, like Portal's, built to be read. Each step of building them is one feature branch, which ends in a chapter explaining what the step does and why, so you can learn how portals are made in a real engine, from the code. quortal builds as a standalone game, and runs on [OpenArena](https://openarena.ws)'s free data, so you can build it, run it and follow along without owning Quake III Arena.

## Building and running

You need CMake 3.25 or later, git and a C compiler, and on Linux, SDL 2's development files. Then, from the top of the source:

```sh
cmake -S . -B build
cmake --build build --target openarena q3map2
cmake --build build
build/Release/quortal.x86_64 +devmap test_first
```

The `openarena` target fetches OpenArena 0.8.8's data, a 425 MB download kept in your cache folder, so it's only made once. The `q3map2` target fetches the map compiler that builds the test maps into `quortal.pk3`. Neither is part of the default build. `test_first` is the first test map: two rooms, textured and lit alike. `ctest --test-dir build` runs quortal's checks.

On Windows, with Visual Studio, add `--config Release` to the build commands, and run `build\Release\quortal.exe`. On macOS there's no q3map2 to fetch, so build one first. [Building and running](docs/how-to/building-and-running.md) has the details, such as how to fetch OpenArena's data by hand, or use your own q3map2.

quortal is built and checked on Linux and Windows. It builds on macOS too, but isn't checked there.

## Reading

Start at the [docs index](docs/README.md). It says what a portal is and what quortal's first milestone does, starts you at `test_first`, and lists the chapters, one for each step in the order the history builds them, and the how-tos.

## quortal and ioquake3

quortal is ioquake3 at 87a99d1, with all of ioquake3's history, and quortal's commits on top. It builds as its own game, quortal, with none of Quake III Arena's paks or CD key checks, and GL1 as its only renderer. GL2's source is still there, but isn't built.

quortal isn't ioquake3. For ioquake3 itself, go to [github.com/ioquake/ioq3](https://github.com/ioquake/ioq3). ioquake3's own readme is in [docs/ioquake3-readme.md](docs/ioquake3-readme.md).

quortal is built on the work of the ioquake3 project, and of id Software, which released Quake III Arena's source under the GPL. It runs on the OpenArena Team's data.

## Licence

quortal's own prose and diagrams are under [CC BY 4.0](CC-BY-4.0.txt): this README, the docs index, the glossary, the chapters, the how-tos, and their figures. Everything else is under the GNU General Public License, version 2 or (at your option) any later version, whose text is in [COPYING.txt](COPYING.txt). That's the code, including any code the docs quote, quortal's game data, the screenshots, and ioquake3's readmes. The libraries in `code/thirdparty`, the lcc compiler in `code/tools/lcc`, and the map editors' entity definitions, which are the OpenArena gamepack's, keep their own licences. The [docs index](docs/README.md#licence) says more.
