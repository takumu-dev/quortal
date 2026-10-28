# The test maps are compiled from their .map sources in data/maps into
# quortal.pk3. Compiled maps are never part of quortal's source

include(utils/add_pk3)

if(NOT Q3MAP2)
    message(WARNING "q3map2 wasn't found, so ${BASEGAME}.pk3 is built without "
        "its maps. Build the q3map2 target to fetch it, or set Q3MAP2 to your "
        "own NetRadiant-custom q3map2")
    return()
endif()

set(DATA_DIR ${CMAKE_SOURCE_DIR}/data)
set(COMPILE_MAP_SCRIPT ${CMAKE_SOURCE_DIR}/cmake/utils/compile_map.cmake)

file(GLOB MAP_FILES CONFIGURE_DEPENDS ${DATA_DIR}/maps/*.map)

# q3map2 reads the data folder's shaders and textures, so the maps are
# compiled again when it changes
file(GLOB_RECURSE DATA_FILES CONFIGURE_DEPENDS ${DATA_DIR}/*)
list(FILTER DATA_FILES EXCLUDE REGEX "\\.map$")

get_pk3_build_dir(${BASEGAME} PK3_BUILD_DIR)

set(BSP_FILES "")
foreach(MAP_FILE IN LISTS MAP_FILES)
    get_filename_component(MAP_NAME ${MAP_FILE} NAME_WE)
    set(BSP_FILE ${PK3_BUILD_DIR}/maps/${MAP_NAME}.bsp)

    add_custom_command(
        OUTPUT ${BSP_FILE}
        COMMAND ${CMAKE_COMMAND}
            -DQ3MAP2=${Q3MAP2}
            -DMAP_FILE=${MAP_FILE}
            -DBSP_FILE=${BSP_FILE}
            -DDATA_DIR=${DATA_DIR}
            -DGAME_DIR=${CMAKE_BINARY_DIR}/$<CONFIG>/${BASEGAME}
            -DWORK_DIR=${CMAKE_BINARY_DIR}/maps.dir/$<CONFIG>/${MAP_NAME}
            -P ${COMPILE_MAP_SCRIPT}
        DEPENDS ${MAP_FILE} ${DATA_FILES} ${Q3MAP2} ${COMPILE_MAP_SCRIPT}
        COMMENT "Compiling map ${MAP_NAME}"
        VERBATIM)

    list(APPEND BSP_FILES ${BSP_FILE})
endforeach()

add_custom_target(maps ALL DEPENDS ${BSP_FILES})
add_pk3_files(${BASEGAME} maps ${BSP_FILES})
