include_guard(GLOBAL)

# A pk3 is zipped from a data folder in the source tree and from files built
# for it, which are built into the pk3's own build folder, at the paths they
# take in the pk3

# Sets VAR to the folder that the files built for NAME.pk3 go in
function(get_pk3_build_dir NAME VAR)
    set(${VAR} ${CMAKE_BINARY_DIR}/pk3.dir/$<CONFIG>/${NAME} PARENT_SCOPE)
endfunction()

# Adds FILES, built into NAME.pk3's build folder by TARGET, to that pk3
function(add_pk3_files NAME TARGET)
    get_property(PK3_ADDED GLOBAL PROPERTY PK3_ADDED_${NAME})
    if(PK3_ADDED)
        message(FATAL_ERROR "Files added to ${NAME}.pk3 after add_pk3(${NAME})")
    endif()

    set_property(GLOBAL APPEND PROPERTY PK3_TARGETS_${NAME} ${TARGET})
    set_property(GLOBAL APPEND PROPERTY PK3_FILES_${NAME} ${ARGN})
endfunction()

# Zips NAME.pk3 into OUTPUT_DIRECTORY in the config folder, from every file
# in DATA_DIRECTORY but the .map sources, and from the files added to it
# with add_pk3_files, which must come first
function(add_pk3 NAME)
    list(REMOVE_AT ARGV 0)
    cmake_parse_arguments(ARG "" "DATA_DIRECTORY;OUTPUT_DIRECTORY" "" ${ARGV})

    set_property(GLOBAL PROPERTY PK3_ADDED_${NAME} TRUE)

    get_pk3_build_dir(${NAME} PK3_BUILD_DIR)
    get_property(PK3_TARGETS GLOBAL PROPERTY PK3_TARGETS_${NAME})
    get_property(PK3_FILES GLOBAL PROPERTY PK3_FILES_${NAME})

    file(GLOB_RECURSE DATA_FILES CONFIGURE_DEPENDS ${ARG_DATA_DIRECTORY}/*)
    list(FILTER DATA_FILES EXCLUDE REGEX "\\.map$")

    # The manifest lists what goes in the pk3. It's only rewritten when that
    # changes, so the pk3 is zipped again when a file is removed, too
    set(PK3_MANIFEST ${PK3_BUILD_DIR}.cmake)
    string(CONCAT PK3_MANIFEST_CONTENT
        "set(DATA_DIR \"${ARG_DATA_DIRECTORY}\")\n"
        "set(DATA_FILES \"${DATA_FILES}\")\n"
        "set(BUILD_DIR \"${PK3_BUILD_DIR}\")\n"
        "set(BUILT_FILES \"${PK3_FILES}\")\n")
    file(GENERATE OUTPUT ${PK3_MANIFEST} CONTENT "${PK3_MANIFEST_CONTENT}")

    set(PK3_FILE ${CMAKE_BINARY_DIR}/$<CONFIG>/${ARG_OUTPUT_DIRECTORY}/${NAME}.pk3)
    set(MAKE_PK3_SCRIPT ${CMAKE_SOURCE_DIR}/cmake/utils/make_pk3.cmake)

    string(REPLACE "${CMAKE_BINARY_DIR}/" "" PK3_FILE_COMMENT ${PK3_FILE})
    add_custom_command(
        OUTPUT ${PK3_FILE}
        COMMAND ${CMAKE_COMMAND}
            -DPK3_FILE=${PK3_FILE}
            -DMANIFEST=${PK3_MANIFEST}
            -DSTAGING_DIR=${PK3_BUILD_DIR}.staging
            -P ${MAKE_PK3_SCRIPT}
        DEPENDS ${PK3_MANIFEST} ${DATA_FILES} ${PK3_FILES} ${PK3_TARGETS} ${MAKE_PK3_SCRIPT}
        COMMENT "Zipping ${PK3_FILE_COMMENT}"
        VERBATIM)

    add_custom_target(${NAME}_pk3 ALL DEPENDS ${PK3_FILE})

    install(FILES ${PK3_FILE} DESTINATION ${ARG_OUTPUT_DIRECTORY})
endfunction()
