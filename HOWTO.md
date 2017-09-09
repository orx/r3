# How to compile

## Linux / OS X

- Go to `make` directory
- Link the correct pre-built r3 binary as `r3-make` (`ln -s <platform-r3-binary> r3-make`)
- Run: `./r3-make ../src/tools/make-make.r`
- Result is called `r3`

- One can cross-compile by specifying `OS_ID` (cf. `../src/tools/systems.r` for a list of all options):

  `./r3-make ../src/tools/make-make.r OS_ID=0.4.4` -> will compile the Linux x86 version

## Windows

- Go to `make` directory
- Run: `r3-make.exe ../src/tools/make-make.r CONFIG=configs/vs2017-x86.r`
- Open `app.sln` with Visual Studio 2017 and compile:
    - prep
    - top
- Result is called `r3.exe` in `main.dir/Release`
