REBOL []

name: 'Time
source: %time/mod-time.c
includes: [
    %prep/extensions/time
]

depends: compose [
    (switch system-config/os-base [
        'Windows [
            [%time/time-windows.c]
        ]

        default [
            [%time/time-posix.c]
        ]
    ])
]

