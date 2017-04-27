REBOL [
    System: "REBOL [R3] Language Interpreter and Run-time Environment"
    Title: "Make the R3 Core Makefile"
    Rights: {
        Copyright 2012 REBOL Technologies
        Copyright 2012-2017 Rebol Open Source Contributors
        REBOL is a trademark of REBOL Technologies
    }
    License: {
        Licensed under the Apache License, Version 2.0
        See: http://www.apache.org/licenses/LICENSE-2.0
    }
    Purpose: {
        Build a new makefile for a given platform.

        The reason that Rebol is not used to drive the build directly is to
        make it possible to port to any platform which supports GNU make.
        A R3-Alpha or Ren-C interpreter is thus only needed to produce the
        files, which can be done on a different platform, with the products
        transferred over to the new system which bootstrap is being done on.
    }
    Note: [
        "This runs relative to ../tools directory."
        "Make OS-specific changes to the systems.r file."
    ]
]

do %r2r3-future.r
do %common.r
do %common-emitter.r


path-host: %../os/
path-make: %../../make/
path-incl: %../../src/include/


;
; PROCESS COMMAND LINE ARGS
;
; Arguments are like `r3 %make-make.r A=B X=Y`, so turn that into an args
; object with keys and values (e.g. args/A = "B").  Values are STRING!
;

args: parse-args system/options/args


;
; IMPORT PLATFORM CONFIGURATION TO `CONFIG` OBJECT (from %systems.r)
;
; If OS_ID is not provided, it will be detected.
;

do %systems.r

config: case [
    any [blank? args/OS_ID | args/OS_ID = "detect"] [
        config-system blank
    ]
    true [
        config-system args/OS_ID
    ]
]

print ["Option set for building:" config/id config/os-name]

flag?: function [
    {Test if a flag is applicable for the current platform (see %systems.r)}
    'flag [word!]
][
    not blank? find config/build-flags flag
]


;
; DECODE DEBUG OPTION INTO FLAGS
;
; DEBUG can be "none", "asserts", "symbols", "sanitize"...each a level of
; assumed greater debugging.  Adding symbols makes the executable much
; larger, and Address Sanitization makes the executable much slower.  To
; try and get casual builders to bear a modest useful burden, the default
; is set to just including the asserts.
;

case [
    args/DEBUG = "none" [
        asserts: false
        symbols: false
        sanitize: false
        optimize: true
    ]
    any [blank? args/DEBUG | args/DEBUG = "asserts"] [
        asserts: true
        symbols: false
        sanitize: false
        optimize: true
    ]
    args/DEBUG = "symbols" [
        asserts: true
        symbols: true
        sanitize: false
        optimize: false
    ]
    args/DEBUG = "sanitize" [
        asserts: true
        symbols: true
        sanitize: true
        optimize: false
    ]
    true [
        fail [
            "DEBUG must be [none | asserts | symbols | sanitize], not"
            (args/DEBUG)
        ]
    ]
]


;
; PROCESS LIST OF INPUT C AND HEADER FILES FROM %FILE-BASE.R
;

file-base: has load %file-base.r

; Collect OS-specific host files.
;
os-specific-objs: select file-base to word! unspaced ["os-" config/os-base]
unless os-specific-objs [
    fail [
        "make-make.r requires os-specific obj list in file-base.r"
        "Nothing was provided for" unspaced ["os-" config/os-base]
    ]
]

; The + sign is used to tell the make-os-ext.r script to scan a host kit file
; for headers (the way make-headers.r does).  But we don't care about that
; here in make-make.r... so remove any + signs we find before processing.
;
remove-each item file-base/os [item = '+]
remove-each item os-specific-objs [item = '+]

if flag? +SC [remove find os-specific-objs 'host-readline.c]


emit [

{# REBOL Makefile -- Generated by make-make.r (!!! EDITS WILL BE LOST !!!)
# This automatically produced file was created } now newline

newline

{# This makefile is intentionally kept simple to make builds possible on
# a wide range of target platforms.  While this generated file has several
# capabilities, it is not tracked by version control.  So to kick off the
# process you need to use the tracked bootstrap makefile:
#
#     make -f makefile.boot
#
# See the comments in %makefile.boot for more information on the workings of
# %make-make.r and what the version numbers mean.
#
# To cross-compile using a different toolchain and include files:
#
#     $TOOLS - should point to bin where gcc is found
#     $INCL  - should point to the dir for includes
#
# Example make:
#
#     make TOOLS=~/amiga/amiga/bin/ppc-amigaos- INCL=/SDK/newlib/include
#
# !!! Efforts to be able to have Rebol build itself in absence of a make
# tool are being considered.  Please come chime in on chat if you are
# interested in that and other projects, or need support while building:
#
# http://rebolsource.net/go/chat-faq
#
}

{OS_ID?=} space (config/id) newline

newline

{GIT_COMMIT?=} space (any [args/GIT_COMMIT "unknown"]) newline

newline

{DEBUG_FLAGS?=} space (
    unspaced [
        either symbols ["-g "] [""]
        either asserts [""] ["-DNDEBUG "] ; http://stackoverflow.com/q/9229978/
        either optimize ["-O2"] ["-O0"]
    ]
) newline

newline

(
    either sanitize [
        unspaced [
            {SANITIZE_FLAGS= -fno-omit-frame-pointer -fsanitize=address} newline
            {SANITIZE_LINK_FLAGS= -fsanitize=address} newline
        ]
    ][
        unspaced [
            {SANITIZE_FLAGS=} newline
            {SANITIZE_LINK_FLAGS=} newline
        ]
    ]
) newline

newline

{LANGUAGE_FLAGS?=} space case [
    any [blank? args/STANDARD | args/STANDARD = "c"] [
        cplusplus: false
        ""
    ]
    find ["gnu89" "c99" "gnu99" "c11"] args/STANDARD [
        cplusplus: false
        unspaced ["--std=" args/STANDARD]
    ]
    "c++" = args/STANDARD [
        cplusplus: true
        "-x c++"
    ]
    find ["c++98" "c++0x" "c++11" "c++14" "c++17"] args/STANDARD [
        cplusplus: true

        ; Note: The C and C++ standards do not dictate if `char` is signed
        ; or unsigned.  Lest anyone think all environments have settled on
        ; them being signed, they're not... Android NDK uses unsigned:
        ;
        ; http://stackoverflow.com/questions/7414355/
        ;
        ; In order to give the option some exercise, make the C++11 builds
        ; and above use unsigned chars.
        ;
        unspaced [
            "-x c++" space "--std=" args/STANDARD space "-funsigned-char"
        ]
    ]
    true [
        fail [
            "STANDARD should be [c gnu89 gnu99 c99 c11 c++ c++11 c++14 c++17]"
            "not" (args/STANDARD)
        ]
    ]
] newline

{RIGOROUS_FLAGS?=} space (
    case [
        args/RIGOROUS = "yes" [
            rigorous: true
            spaced [
                "-Werror" ;-- convert warnings to errors

                ; If you use pedantic in a C build on an older GNU compiler,
                ; (that defaults to thinking it's a C89 compiler), it will
                ; complain about using `//` style comments.  There is no
                ; way to turn this complaint off.  So don't use pedantic
                ; warnings unless you're at c99 or higher, or C++.
                ;
                (
                    either any [
                        cplusplus | not find ["c" "gnu89"] args/STANDARD
                    ][
                        "--pedantic"
                    ][
                        ""
                    ]
                )

                "-Wextra"
                "-Wall"
                
                "-Wchar-subscripts"
                "-Wwrite-strings"
                "-Wundef"
                "-Wformat=2"
                "-Wdisabled-optimization"
                "-Wlogical-op"
                "-Wredundant-decls"
                "-Woverflow"
                "-Wpointer-arith"
                "-Wparentheses"
                "-Wmain"
                "-Wsign-compare"
                "-Wtype-limits"
                "-Wclobbered"

                ; Neither C++98 nor C89 had "long long" integers, but they
                ; were fairly pervasive before being present in the standard.
                ;
                "-Wno-long-long"

                ; When constness is being deliberately cast away, `m_cast` is
                ; used (for "m"utability).  However, this is just a plain cast
                ; in C as it has no const_cast.  Since the C language has no
                ; way to say you're doing a mutability cast on purpose, the
                ; warning can't be used... but assume the C++ build covers it.
                ;
                (either cplusplus ["-Wcast-qual"] ["-Wno-cast-qual"])

                ; The majority of Rebol's C code was written with little
                ; attention to overflow in arithmetic.  Frequently REBUPT
                ; is assigned to REBCNT, size_t to REBYTE, etc.  The issue
                ; needs systemic review, but will be most easy to do so when
                ; the core is broken out fully from less critical code
                ; in optional extensions.
                ;
                ;"-Wstrict-overflow=5"
                "-Wno-conversion"
                "-Wno-strict-overflow"
            ]

        ]
        any [blank? args/RIGOROUS | args/RIGOROUS = "no"] [
            rigorous: false
            {}
        ]
        true [
            fail ["RIGOROUS must be yes or no, not" (args/RIGOROUS)]
        ]
    ]
) newline
 
{# For the build toolchain:
CC=} space (either cplusplus ["$(TOOLS)g++"] ["$(TOOLS)gcc"]) newline

newline

{NM= $(TOOLS)nm} newline

newline

{# CP allows different copy progs:
CP?=} space (either flag? COP ["copy"] ["cp"]) newline

{# LS allows different directory list progs:
LS?=} space (either flag? DIR ["dir"] ["ls -l"]) newline

{# UP - some systems do not use ../
UP?=} space (either flag? -SP [""] [".."]) newline

{# CD - some systems do not use ./
CD?=} space (either flag? -SP [""] ["./"]) newline

newline

(
    either symbols [
        ;
        ; Easier in the rules below to have something that just takes a
        ; filename than to actually conditionally use the strip commands.
        ;
        {STRIP= $(LS)}
    ][
        {STRIP= $(TOOLS)strip}
    ]
) newline

newline

{# Special tools:
T= $(UP)/src/tools
# Paths used by make:
S= ../src
R= $S/core

INCL ?= .
I= -I$(INCL) -I$S/include/ -I$S/codecs/
PKGCONFIG ?= pkg-config
}

newline

{TO_OS_BASE?=} space (uppercase to-c-name [{TO_} config/os-base]) newline
{TO_OS_NAME?=} space (uppercase to-c-name [{TO_} config/os-name]) newline

newline

{BIN_SUFFIX=} space (either flag? EXE [".exe"] [""]) newline

newline

case [
    args/WITH_FFI = "static" [
        unspaced [
            {FFI_FLAGS=`${PKGCONFIG} --cflags libffi` -DHAVE_LIBFFI_AVAILABLE}
                newline
            {#only statically link ffi}
                newline
            {FFI_LIBS=-Wl,-Bstatic `${PKGCONFIG} --libs libffi`}
                space {-Wl,-Bdynamic}
                newline
         ]
    ]
    args/WITH_FFI = "dynamic" [
        unspaced [
            {FFI_FLAGS=`${PKGCONFIG} --cflags libffi` -DHAVE_LIBFFI_AVAILABLE}
                newline
            {FFI_LIBS=`${PKGCONFIG} --libs libffi`}
                newline
         ]
    ]
    any [blank? args/WITH_FFI | args/WITH_FFI = "no"] [
        unspaced [
            {FFI_FLAGS=} newline
            {FFI_LIBS=} newline
        ]
    ]
    true [
        fail ["WITH_FFI must be static, dynamic or no, not" (args/WITH_FFI)]
    ]
]

newline

case [
    any [blank? args/WITH_TCC | args/WITH_TCC = "no"] [
        unspaced [
            {TCC=} newline
            {TCC_FLAGS=} newline
            {TCC_LIB_DIR?=}
            {TCC_LIBS=} newline
            {TCC_LINK_FLAGS=} newline
        ]
    ]
    true [
        path: to-rebol-file args/WITH_TCC
        unless 'file = exists? path [
            fail ["WITH_TCC must be the path to the tcc executable or no, not" (args/WITH_TCC)]
        ]
        unspaced [
            {TCC=} path newline
            {TCC_FLAGS=-DWITH_TCC -I../external/tcc} newline
            {TCC_LIB_DIR?=} first split-path path newline
            {TCC_LIBS=$(TCC_LIB_DIR)/libtcc1.a $(TCC_LIB_DIR)/libtcc.a} newline
            {TCC_LINK_FLAGS=-L$(TCC_LIB_DIR)} newline
        ]
    ]
]

newline
]



;
; LIBRARY FLAGS
;
emit [
    {RAPI_FLAGS= $(LANGUAGE_FLAGS) $(DEBUG_FLAGS)}
        space {$(SANITIZE_FLAGS) $(RIGOROUS_FLAGS)}
]

for-each [flag switches] compiler-flags [
    if all [flag? (flag) | switches] [
        emit [space switches]
    ]
]

for-each [flag switches] lib-compiler-flags [
    if all [flag? (flag) | switches] [
        emit [space switches]
    ]
]

emit newline

;
; HOST FLAGS
;

emit [
    {HOST_FLAGS= $(LANGUAGE_FLAGS) $(DEBUG_FLAGS) $(SANITIZE_FLAGS)}
        space {$(RIGOROUS_FLAGS) -DREB_EXE}
]

for-each [flag switches] compiler-flags [
    if all [flag? (flag) | switches] [
        emit [space switches]
    ]
]

emit newline

emit [
newline
{# Flags for core and for host:
RFLAGS= -D$(TO_OS_BASE) -D$(TO_OS_NAME) -DREB_API  $(RAPI_FLAGS) $(FFI_FLAGS) $I $(TCC_FLAGS)
HFLAGS= -D$(TO_OS_BASE) -D$(TO_OS_NAME) -DREB_CORE $(HOST_FLAGS) $I}

newline newline

{# Flags used by tcc to preprocess sys-core.h
# filter out options that tcc doesn't support
TCC_CPP_FLAGS_tmp=$(RFLAGS:--std%=)
TCC_CPP_FLAGS=$(TCC_CPP_FLAGS_tmp:--pedantic=)}

newline newline
]


;
; LINKER FLAGS
;
; See %systems.r for the abbreviated table of linker flags per-system
;

emit ["CLIB= $(SANITIZE_LINK_FLAGS)" space]

emit case [
    any [blank? args/STATIC | args/STATIC = "no"] [
        ;
        ; !!! Is there a way to explicitly request dynamic linking?
        ;
        {}
    ]
    args/STATIC = "yes" [
        join-of either sanitize ["-static-libasan "][{}]
        either cplusplus [
            unspaced ["-static-libgcc -static-libstdc++" space]
        ][
            unspaced ["-static-libgcc" space]
        ]
    ]
    true [
        fail ["STATIC needs to be yes or no, not" (args/STATIC)]
    ]
] 

for-each [flag switches] linker-flags [
    if all [flag? (flag) | switches] [
        emit [switches space]
    ]
]

emit newline
emit newline


;
; REBOL TOOLING
;

emit [
{# REBOL is needed to build various include files:
REBOL_TOOL= r3-make$(BIN_SUFFIX)
REBOL= $(CD)$(REBOL_TOOL) -qs

# For running tests, ship, build, etc.
R3_TARGET= r3$(BIN_SUFFIX)
R3= $(CD)$(R3_TARGET) -qs

### Build targets:
top:
    $(MAKE) $(R3_TARGET)

update:
    -cd $(UP)/; cvs -q update src

clean:
    @-rm -rf $(R3_TARGET) libr3.so objs/
    @-find ../src -name 'tmp-*' -exec rm -f {} \;
    @-grep -l "AUTO-GENERATED FILE" ../src/include/*.h |grep -v sys-zlib.h|xargs rm 2>/dev/null || true

all:
    $(MAKE) clean
    $(MAKE) prep
    $(MAKE) $(R3_TARGET)
    $(MAKE) lib
    $(MAKE) host$(BIN_SUFFIX)

prep: $(REBOL_TOOL)
    $(REBOL) $T/make-natives.r
    $(REBOL) $T/make-headers.r
    $(REBOL) $T/make-boot.r OS_ID=$(OS_ID) GIT_COMMIT=$(GIT_COMMIT)
    $(REBOL) $T/make-host-init.r
    $(REBOL) $T/make-os-ext.r
    $(REBOL) $T/make-host-ext.r
    $(REBOL) $T/make-reb-lib.r} newline
    ;
    ;-- more lines added to this section by the boot extensions 
]


;
; EMIT BOOT EXTENSIONS
;
; The concept in Ren-C is to allow various pieces of Rebol to be chosen as
; either built into the EXE, available as a dynamic library, or not built
; at all.  This is new work, and for starters just cryptography and image
; codecs are covered.  But the concept behind it is that even the /VIEW
; GUI behavior itself would be such an extension.
;

boot-extension-src: copy []
extensions: copy ""
for-each [is-built-in ext-name ext-src modules] file-base/extensions [
    unless '+ = is-built-in [
        continue
    ]

    unless empty? extensions [append extensions ","]
    append extensions to string! ext-name
    append/only boot-extension-src ext-src ; ext-src is a path!, /ONLY needed

    ; Though not scanned for natives, there can be additional C files
    ; specified for a module.
    ;
    for-each m modules [
        m-spec: find file-base/modules m

        ; Currently, only the extension's main C file is scanned for natives.
        ; m-spec/2 is that main C file, see %file-base.r's "modules"
        ;
        emit [
            {    $(REBOL) $T/make-ext-natives.r} space
            {MODULE=} m-spec/1 space {SRC=} m-spec/2 newline
        ]

        append/only boot-extension-src m-spec/2 ; main C file
        append boot-extension-src m-spec/3 ; other files of the module
    ]
]

emit [
    {    $(REBOL) $T/make-boot-ext-header.r EXTENSIONS=} extensions newline
]

unless any [blank? args/WITH_TCC | args/WITH_TCC = "no"] [
    emit [
    {    $(TCC) -E -dD -nostdlib -DREN_C_STDIO_OK -UHAVE_ASAN_INTERFACE_H -o ../src/include/sys-core.i $(TCC_CPP_FLAGS) $(TCC_CPP_EXTRA_FLAGS) -I../external/tcc/include ../src/include/sys-core.h} newline
    {    $(REBOL) $T/make-embedded-header.r} newline
]

    append file-base/generated [tmp-symbols.c e-embedded-header.c]
]

emit [
{zlib:
    $(REBOL) $T/make-zlib.r

### Provide more info if make fails due to no local Rebol build tool:
tmps: $S/include/tmp-bootdefs.h

$S/include/tmp-bootdefs.h: $(REBOL_TOOL)
    $(MAKE) prep

$(REBOL_TOOL):
    $(MAKE) -f makefile.boot $(REBOL_TOOL)

### Post build actions
purge:
    -rm libr3.*
    -rm host$(BIN_SUFFIX)
    $(MAKE) lib
    $(MAKE) host$(BIN_SUFFIX)

test:
    $(CP) $(R3_TARGET) $(UP)/src/tests/
    $(R3) $S/tests/test.r

install:
    sudo cp $(R3_TARGET) /usr/local/bin

ship:
    $(R3) $S/tools/upload.r

build: libr3.so
    $(R3) $S/tools/make-build.r

cln:
    rm libr3.* r3.o

check:
    $(STRIP) -s -o r3.s $(R3_TARGET)
    $(STRIP) -x -o r3.x $(R3_TARGET)
    $(STRIP) -X -o r3.X $(R3_TARGET)
    $(LS) r3*

}]


;
; EMIT OBJ FILE DEPENDENCIES
;
; !!! The use of split path to remove directory in TO-OBJ had been commented
; out, but was re-added to incorporate the paths on codecs in a stop-gap
; measure to use make-make.r with Atronix repo
;

to-obj: function [
    "Create .o object filename (with no dir path)."
    file
][
    file: (comment [to-file file] second split-path to-file file)
    head change back tail file "o"
]

emit-obj-files: procedure [
    "Output a line-wrapped list of object files."
    file-list [block!]
][
    num-on-line: 0
    pending: _
    for-each item file-list [
        if pending [
            emit pending
            pending: _
        ]

        file: either block? item [first item] [item]

        emit [%objs/ to-obj file space]
        
        if num-on-line = 4 [
            pending: unspaced ["\" newline spaced-tab]
            num-on-line: 0
        ]
        num-on-line: num-on-line + 1
    ]
    emit [newline newline]
]

emit ["OBJS =" space]
emit-obj-files compose [
    (file-base/core) (file-base/generated) (boot-extension-src)
]

emit ["HOST =" space]
emit-obj-files compose [
    (file-base/os) (os-specific-objs)
]

emit {
# Directly linked r3 executable:
$(R3_TARGET): tmps objs $(OBJS) $(HOST)
    $(CC) -o $(R3_TARGET) $(OBJS) $(HOST) $(CLIB) $(FFI_LIBS) $(TCC_LINK_FLAGS) $(TCC_LIBS)
    $(STRIP) $(R3_TARGET)
    $(LS) $(R3_TARGET)

objs:
    mkdir -p objs
}


;
; EMIT STATIC OR DYNAMIC LIBRARY
;
; Depending on the kind of target being built the R3-library can be either
; static or dynamic
;

makefile-so: {
lib: libr3.so

# PUBLIC: Shared library:
# NOTE: Did not use "-Wl,-soname,libr3.so" because won't find .so in local dir.
libr3.so: $(OBJS)
    $(CC) -o libr3.so -shared $(OBJS) $(CLIB) $(FFI_LIBS)
    $(STRIP) libr3.so
    $(LS) libr3.so

# PUBLIC: Host using the shared lib:
host$(BIN_SUFFIX): $(HOST)
    $(CC) -o host$(BIN_SUFFIX) $(HOST) libr3.so $(CLIB)
    $(STRIP) host$(BIN_SUFFIX)
    $(LS) host$(BIN_SUFFIX)
    echo "export LD_LIBRARY_PATH=.:$LD_LIBRARY_PATH"
}

makefile-dyn: {
lib: libr3.dylib

# Private static library (to be used below for OSX):
libr3.dylib: $(OBJS)
    ld -r -o r3.o $(OBJS)
    $(CC) -dynamiclib -o libr3.dylib r3.o $(CLIB)
    $(STRIP) -x libr3.dylib
    $(LS) libr3.dylib

# PUBLIC: Host using the shared lib:
host$(BIN_SUFFIX): $(HOST)
    $(CC) -o host$(BIN_SUFFIX) $(HOST) libr3.dylib $(CLIB)
    $(STRIP) host$(BIN_SUFFIX)
    $(LS) host$(BIN_SUFFIX)
    echo "export LD_LIBRARY_PATH=.:$LD_LIBRARY_PATH"
}

not-used: {
# PUBLIC: Static library (to distrirbute) -- does not work!
libr3.lib: r3.o
    ld -static -r -o libr3.lib r3.o
    $(STRIP) libr3.lib
    $(LS) libr3.lib
}

either config/id/2 = 2 [
    emit makefile-dyn
][
    emit makefile-so
] 


;
; EMIT FILE DEPENDENCIES
;
; !!! Because of how much scanning of header files to build temporary files
; there is, it's very hard to tell what kinds of changes to the source will
; necessitate a full build vs. an incremental one.  So the dependencies list
; is not as useful as it is for many makefiles, as full builds are usually
; required.
;

emit-file-deps: function [
    "Emit compiler and file dependency lines."
    file-list
    /dir path  ; from path
][
    for-each item file-list [
        ;
        ; Item may be like foo.c, or [foo.c <option1> <option2>]
        ; Make sure it's a block so it can be uniformly searched for options
        ;
        unless block? item [item: reduce [item]]
        
        file: first item

        obj: unspaced [%objs/ (to-obj file)]

        src: either not dir [
            unspaced ["$R/" file]
        ][
            unspaced ["$S/" path file]
        ]

        emit-line [obj ":" space src]

        file-specific-flags: copy ""
        if rigorous [
            for-each [setting switches] [
                <no-uninitialized> "-Wno-uninitialized"
                <no-unused-parameter> "-Wno-unused-parameter"
                <no-shift-negative-value> "-Wno-shift-negative-value"
            ][
                if not find item setting [continue]

                if not empty? file-specific-flags [
                    append file-specific-flags space
                ]
                append file-specific-flags switches
            ]
        ]

        emit-line/indent spaced [
            "$(CC) -c"
            pick ["$(RFLAGS)" "$(HFLAGS)"] not dir
            file-specific-flags
            src
            "-o"
            obj
        ]

        emit newline
    ]
]

emit {
### File build targets:
tmp-boot-block.c: $(SRC)/boot/tmp-boot-block.r
    $(REBOL) -sqw $(SRC)/tools/make-boot.r
}
emit newline

emit-file-deps file-base/core
emit-file-deps file-base/generated
emit-file-deps boot-extension-src

emit-file-deps/dir file-base/os %os/
emit-file-deps/dir os-specific-objs %os/


;
; OUTPUT MAKEFILE AND CREATE OBJ DIRECTORY
;
; Unfortunately, GNU make requires you use tab characters to indent, as part
; of the file format.  This code uses 4 spaces instead, but then converts to
; tabs at the last minute--so this Rebol source file doesn't need to have
; actual tab characters in it.
;
make-dir path-make
write-emitted/tabbed path-make/makefile
make-dir path-make/objs

print ["Created:" path-make/makefile]
