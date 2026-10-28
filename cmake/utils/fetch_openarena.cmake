# Fetch OpenArena 0.8.8's data, which quortal runs on

# GAME_DIR must be set via -D, to the quortal folder beside the binaries

# The zip is downloaded once and kept in the user's cache folder, then
# the nine baseoa paks are extracted into GAME_DIR. To do the same by hand:
#
#   1. Download openarena-0.8.8.zip from one of the URLS below.
#   2. Check it's ZIP_SIZE bytes, and that its SHA-256 is ZIP_SHA256.
#   3. Copy the nine .pk3 files in its openarena-0.8.8/baseoa folder into
#      the quortal folder beside the binaries: build/Release/quortal in a
#      build tree, or <prefix>/quortal once installed.
#
# Never copy them into the home folder. It's searched first, so OpenArena's
# paks would outrank quortal's own.
#
# Alternatively, put the zip in the cache folder by hand (~/.cache/quortal,
# %LOCALAPPDATA%\quortal or ~/Library/Caches/quortal) and run this again,
# which checks it and extracts it without downloading anything.

set(ZIP_NAME openarena-0.8.8.zip)
set(ZIP_SIZE 425189255)
set(ZIP_SHA256 5a8faf7f5b51f351b0a1618c06b6b98a5f1a6758f1d39818de2c87df2a0bac4a)

set(URLS
    https://downloads.sourceforge.net/project/oarena/${ZIP_NAME}
    https://download.tuxfamily.org/openarena/rel/088/${ZIP_NAME})

set(PAK_DIR openarena-0.8.8/baseoa)
set(PAKS
    pak0.pk3
    pak1-maps.pk3
    pak2-players.pk3
    pak2-players-mature.pk3
    pak4-textures.pk3
    pak5-TA.pk3
    pak6-misc.pk3
    pak6-patch085.pk3
    pak6-patch088.pk3)

if(NOT GAME_DIR)
    message(FATAL_ERROR "GAME_DIR must be set")
endif()

set(MISSING_PAKS "")
foreach(PAK IN LISTS PAKS)
    if(NOT EXISTS ${GAME_DIR}/${PAK})
        list(APPEND MISSING_PAKS ${PAK})
    endif()
endforeach()

if(NOT MISSING_PAKS)
    message(STATUS "OpenArena's paks are already in ${GAME_DIR}")
    return()
endif()

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

set(ZIP_FILE ${CACHE_DIR}/quortal/${ZIP_NAME})
set(PART_FILE ${ZIP_FILE}.part)

# Sets REASON to why FILE isn't OpenArena's zip, or to nothing if it is
function(check_zip FILE REASON)
    file(SIZE ${FILE} SIZE)
    if(NOT SIZE EQUAL ZIP_SIZE)
        set(${REASON} "it's ${SIZE} bytes, not ${ZIP_SIZE}" PARENT_SCOPE)
        return()
    endif()

    file(SHA256 ${FILE} SHA256)
    if(NOT SHA256 STREQUAL ZIP_SHA256)
        set(${REASON} "its SHA-256 is ${SHA256}, not ${ZIP_SHA256}" PARENT_SCOPE)
        return()
    endif()

    set(${REASON} "" PARENT_SCOPE)
endfunction()

if(EXISTS ${ZIP_FILE})
    check_zip(${ZIP_FILE} REASON)
    if(REASON)
        message(WARNING "Discarding ${ZIP_FILE}: ${REASON}")
        file(REMOVE ${ZIP_FILE})
    endif()
endif()

if(NOT EXISTS ${ZIP_FILE})
    foreach(URL IN LISTS URLS)
        message(STATUS "Downloading ${URL}")
        file(DOWNLOAD ${URL} ${PART_FILE}
            STATUS STATUS
            INACTIVITY_TIMEOUT 60
            SHOW_PROGRESS)

        list(GET STATUS 0 STATUS_CODE)
        if(STATUS_CODE EQUAL 0)
            check_zip(${PART_FILE} REASON)
        else()
            list(GET STATUS 1 REASON)
        endif()

        if(NOT REASON)
            file(RENAME ${PART_FILE} ${ZIP_FILE})
            break()
        endif()

        message(WARNING "Couldn't download ${URL}: ${REASON}")
        file(REMOVE ${PART_FILE})
    endforeach()
endif()

if(NOT EXISTS ${ZIP_FILE})
    message(FATAL_ERROR "Couldn't download ${ZIP_NAME}. "
        "The steps to fetch it by hand are at the top of ${CMAKE_CURRENT_LIST_FILE}")
endif()

# Extract next to GAME_DIR's paks, so that each one only appears there whole
set(STAGING_DIR ${GAME_DIR}/.openarena)
file(REMOVE_RECURSE ${STAGING_DIR})

list(TRANSFORM MISSING_PAKS PREPEND ${PAK_DIR}/ OUTPUT_VARIABLE PATTERNS)

message(STATUS "Extracting OpenArena's paks into ${GAME_DIR}")
file(ARCHIVE_EXTRACT
    INPUT ${ZIP_FILE}
    DESTINATION ${STAGING_DIR}
    PATTERNS ${PATTERNS})

foreach(PAK IN LISTS MISSING_PAKS)
    file(RENAME ${STAGING_DIR}/${PAK_DIR}/${PAK} ${GAME_DIR}/${PAK})
endforeach()

file(REMOVE_RECURSE ${STAGING_DIR})
