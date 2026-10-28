# Linux-like specific settings, i.e. including FreeBSD etc.

if(NOT UNIX OR APPLE)
    return()
endif()

include(utils/arch)

list(APPEND CLIENT_DEFINITIONS USE_ICON)
list(APPEND RENDERER_DEFINITIONS USE_ICON)

# Without an extension, the client would have the same path as the base
# game's folder beside it, so both binaries are named for their architecture
if(NOT EMSCRIPTEN)
    list(APPEND POST_CONFIGURE_FUNCTIONS add_arch_suffix)
endif()

function(add_arch_suffix)
    foreach(BINARY IN ITEMS ${CLIENT_BINARY} ${SERVER_BINARY})
        set_target_properties(${BINARY} PROPERTIES SUFFIX .${ARCH})
    endforeach()
endfunction()

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set_property(CACHE CMAKE_INSTALL_PREFIX PROPERTY VALUE /opt/quortal)
endif()

set(CPACK_GENERATOR "DEB")
set(CPACK_PACKAGING_INSTALL_PREFIX ${CMAKE_INSTALL_PREFIX})
