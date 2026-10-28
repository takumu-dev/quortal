# Fetch the OpenGL DLLs of mesa-dist-win 26.2.4, Mesa's build for Windows,
# whose llvmpipe renders in software on a machine with no GPU, such as CI's

# MESA_DIR must be set via -D, to the folder the DLLs go in

# The release is downloaded once and kept in the user's cache folder. Its
# x64 opengl32.dll, and libgallium_wgl.dll, which that loads, are then
# extracted into MESA_DIR. Configure quortal with -DTEST_OPENGL_DIR=<MESA_DIR>,
# and the render checks' client loads them in place of the system's
# OpenGL. To do the same by hand:
#
#   1. Download ARCHIVE from URL_BASE below.
#   2. Check that its SHA-256 is SHA256.
#   3. Extract the FILES below from it into one folder.
#   4. Configure quortal with -DTEST_OPENGL_DIR=<that folder>.
#
# Alternatively, put the release in the cache folder by hand
# (%LOCALAPPDATA%\quortal) and run this again, which checks it and extracts
# it without downloading anything.

set(RELEASE 26.2.4)
set(URL_BASE https://github.com/pal1000/mesa-dist-win/releases/download/${RELEASE})

set(ARCHIVE mesa3d-${RELEASE}-release-msvc.7z)
set(SHA256 351fc8c8b695878ffb3eaa044b3ead08672a48b1a045e3c3e3975811df0f6695)

set(FILES
    x64/opengl32.dll
    x64/libgallium_wgl.dll)

if(NOT MESA_DIR)
    message(FATAL_ERROR "MESA_DIR must be set")
endif()

include(${CMAKE_CURRENT_LIST_DIR}/fetch_to_cache.cmake)

# MESA_DIR names the release it was extracted from, so a newly pinned
# release replaces it
set(RELEASE_FILE ${MESA_DIR}/release.txt)
if(EXISTS ${RELEASE_FILE})
    file(READ ${RELEASE_FILE} EXTRACTED_RELEASE)
    if(EXTRACTED_RELEASE STREQUAL RELEASE)
        message(STATUS "Mesa's OpenGL DLLs are already in ${MESA_DIR}")
        return()
    endif()
endif()

fetch_to_cache(${ARCHIVE} ARCHIVE_FILE
    SHA256 ${SHA256}
    URLS ${URL_BASE}/${ARCHIVE})

# Extract beside MESA_DIR, so that it only ever appears whole
set(STAGING_DIR ${MESA_DIR}.staging)
file(REMOVE_RECURSE ${STAGING_DIR})

message(STATUS "Extracting Mesa's OpenGL DLLs into ${MESA_DIR}")
file(ARCHIVE_EXTRACT
    INPUT ${ARCHIVE_FILE}
    DESTINATION ${STAGING_DIR}
    PATTERNS ${FILES})

foreach(FILE IN LISTS FILES)
    if(NOT EXISTS ${STAGING_DIR}/${FILE})
        message(FATAL_ERROR "${ARCHIVE} has no ${FILE}")
    endif()
endforeach()

set(EXTRACTED_DIR ${STAGING_DIR}/x64)
file(WRITE ${EXTRACTED_DIR}/release.txt ${RELEASE})

file(REMOVE_RECURSE ${MESA_DIR})
file(RENAME ${EXTRACTED_DIR} ${MESA_DIR})
file(REMOVE_RECURSE ${STAGING_DIR})
