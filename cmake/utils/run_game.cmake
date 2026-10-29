# Run quortal or quortal-ded for a check, then check its console log

# GAME, BASEGAME, RUN_DIR and TIMEOUT must be set via -D. GAME is run with
# ARGS, and the check passes when it exits cleanly within TIMEOUT seconds,
# with each of EXPECT somewhere in its console log. When LINES is set, the
# log's lines that match it must also be those of EXPECT_LINES, one for one:
# each regular expression in EXPECT_LINES matches exactly one of them, and
# there are no more of them than there are of EXPECT_LINES. With TWICE, those
# lines are printed twice over, as a client's server and then its cgame both
# print them: the second half of them must repeat the first, line for line,
# and the first half must be those of EXPECT_LINES
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
# When MAP_FILE is set, that map is first compiled into the home folder,
# where the game finds it before the copy in quortal.pk3, by
# compile_map.cmake with Q3MAP2, DATA_DIR and CUSTINFOPARMS. Its work folder
# is in RUN_DIR too.
#
# The client, when CLIENT is set, opens a 640x480 window without MSAA, and
# every frame moves the game on by 8 msec, however long it took. On Linux
# and the BSDs without a display, it runs under xvfb-run, and without that
# the check is skipped. On Windows, when OPENGL_DIR is set, the client loads
# the OpenGL DLLs in it in place of the system's

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

if(MAP_FILE)
    get_filename_component(MAP_NAME ${MAP_FILE} NAME_WE)
    execute_process(
        COMMAND ${CMAKE_COMMAND}
            -DQ3MAP2=${Q3MAP2}
            -DMAP_FILE=${MAP_FILE}
            -DBSP_FILE=${HOME_DIR}/${BASEGAME}/maps/${MAP_NAME}.bsp
            -DDATA_DIR=${DATA_DIR}
            -DGAME_DIR=${BASE_DIR}/${BASEGAME}
            -DWORK_DIR=${RUN_DIR}/map
            -DCUSTINFOPARMS=${CUSTINFOPARMS}
            -P ${CMAKE_CURRENT_LIST_DIR}/compile_map.cmake
        RESULT_VARIABLE RESULT)

    if(NOT RESULT EQUAL 0)
        message(FATAL_ERROR "${MAP_NAME} couldn't be compiled for the check")
    endif()
endif()

# Windows loads opengl32.dll from the folder of the program it starts
# before its own, so the client runs from a folder in RUN_DIR, which holds
# links to it and the DLLs beside it, and to OPENGL_DIR's DLLs. The game's
# own files are still read from beside the client it links to
if(CMAKE_HOST_WIN32 AND CLIENT AND OPENGL_DIR)
    file(GLOB OPENGL_LIBRARIES ${OPENGL_DIR}/*.dll)
    if(NOT OPENGL_LIBRARIES)
        message(FATAL_ERROR "${OPENGL_DIR} has no OpenGL DLLs for the client")
    endif()

    set(BIN_DIR ${RUN_DIR}/bin)
    file(MAKE_DIRECTORY ${BIN_DIR})

    file(GLOB LIBRARIES ${BASE_DIR}/*.dll)
    foreach(FILE IN ITEMS ${GAME} ${LIBRARIES} ${OPENGL_LIBRARIES})
        get_filename_component(NAME ${FILE} NAME)
        file(CREATE_LINK ${FILE} ${BIN_DIR}/${NAME} COPY_ON_ERROR)
    endforeach()

    set(GAME ${BIN_DIR}/${GAME_NAME})
endif()

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

if(LINES)
    # Split into lines first, as . matches a line's end too
    string(REGEX MATCHALL "[^\n]+" LOG_LINES "${LOG}")
    set(MATCHED_LINES "")
    foreach(LINE IN LISTS LOG_LINES)
        if(LINE MATCHES "${LINES}")
            list(APPEND MATCHED_LINES "${LINE}")
        endif()
    endforeach()

    if(TWICE)
        list(LENGTH MATCHED_LINES LINE_COUNT)
        math(EXPR HALF_COUNT "${LINE_COUNT} / 2")
        list(SUBLIST MATCHED_LINES 0 ${HALF_COUNT} FIRST_LINES)
        list(SUBLIST MATCHED_LINES ${HALF_COUNT} -1 SECOND_LINES)

        if(NOT FIRST_LINES STREQUAL SECOND_LINES)
            list(APPEND FAILURES "the second half of its lines with \"${LINES}\" don't repeat the first")
        endif()

        set(MATCHED_LINES ${FIRST_LINES})
    endif()

    foreach(EXPECTED IN LISTS EXPECT_LINES)
        set(MATCH_COUNT 0)
        foreach(LINE IN LISTS MATCHED_LINES)
            if(LINE MATCHES "${EXPECTED}")
                math(EXPR MATCH_COUNT "${MATCH_COUNT} + 1")
            endif()
        endforeach()

        if(NOT MATCH_COUNT EQUAL 1)
            list(APPEND FAILURES "${MATCH_COUNT} of its lines with \"${LINES}\" match \"${EXPECTED}\", not 1")
        endif()
    endforeach()

    list(LENGTH MATCHED_LINES LINE_COUNT)
    list(LENGTH EXPECT_LINES EXPECTED_COUNT)
    if(NOT LINE_COUNT EQUAL EXPECTED_COUNT)
        list(APPEND FAILURES "${LINE_COUNT} of its lines have \"${LINES}\", not ${EXPECTED_COUNT}")
    endif()
endif()

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
