# Zip a pk3 from the files its manifest lists

# PK3_FILE, MANIFEST and STAGING_DIR must be set via -D

# The manifest, written by add_pk3, sets DATA_FILES, each of which goes in
# at its path in DATA_DIR, and BUILT_FILES, each of which goes in at its
# path in BUILD_DIR. They're gathered in STAGING_DIR, afresh each time,
# which is then zipped whole

if(NOT PK3_FILE OR NOT MANIFEST OR NOT STAGING_DIR)
    message(FATAL_ERROR "PK3_FILE, MANIFEST and STAGING_DIR must be set")
endif()

include(${MANIFEST})

file(REMOVE_RECURSE ${STAGING_DIR})
file(MAKE_DIRECTORY ${STAGING_DIR})

# Copies each of FILES into STAGING_DIR at its path in BASE_DIR
function(stage_files BASE_DIR)
    foreach(FILE IN LISTS ARGN)
        file(RELATIVE_PATH PATH ${BASE_DIR} ${FILE})
        get_filename_component(DIR ${STAGING_DIR}/${PATH} DIRECTORY)
        file(COPY ${FILE} DESTINATION ${DIR})
    endforeach()
endfunction()

stage_files(${DATA_DIR} ${DATA_FILES})
stage_files(${BUILD_DIR} ${BUILT_FILES})

file(GLOB_RECURSE PATHS RELATIVE ${STAGING_DIR} ${STAGING_DIR}/*)

# Zip it beside the pk3 and then move it over the pk3, so that a game
# running from the build never reads one half written
execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar cf ${PK3_FILE}.part --format=zip -- ${PATHS}
    WORKING_DIRECTORY ${STAGING_DIR}
    COMMAND_ERROR_IS_FATAL ANY)

file(RENAME ${PK3_FILE}.part ${PK3_FILE})
file(REMOVE_RECURSE ${STAGING_DIR})
