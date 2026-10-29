# Compile a map with q3map2, through its BSP, vis and light stages

# Q3MAP2, MAP_FILE, BSP_FILE, DATA_DIR, GAME_DIR and WORK_DIR must be set
# via -D. With CUSTINFOPARMS set OFF, -custinfoparms is left out of every
# stage, as a build that forgot it would leave it out

# q3map2 reads the shaders and textures in DATA_DIR, quortal's data folder,
# and OpenArena's common shaders from its paks in GAME_DIR, but not
# quortal.pk3 there, which may hold older copies of quortal's own. MAP_FILE
# is compiled in WORK_DIR, afresh each time, which keeps the log and what
# q3map2 writes beside the map (a leaked map's .lin among them), and the
# compiled map is then copied to BSP_FILE

foreach(VAR Q3MAP2 MAP_FILE BSP_FILE DATA_DIR GAME_DIR WORK_DIR)
    if(NOT ${VAR})
        message(FATAL_ERROR "${VAR} must be set")
    endif()
endforeach()

if(NOT DEFINED CUSTINFOPARMS)
    set(CUSTINFOPARMS ON)
endif()

get_filename_component(NAME ${MAP_FILE} NAME_WE)

if(NOT EXISTS ${GAME_DIR}/pak0.pk3)
    message(FATAL_ERROR "Can't compile ${NAME}: q3map2 reads OpenArena's common "
        "shaders from its paks, which aren't in ${GAME_DIR}. Build the openarena "
        "target to fetch them")
endif()

file(REMOVE_RECURSE ${WORK_DIR})
file(MAKE_DIRECTORY ${WORK_DIR})
file(COPY ${MAP_FILE} DESTINATION ${WORK_DIR})

# The home path is set as well as the base path, or q3map2 also reads
# ~/.q3a/data on Linux
get_filename_component(DATA_PARENT_DIR ${DATA_DIR} DIRECTORY)
get_filename_component(DATA_DIR_NAME ${DATA_DIR} NAME)
set(PATH_ARGS
    -fs_basepath ${DATA_PARENT_DIR}
    -fs_homepath ${DATA_PARENT_DIR}
    -fs_basegame ${DATA_DIR_NAME}
    -fs_pakpath ${GAME_DIR}
    -fs_forbiddenpath quortal.pk3)

set(LOG_FILE ${WORK_DIR}/${NAME}.log)

# Runs q3map2's STAGE on the map, showing its warnings, or all it printed
# if it fails
function(run_stage STAGE)
    set(OPTIONS ${ARGN})
    if(NOT CUSTINFOPARMS)
        list(REMOVE_ITEM OPTIONS -custinfoparms)
    endif()

    execute_process(
        COMMAND ${Q3MAP2} ${PATH_ARGS} ${STAGE} ${OPTIONS} ${WORK_DIR}/${NAME}.map
        WORKING_DIRECTORY ${WORK_DIR}
        OUTPUT_VARIABLE OUTPUT
        ERROR_VARIABLE OUTPUT
        RESULT_VARIABLE RESULT)

    file(APPEND ${LOG_FILE} "${OUTPUT}")

    if(NOT RESULT EQUAL 0)
        message(FATAL_ERROR "q3map2 ${STAGE} failed on ${NAME}:\n${OUTPUT}")
    endif()

    string(REGEX MATCHALL "[^\n]*WARNING[^\n]*" WARNINGS "${OUTPUT}")
    foreach(WARNING IN LISTS WARNINGS)
        message(STATUS "${NAME}: ${WARNING}")
    endforeach()
endfunction()

# custinfoparms.txt gives quortal's own surface parameters their bits
run_stage(-bsp -meta -leaktest -custinfoparms)

# A map that leaks would have no vis. With -leaktest, q3map2 then stops
# before writing the .bsp, but without failing
if(NOT EXISTS ${WORK_DIR}/${NAME}.bsp)
    message(FATAL_ERROR "${NAME} leaks: the way out of it is in ${WORK_DIR}/${NAME}.lin, "
        "which an editor can show as a pointfile")
endif()

run_stage(-vis)
run_stage(-light -fast -samples 2 -custinfoparms)

get_filename_component(BSP_DIR ${BSP_FILE} DIRECTORY)
file(MAKE_DIRECTORY ${BSP_DIR})
file(COPY_FILE ${WORK_DIR}/${NAME}.bsp ${BSP_FILE})
