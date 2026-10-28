include_guard(GLOBAL)

# Downloads kept in the user's cache folder, for the fetch scripts, which run
# in script mode (cmake -P). Each file is downloaded once, into quortal's
# folder there: ~/.cache/quortal (or $XDG_CACHE_HOME/quortal),
# %LOCALAPPDATA%\quortal or ~/Library/Caches/quortal

# Sets VAR to quortal's folder in the user's cache folder
function(get_cache_dir VAR)
    if(CMAKE_HOST_WIN32)
        file(TO_CMAKE_PATH "$ENV{LOCALAPPDATA}" CACHE_DIR)
    elseif(CMAKE_HOST_APPLE)
        set(CACHE_DIR "$ENV{HOME}/Library/Caches")
    elseif(NOT "$ENV{XDG_CACHE_HOME}" STREQUAL "")
        set(CACHE_DIR "$ENV{XDG_CACHE_HOME}")
    else()
        set(CACHE_DIR "$ENV{HOME}/.cache")
    endif()

    if(NOT IS_ABSOLUTE "${CACHE_DIR}")
        message(FATAL_ERROR "Can't find the user's cache folder")
    endif()

    set(${VAR} ${CACHE_DIR}/quortal PARENT_SCOPE)
endfunction()

# Sets REASON to why FILE doesn't have the given SHA256, or SIZE when that's
# given too, or to nothing if it does
function(check_cached_file FILE SHA256 SIZE REASON)
    if(SIZE)
        file(SIZE ${FILE} FILE_SIZE)
        if(NOT FILE_SIZE EQUAL SIZE)
            set(${REASON} "it's ${FILE_SIZE} bytes, not ${SIZE}" PARENT_SCOPE)
            return()
        endif()
    endif()

    file(SHA256 ${FILE} FILE_SHA256)
    if(NOT FILE_SHA256 STREQUAL SHA256)
        set(${REASON} "its SHA-256 is ${FILE_SHA256}, not ${SHA256}" PARENT_SCOPE)
        return()
    endif()

    set(${REASON} "" PARENT_SCOPE)
endfunction()

# Sets VAR to the path of NAME in the cache folder, first downloading it
# from the first of URLS that gives it whole, unless it's there already.
# It must have the given SHA256, and SIZE when that's given too. A file in
# the cache folder that doesn't is discarded
function(fetch_to_cache NAME VAR)
    cmake_parse_arguments(ARG "" "SHA256;SIZE" "URLS" ${ARGN})

    get_cache_dir(CACHE_DIR)
    set(FILE ${CACHE_DIR}/${NAME})
    set(PART_FILE ${FILE}.part)

    if(EXISTS ${FILE})
        check_cached_file(${FILE} ${ARG_SHA256} "${ARG_SIZE}" REASON)
        if(REASON)
            message(WARNING "Discarding ${FILE}: ${REASON}")
            file(REMOVE ${FILE})
        endif()
    endif()

    if(NOT EXISTS ${FILE})
        foreach(URL IN LISTS ARG_URLS)
            message(STATUS "Downloading ${URL}")
            file(DOWNLOAD ${URL} ${PART_FILE}
                STATUS STATUS
                INACTIVITY_TIMEOUT 60
                SHOW_PROGRESS)

            list(GET STATUS 0 STATUS_CODE)
            if(STATUS_CODE EQUAL 0)
                check_cached_file(${PART_FILE} ${ARG_SHA256} "${ARG_SIZE}" REASON)
            else()
                list(GET STATUS 1 REASON)
            endif()

            if(NOT REASON)
                file(RENAME ${PART_FILE} ${FILE})
                break()
            endif()

            message(WARNING "Couldn't download ${URL}: ${REASON}")
            file(REMOVE ${PART_FILE})
        endforeach()
    endif()

    if(NOT EXISTS ${FILE})
        message(FATAL_ERROR "Couldn't download ${NAME}. "
            "The steps to fetch it by hand are at the top of ${CMAKE_CURRENT_LIST_FILE}")
    endif()

    set(${VAR} ${FILE} PARENT_SCOPE)
endfunction()
