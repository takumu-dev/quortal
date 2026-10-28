# quortal's checks, run with ctest. Each is labelled by what it needs:
#
#   - server: the dedicated server and the test maps;
#   - render: the client, the test maps, and OpenGL with 8 stencil bits.
#
# Without q3map2 there are no test maps, so the checks that need them are
# disabled, and ctest runs the rest

include(utils/add_game_test)

enable_testing()

set(MAP_TESTS "")

if(BUILD_SERVER)
    # Its log names the game code that was loaded: OpenArena's says baseoa
    add_game_test(server_runs_quortal_game_code
        GAME ${SERVER_BINARY}
        LABEL server
        TIMEOUT 60
        ARGS +map test_first +quit
        EXPECT "gamename: ${BASEGAME}")
    list(APPEND MAP_TESTS server_runs_quortal_game_code)
endif()

if(MAP_TESTS AND NOT Q3MAP2)
    set_tests_properties(${MAP_TESTS} PROPERTIES DISABLED TRUE)
endif()
