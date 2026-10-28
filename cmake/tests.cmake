# quortal's checks, run with ctest. Each is labelled by what it needs:
#
#   - docs: git, and the source's history;
#   - server: the dedicated server and the test maps;
#   - render: the client, the test maps, and OpenGL with 8 stencil bits.
#
# Without q3map2 there are no test maps, so the checks that need them are
# disabled, and ctest runs the rest. So is the docs check without the
# source's history, as in a source archive

include(utils/add_game_test)

enable_testing()

# The docs' links, identifiers and excerpts are checked against the source,
# and the chapters' lists of commits against its history
add_test(NAME docs_hold_true
    COMMAND ${CMAKE_COMMAND}
        -DSOURCE_DIR=${CMAKE_SOURCE_DIR}
        -P ${CMAKE_SOURCE_DIR}/cmake/utils/check_docs.cmake)
set_tests_properties(docs_hold_true PROPERTIES LABELS docs)

find_package(Git QUIET)
if(NOT GIT_FOUND OR NOT EXISTS ${CMAKE_SOURCE_DIR}/.git)
    set_tests_properties(docs_hold_true PROPERTIES DISABLED TRUE)
endif()

# On Windows, a check's client can load other OpenGL DLLs than the system's,
# such as Mesa's, which render in software on a machine with no GPU and
# which cmake/utils/fetch_mesa.cmake fetches
if(WIN32)
    set(TEST_OPENGL_DIR "" CACHE PATH "OpenGL DLLs for the checks' client to load")
endif()

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

if(BUILD_CLIENT)
    # The renderer reports its stencil bits as it starts. A renderer that
    # fails to load is a fatal error, so a client that tried GL1's and exits
    # cleanly ran on GL1. activeAction runs once the client is in the game,
    # after it has drawn its first frame
    set(RENDER_EXPECT "stencil(8-bits)")
    if(USE_RENDERER_DLOPEN)
        list(APPEND RENDER_EXPECT "renderer_opengl1")
    endif()

    add_game_test(client_opens_gl1_with_8_stencil_bits
        GAME ${CLIENT_BINARY}
        LABEL render
        TIMEOUT 120
        ARGS +set activeAction quit +devmap test_first
        EXPECT ${RENDER_EXPECT})
    list(APPEND MAP_TESTS client_opens_gl1_with_8_stencil_bits)
endif()

if(MAP_TESTS AND NOT Q3MAP2)
    set_tests_properties(${MAP_TESTS} PROPERTIES DISABLED TRUE)
endif()
