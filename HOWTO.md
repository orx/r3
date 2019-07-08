# How to compile

## Linux / OS X

- Download pre-built r3 binary (cf prebuilt/README.md) as `prebuilt/r3-make`
- Run: `./r3-make make.r`
- Result is called `r3` in `build/`

- One can cross-compile by specifying `OS_ID` (cf. `tools/systems.r` for a list of all options):

  `./r3-make make.r OS_ID=0.4.4` -> will compile the Linux x86 version

## Windows

- Download pre-built r3 binary (cf prebuilt/README.md) as `prebuilt/r3-make`
- Run: `r3-make.exe make.r config: ../configs/vs2017-x86.r`
- Open `app.sln` with Visual Studio 2017 and compile:
    - prep
    - top
- Result is called `r3.exe` in `build/r3-exe.dir/Release/`
