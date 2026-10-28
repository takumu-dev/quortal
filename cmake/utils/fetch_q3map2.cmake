# Fetch q3map2, the map compiler, from NetRadiant-custom 20260114

# Q3MAP2_DIR must be set via -D, to the folder q3map2 goes in

# NetRadiant-custom's release for Linux or Windows is downloaded once and
# kept in the user's cache folder. q3map2 and the libraries it loads are
# then extracted from it into Q3MAP2_DIR, as bin/q3map2 (bin/q3map2.exe on
# Windows). To do the same by hand:
#
#   1. Download LINUX_ARCHIVE or WINDOWS_ARCHIVE from URL_BASE below.
#   2. Check that its SHA-256 is LINUX_SHA256 or WINDOWS_SHA256.
#   3. On Linux, extract LINUX_APPIMAGE from the .7z, and run it with
#      --appimage-extract, which extracts what it holds into squashfs-root.
#      q3map2 is squashfs-root/usr/bin/q3map2. On Windows, extract the zip,
#      which has q3map2.exe at its root.
#   4. Configure quortal with -DQ3MAP2=<the path to q3map2>.
#
# Alternatively, put the release in the cache folder by hand (~/.cache/quortal
# or %LOCALAPPDATA%\quortal) and run this again, which checks it and extracts
# it without downloading anything.
#
# The releases are for x86-64 Linux and Windows only. Anywhere else, such as
# on macOS, build q3map2 from NetRadiant-custom's source, with glib, libxml2,
# libpng, libjpeg, zlib and assimp installed:
#
#   git clone --branch 20260114 https://github.com/Garux/netradiant-custom.git
#   make -C netradiant-custom binaries-q3map2 DEPENDENCIES_CHECK=off
#
# and configure quortal with -DQ3MAP2=<path>/netradiant-custom/install/q3map2.

set(RELEASE 20260114)
set(URL_BASE https://github.com/Garux/netradiant-custom/releases/download/${RELEASE})

set(LINUX_ARCHIVE netradiant-custom-${RELEASE}-linux-x86_64.7z)
set(LINUX_SHA256 f48f6f1d0db2b910ef9cb5dc5d8a722852510f3c5c278dc17615c0466b8a7a3d)
set(LINUX_APPIMAGE NetRadiant-Custom-x86_64.AppImage)

# q3map2 and the libraries it loads from the AppImage, which it finds in
# ../lib through its RUNPATH. libc, libstdc++ and zlib are the system's.
# q3map2 is a symlink to q3map2.x86_64, which comes first, since the
# AppImage makes the folder a file goes in, but not one for a symlink
set(LINUX_FILES
    usr/bin/q3map2.x86_64
    usr/bin/q3map2
    usr/lib/libassimp.so.5
    usr/lib/libdraco.so.8
    usr/lib/libglib-2.0.so.0
    usr/lib/libicudata.so.74
    usr/lib/libicuuc.so.74
    usr/lib/libjpeg.so.8
    usr/lib/liblzma.so.5
    usr/lib/libminizip.so.1
    usr/lib/libpcre2-8.so.0
    usr/lib/libpng16.so.16
    usr/lib/libpugixml.so.1
    usr/lib/libxml2.so.2)

set(WINDOWS_ARCHIVE netradiant-custom-${RELEASE}-windows-x86_64.zip)
set(WINDOWS_SHA256 25c2e14e2b0bd7a9897b2f943c8821458873c8713973f9c3d68d49f26fe79e35)

# q3map2 and the DLLs it loads, from the zip's root
set(WINDOWS_FILES
    q3map2.exe
    libassimp-6.dll
    libbz2-1.dll
    libgcc_s_seh-1.dll
    libglib-2.0-0.dll
    libiconv-2.dll
    libintl-8.dll
    libjpeg-8.dll
    libminizip-1.dll
    libpcre2-8-0.dll
    libpng16-16.dll
    libstdc++-6.dll
    libwinpthread-1.dll
    libxml2-16.dll
    zlib1.dll)

if(NOT Q3MAP2_DIR)
    message(FATAL_ERROR "Q3MAP2_DIR must be set")
endif()

include(${CMAKE_CURRENT_LIST_DIR}/fetch_to_cache.cmake)

cmake_host_system_information(RESULT HOST_PLATFORM QUERY OS_PLATFORM)
if(CMAKE_HOST_WIN32)
    set(ARCHIVE ${WINDOWS_ARCHIVE})
    set(SHA256 ${WINDOWS_SHA256})
elseif(CMAKE_HOST_LINUX AND HOST_PLATFORM STREQUAL "x86_64")
    set(ARCHIVE ${LINUX_ARCHIVE})
    set(SHA256 ${LINUX_SHA256})
else()
    message(FATAL_ERROR "NetRadiant-custom has no release for this platform. "
        "The steps to build q3map2 from source are at the top of ${CMAKE_CURRENT_LIST_FILE}")
endif()

# Q3MAP2_DIR names the release it was extracted from, so a newly pinned
# release replaces it
set(RELEASE_FILE ${Q3MAP2_DIR}/release.txt)
if(EXISTS ${RELEASE_FILE})
    file(READ ${RELEASE_FILE} EXTRACTED_RELEASE)
    if(EXTRACTED_RELEASE STREQUAL RELEASE)
        message(STATUS "q3map2 is already in ${Q3MAP2_DIR}")
        return()
    endif()
endif()

fetch_to_cache(${ARCHIVE} ARCHIVE_FILE
    SHA256 ${SHA256}
    URLS ${URL_BASE}/${ARCHIVE})

# Extract beside Q3MAP2_DIR, so that it only ever appears whole
set(STAGING_DIR ${Q3MAP2_DIR}.staging)
file(REMOVE_RECURSE ${STAGING_DIR})

message(STATUS "Extracting q3map2 into ${Q3MAP2_DIR}")
if(CMAKE_HOST_WIN32)
    set(EXTRACTED_DIR ${STAGING_DIR})
    file(ARCHIVE_EXTRACT
        INPUT ${ARCHIVE_FILE}
        DESTINATION ${EXTRACTED_DIR}/bin
        PATTERNS ${WINDOWS_FILES})
else()
    set(EXTRACTED_DIR ${STAGING_DIR}/squashfs-root/usr)
    file(ARCHIVE_EXTRACT
        INPUT ${ARCHIVE_FILE}
        DESTINATION ${STAGING_DIR}
        PATTERNS ${LINUX_APPIMAGE})

    # The AppImage extracts what matches one pattern at a time, and nothing,
    # without failing, for a pattern that matches nothing
    foreach(FILE IN LISTS LINUX_FILES)
        execute_process(
            COMMAND ${STAGING_DIR}/${LINUX_APPIMAGE} --appimage-extract ${FILE}
            WORKING_DIRECTORY ${STAGING_DIR}
            OUTPUT_QUIET
            COMMAND_ERROR_IS_FATAL ANY)

        if(NOT EXISTS ${STAGING_DIR}/squashfs-root/${FILE})
            message(FATAL_ERROR "${LINUX_APPIMAGE} has no ${FILE}")
        endif()
    endforeach()
endif()

file(WRITE ${EXTRACTED_DIR}/release.txt ${RELEASE})

file(REMOVE_RECURSE ${Q3MAP2_DIR})
file(RENAME ${EXTRACTED_DIR} ${Q3MAP2_DIR})
file(REMOVE_RECURSE ${STAGING_DIR})
