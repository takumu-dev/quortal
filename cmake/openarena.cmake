# OpenArena's data is fetched on demand, never by the default build or
# install: "--target openarena" fetches it into the build tree, and
# "--install <dir> --component openarena" into the install prefix

set(FETCH_OPENARENA_SCRIPT ${CMAKE_SOURCE_DIR}/cmake/utils/fetch_openarena.cmake)

add_custom_target(openarena
    COMMAND ${CMAKE_COMMAND}
        -DGAME_DIR=${CMAKE_BINARY_DIR}/$<CONFIG>/${BASEGAME}
        -P ${FETCH_OPENARENA_SCRIPT}
    USES_TERMINAL
    VERBATIM)

install(CODE "
    execute_process(
        COMMAND \"${CMAKE_COMMAND}\"
            \"-DGAME_DIR=\${CMAKE_INSTALL_PREFIX}/${BASEGAME}\"
            -P \"${FETCH_OPENARENA_SCRIPT}\"
        COMMAND_ERROR_IS_FATAL ANY)"
    COMPONENT openarena
    EXCLUDE_FROM_ALL)
