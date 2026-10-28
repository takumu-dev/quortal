# Building and running

quortal builds with CMake, and runs on OpenArena's data, which you don't need to own anything to get. The build fetches it for you, along with q3map2, the map compiler that builds the test maps. This how-to says what you need, how to build and run quortal, where q3map2 comes from on each platform, and how to fetch OpenArena's data by hand.

## What you need

- CMake 3.25 or later, and git.
- A C compiler: GCC or Clang on Linux, Visual Studio 2022 on Windows, or Xcode on macOS.
- On Linux, SDL 2's development files, such as Debian and Ubuntu's `libsdl2-dev`. On Windows and macOS, the build uses the SDL 2 in the source.
- For the client, OpenGL with 8 stencil bits, which portal views are drawn with. If your display gives fewer, the console says so as the renderer starts.
- Room for OpenArena's data: its zip is 425 MB, and is kept in your cache folder, and its paks take another 392 MB in the build tree.

## Building

From the top of the source:

```sh
cmake -S . -B build
cmake --build build --target openarena q3map2
cmake --build build
```

The first command configures the build, and warns that it can't find q3map2. The second fetches OpenArena's data and q3map2, which the build never does on its own, since they're downloads. The [`openarena`](../../cmake/openarena.cmake) target and the [`q3map2`](../../cmake/q3map2.cmake) target are described below. The third builds quortal. Now that q3map2 is there, it configures again first, and compiles the test maps into `quortal.pk3`.

With Visual Studio, which can build several configurations from one build tree, add `--config Release` to the two build commands.

Everything is built into `build/Release`:

- the client: `quortal.exe` on Windows, `quortal.app` on macOS, and on Linux, where it's named for its architecture, `quortal.x86_64` on a PC;
- the dedicated server, `quortal-ded`, named the same way;
- the GL1 renderer, which the client loads;
- the game folder, `quortal`, which holds `quortal.pk3`, OpenArena's paks, and the game code's native libraries.

`quortal.pk3` holds quortal's game code, built as QVMs, with quortal's own textures and shaders, and the compiled test maps. Its name sorts after all of OpenArena's paks, so its game code is the one that loads.

## Running

The build tree runs as it is, with no install step:

```sh
build/Release/quortal.x86_64 +devmap test_first
```

On Windows, run `build\Release\quortal.exe +devmap test_first`. `devmap` loads the map with cheats allowed, which quortal's debug cvars need. To run the dedicated server instead:

```sh
build/Release/quortal-ded.x86_64 +map test_first
```

## Checking

```sh
ctest --test-dir build
```

runs every check your machine can (add `-C Release` with Visual Studio). Each check is labelled by what it needs, and `-L <label>` runs just those:

- `docs` checks the docs' links, identifiers, excerpts and lists of commits, and needs git and the source's history;
- `server` needs the dedicated server and the test maps;
- `render` needs the client, the test maps, and OpenGL with 8 stencil bits.

Without q3map2 there are no test maps, so the checks that need them are disabled. On Linux, the client's checks open their window under `xvfb-run` when there's no display, and are skipped when there's neither. The labels are set in [tests.cmake](../../cmake/tests.cmake).

## OpenArena's data

quortal runs on OpenArena 0.8.8's data. The `openarena` target downloads `openarena-0.8.8.zip`, from SourceForge or else from tuxfamily, and checks its size and SHA-256. It keeps the zip in your cache folder (`~/.cache/quortal`, `%LOCALAPPDATA%\quortal` or `~/Library/Caches/quortal`), so it's only downloaded once, and copies its nine paks into the build tree's game folder. When you install quortal, `cmake --install build --component openarena` copies them into the install's game folder too.

To do the same by hand:

1. Download [openarena-0.8.8.zip](https://downloads.sourceforge.net/project/oarena/openarena-0.8.8.zip) from SourceForge, or from [tuxfamily](https://download.tuxfamily.org/openarena/rel/088/openarena-0.8.8.zip).
2. Check that it's 425,189,255 bytes, and that its SHA-256 is `5a8faf7f5b51f351b0a1618c06b6b98a5f1a6758f1d39818de2c87df2a0bac4a`, with `sha256sum` on Linux, `shasum -a 256` on macOS or `certutil -hashfile openarena-0.8.8.zip SHA256` on Windows.
3. Copy the nine `.pk3` files in its `openarena-0.8.8/baseoa` folder into `build/Release/quortal`.

Never copy them into quortal's folder in your home folder, such as `~/.local/share/quortal` on Linux, `%APPDATA%\quortal` on Windows or `~/Library/Application Support/quortal` on macOS. It's searched first, so OpenArena's paks would win over `quortal.pk3`, and OpenArena's game code would run in place of quortal's.

Alternatively, put the zip in the cache folder yourself, and build the `openarena` target, which checks it and copies the paks without downloading anything. The steps are also at the top of [fetch_openarena.cmake](../../cmake/utils/fetch_openarena.cmake).

## q3map2

The test maps are compiled with NetRadiant-custom 20260114's q3map2. Without q3map2, configuring warns that `quortal.pk3` is built without its maps, so there's no `test_first` to run.

quortal uses the first q3map2 it finds of:

1. the one given when configuring, as [`Q3MAP2`](../../cmake/q3map2.cmake), such as `-DQ3MAP2=/path/to/q3map2`;
2. a `q3map2` on your `PATH`;
3. the one the `q3map2` target fetched into the build tree.

The `q3map2` target downloads NetRadiant-custom's release for Linux or Windows from its [GitHub releases](https://github.com/Garux/netradiant-custom/releases/tag/20260114), checks its SHA-256, keeps it in your cache folder, and takes q3map2 out of it, with the libraries it needs, into `build/q3map2`, as `build/q3map2/bin/q3map2`. The releases are for x86-64 only.

### On Linux

The release is `netradiant-custom-20260114-linux-x86_64.7z`, whose SHA-256 is `f48f6f1d0db2b910ef9cb5dc5d8a722852510f3c5c278dc17615c0466b8a7a3d`. q3map2 is in the AppImage inside it. To take it out by hand:

1. Extract `NetRadiant-Custom-x86_64.AppImage` from the `.7z`, with `7z x` or `bsdtar -xf`.
2. Run it with `--appimage-extract`, which extracts what it holds into `squashfs-root`.
3. Configure quortal with `-DQ3MAP2=<the folder>/squashfs-root/usr/bin/q3map2`.

### On Windows

The release is `netradiant-custom-20260114-windows-x86_64.zip`, whose SHA-256 is `25c2e14e2b0bd7a9897b2f943c8821458873c8713973f9c3d68d49f26fe79e35`. Extract it, and configure quortal with `-DQ3MAP2=<the folder>\q3map2.exe`. q3map2 needs the DLLs beside it.

### On macOS, and anywhere else

There's no release, so build q3map2 from NetRadiant-custom's source, with glib, libxml2, libpng, libjpeg, zlib and assimp installed:

```sh
git clone --branch 20260114 https://github.com/Garux/netradiant-custom.git
make -C netradiant-custom binaries-q3map2 DEPENDENCIES_CHECK=off
```

Then configure quortal with `-DQ3MAP2=<path>/netradiant-custom/install/q3map2`. The steps for both platforms are also at the top of [fetch_q3map2.cmake](../../cmake/utils/fetch_q3map2.cmake).
