include_guard(GLOBAL)

# Checks that run the game, each through run_game.cmake, in its own folder
# in tests.dir

# Adds the check NAME, labelled LABEL, which runs the target GAME with ARGS.
# It passes when the game exits cleanly within TIMEOUT seconds, with each of
# EXPECT somewhere in its console log
function(add_game_test NAME)
    cmake_parse_arguments(ARG "" "GAME;LABEL;TIMEOUT" "ARGS;EXPECT" ${ARGN})

    set(RUN_GAME_SCRIPT ${CMAKE_SOURCE_DIR}/cmake/utils/run_game.cmake)

    add_test(NAME ${NAME}
        COMMAND ${CMAKE_COMMAND}
            -DGAME=$<TARGET_FILE:${ARG_GAME}>
            -DBASEGAME=${BASEGAME}
            -DRUN_DIR=${CMAKE_BINARY_DIR}/tests.dir/$<CONFIG>/${NAME}
            -DTIMEOUT=${ARG_TIMEOUT}
            "-DARGS=${ARG_ARGS}"
            "-DEXPECT=${ARG_EXPECT}"
            -P ${RUN_GAME_SCRIPT})

    # The game is stopped at TIMEOUT, so that its log can still be shown.
    # CTest's own timeout, a little later, is for the script
    math(EXPR CTEST_TIMEOUT "${ARG_TIMEOUT} + 30")

    set_tests_properties(${NAME} PROPERTIES
        LABELS ${ARG_LABEL}
        TIMEOUT ${CTEST_TIMEOUT})
endfunction()
