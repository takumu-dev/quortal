include_guard(GLOBAL)

# Checks that run the game, each through run_game.cmake, in its own folder
# in tests.dir

# Adds the check NAME, labelled LABEL, which runs the target GAME with ARGS.
# It passes when the game exits cleanly within TIMEOUT seconds, with each of
# EXPECT somewhere in its console log. With LINES, a regular expression, the
# log's lines that match it must be matched one for one by the regular
# expressions in EXPECT_LINES, and with no EXPECT_LINES there must be none.
# With TWICE, those lines are printed twice over, as a client's server and
# its cgame both print them: the first half of them must be matched so, and
# the second half must repeat the first.
#
# With MAP, a .map file, the map is compiled for the check alone, in its own
# folder, and the game finds it there before the copy in quortal.pk3. With
# NO_CUSTINFOPARMS, it's compiled without -custinfoparms
function(add_game_test NAME)
    cmake_parse_arguments(ARG "TWICE;NO_CUSTINFOPARMS" "GAME;LABEL;TIMEOUT;LINES;MAP" "ARGS;EXPECT;EXPECT_LINES" ${ARGN})

    set(RUN_GAME_SCRIPT ${CMAKE_SOURCE_DIR}/cmake/utils/run_game.cmake)

    if(ARG_GAME STREQUAL CLIENT_BINARY)
        set(CLIENT ON)
    else()
        set(CLIENT OFF)
    endif()

    set(MAP_OPTIONS "")
    if(ARG_MAP)
        if(ARG_NO_CUSTINFOPARMS)
            set(CUSTINFOPARMS OFF)
        else()
            set(CUSTINFOPARMS ON)
        endif()

        set(MAP_OPTIONS
            -DMAP_FILE=${ARG_MAP}
            -DQ3MAP2=${Q3MAP2}
            -DDATA_DIR=${CMAKE_SOURCE_DIR}/data
            -DCUSTINFOPARMS=${CUSTINFOPARMS})
    endif()

    add_test(NAME ${NAME}
        COMMAND ${CMAKE_COMMAND}
            -DGAME=$<TARGET_FILE:${ARG_GAME}>
            -DBASEGAME=${BASEGAME}
            -DRUN_DIR=${CMAKE_BINARY_DIR}/tests.dir/$<CONFIG>/${NAME}
            -DTIMEOUT=${ARG_TIMEOUT}
            -DCLIENT=${CLIENT}
            -DOPENGL_DIR=${TEST_OPENGL_DIR}
            "-DARGS=${ARG_ARGS}"
            "-DEXPECT=${ARG_EXPECT}"
            "-DLINES=${ARG_LINES}"
            "-DEXPECT_LINES=${ARG_EXPECT_LINES}"
            -DTWICE=${ARG_TWICE}
            ${MAP_OPTIONS}
            -P ${RUN_GAME_SCRIPT})

    # The game is stopped at TIMEOUT, so that its log can still be shown.
    # CTest's own timeout, a little later, is for the script
    math(EXPR CTEST_TIMEOUT "${ARG_TIMEOUT} + 30")

    # run_game.cmake says this when a client can't open a window
    set_tests_properties(${NAME} PROPERTIES
        LABELS ${ARG_LABEL}
        TIMEOUT ${CTEST_TIMEOUT}
        SKIP_REGULAR_EXPRESSION "Skipped: there's no display")
endfunction()
