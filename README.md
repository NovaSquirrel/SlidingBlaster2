# SlidingBlaster2

This is a sequel to [Sliding Blaster](https://github.com/NovaSquirrel/SlidingBlaster/) which is an NES game. It's inspired by a shareware game named Ballmaster 2 from the early 2000s, but I want to differentiate my game a lot with my own unique style.

Building
========

You'll need the following:

* Python 3 (and [Pillow](https://pillow.readthedocs.io/en/stable/))
* GNU Make
* GNU Coreutils
* [ca65](https://cc65.github.io/)
* [lz4](https://github.com/lz4/lz4/releases) compressor (Windows build included)

With that in place, just enter `make`

On Windows I suggest using [msys2](https://www.msys2.org/) to provide Make and Coreutils. You may be able to use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) instead if you prefer.

[nrom-template](https://github.com/pinobatch/nrom-template#setting-up-the-build-environment) has a guide for building on Windows and Linux that will also work for this game, though you will still need to get `lz4`.

License
=======

All game and tool code is available under GPL version 3.

This project uses [Terrific Audio Driver](https://github.com/undisbeliever/terrific-audio-driver) which is under the zlib license.

This project also uses LZ4 code from [libSFX](https://github.com/Optiroc/libSFX) which is under the MIT license.

The following may not be used in other projects without permission:
* Character designs
* PNG files (and files generated from them) except for the `palettes` directory and fonts
* TMX files (and files generated from them)
* Levels
* Story
