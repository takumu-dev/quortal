# q3map2 compiles the test maps. It's fetched on demand, never by the default
# build: "--target q3map2" extracts it from NetRadiant-custom's release into
# the build tree. A Q3MAP2 given when configuring, and then a q3map2 on PATH,
# are used before that one

set(Q3MAP2_DIR ${CMAKE_BINARY_DIR}/q3map2)
set(FETCH_Q3MAP2_SCRIPT ${CMAKE_SOURCE_DIR}/cmake/utils/fetch_q3map2.cmake)

find_program(Q3MAP2 q3map2
    PATHS ${Q3MAP2_DIR}/bin
    DOC "NetRadiant-custom's q3map2, which compiles the test maps")

# Until q3map2 is found, fetching it makes the next build configure again,
# which then finds it
if(NOT Q3MAP2)
    set(Q3MAP2_FETCHED ${CMAKE_BINARY_DIR}/q3map2.fetched)
    file(TOUCH ${Q3MAP2_FETCHED})
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${Q3MAP2_FETCHED})
    set(TOUCH_FETCHED_COMMAND COMMAND ${CMAKE_COMMAND} -E touch ${Q3MAP2_FETCHED})
endif()

add_custom_target(q3map2
    COMMAND ${CMAKE_COMMAND}
        -DQ3MAP2_DIR=${Q3MAP2_DIR}
        -P ${FETCH_Q3MAP2_SCRIPT}
    ${TOUCH_FETCHED_COMMAND}
    USES_TERMINAL
    VERBATIM)
