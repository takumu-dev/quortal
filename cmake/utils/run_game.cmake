# Run quortal or quortal-ded for a check, then check its console log

# GAME, BASEGAME, RUN_DIR and TIMEOUT must be set via -D. GAME is run with
# ARGS, and the check passes when it exits cleanly within TIMEOUT seconds,
# with each of EXPECT somewhere in its console log
#
# Each run starts from an empty RUN_DIR, and writes nothing outside it. The
# game is given:
#
#   - a fresh home folder in RUN_DIR, so that no user config, PID file or
#     earlier output is read, and no XDG migration is offered;
#   - logfile 2, so that the console log is written as it's printed, and is
#     whole even when the game crashes;
#   - on Linux and the BSDs, a PATH starting with zenity, kdialog and
#     xmessage programs that exit at once, so that an error dialog never
#     waits for a click. On Windows one waits for the timeout.
#
# The client, when CLIENT is set, opens a 640x480 window without MSAA, and
# every frame moves the game on by 8 msec, however long it took. On Linux
# and the BSDs without a display, it runs under xvfb-run, and without that
# the check is skipped

foreach(VAR GAME BASEGAME RUN_DIR TIMEOUT)
    if(NOT ${VAR})
        message(FATAL_ERROR "${VAR} must be set")
    endif()
endforeach()

get_filename_component(GAME_NAME ${GAME} NAME)
get_filename_component(BASE_DIR ${GAME} DIRECTORY)

file(REMOVE_RECURSE ${RUN_DIR})
set(HOME_DIR ${RUN_DIR}/home)
file(MAKE_DIRECTORY ${HOME_DIR})

if(CMAKE_HOST_UNIX AND NOT CMAKE_HOST_APPLE)
    set(STUB_DIR ${RUN_DIR}/stubs)
    foreach(PROGRAM zenity kdialog xmessage)
        file(WRITE ${STUB_DIR}/${PROGRAM} "#!/bin/sh\nexit 0\n")
        file(CHMOD ${STUB_DIR}/${PROGRAM}
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE)
    endforeach()
    set(ENV{PATH} "${STUB_DIR}:$ENV{PATH}")

    # The tty console would otherwise take over a terminal ctest runs in
    set(INPUT_OPTION INPUT_FILE /dev/null)
endif()

set(COMMAND ${GAME}
    +set fs_basepath ${BASE_DIR}
    +set fs_homepath ${HOME_DIR}
    +set logfile 2)

if(CLIENT)
    list(APPEND COMMAND
        +set r_fullscreen 0
        +set r_mode 3
        +set r_ext_multisample 0
        +set fixedtime 8)

    if(CMAKE_HOST_UNIX AND NOT CMAKE_HOST_APPLE
            AND "$ENV{DISPLAY}" STREQUAL "" AND "$ENV{WAYLAND_DISPLAY}" STREQUAL "")
        find_program(XVFB_RUN xvfb-run)
        if(NOT XVFB_RUN)
            message("Skipped: there's no display to open a window on, and no xvfb-run to make one")
            return()
        endif()

        list(PREPEND COMMAND ${XVFB_RUN} -a -s "-screen 0 640x480x24")
    endif()
endif()

list(APPEND COMMAND ${ARGS})

execute_process(
    COMMAND ${COMMAND}
    WORKING_DIRECTORY ${RUN_DIR}
    ${INPUT_OPTION}
    OUTPUT_VARIABLE OUTPUT
    ERROR_VARIABLE OUTPUT
    RESULT_VARIABLE RESULT
    TIMEOUT ${TIMEOUT})

set(LOG_FILE ${HOME_DIR}/${BASEGAME}/qconsole.log)
set(LOG "")
if(EXISTS ${LOG_FILE})
    file(READ ${LOG_FILE} LOG)
endif()

set(FAILURES "")
if(NOT RESULT STREQUAL "0")
    list(APPEND FAILURES "it exited with \"${RESULT}\"")
endif()

foreach(TEXT IN LISTS EXPECT)
    string(FIND "${LOG}" "${TEXT}" POSITION)
    if(POSITION EQUAL -1)
        list(APPEND FAILURES "its console log has no \"${TEXT}\"")
    endif()
endforeach()

if(FAILURES)
    # The log starts once the filesystem is up, so a game that fails before
    # then has only what it printed
    if(LOG)
        message("${LOG_FILE}:\n${LOG}")
    else()
        message("${GAME_NAME} wrote no console log, but printed:\n${OUTPUT}")
    endif()

    list(JOIN ARGS " " ARGS)
    list(JOIN FAILURES ", and " FAILURES)
    message(FATAL_ERROR "${GAME_NAME} ${ARGS} failed: ${FAILURES}")
endif()
