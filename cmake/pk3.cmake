# quortal.pk3 carries quortal's game code as QVMs, with quortal's data. The
# paks in a game folder that sort last are searched first, and quortal.pk3
# sorts after every one of OpenArena's, so its QVMs are the ones loaded,
# whether the server is pure or not

include(utils/add_pk3)

if(NOT BUILD_GAME_QVMS)
    message(WARNING "BUILD_GAME_QVMS is off, so ${BASEGAME}.pk3 carries no "
        "game code, and a pure server runs OpenArena's")
endif()

add_pk3(${BASEGAME}
    DATA_DIRECTORY ${CMAKE_SOURCE_DIR}/data
    OUTPUT_DIRECTORY ${BASEGAME})
