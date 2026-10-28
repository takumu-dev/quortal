# Check that quortal's docs hold true: its README.md, and every Markdown file
# in its docs folder

# SOURCE_DIR may be set via -D, and is otherwise the source this script is
# in. COMMIT may be set to the commit whose history the chapters' lists of
# commits must be in, and is otherwise HEAD.
#
# Links to other sites aren't checked. Otherwise:
#
#   - every relative link, and every image, must lead to a file or folder in
#     the source, and a link to a heading in a Markdown file must find it;
#   - a link whose text is all code, such as [`VM_Create`](../code/qcommon/vm.c),
#     names an identifier, which must be in the file it leads to, as a whole
#     word;
#   - a fenced code block is an excerpt when the last line before it that
#     isn't blank ends with a link and a colon, such as "... in
#     [vm.c](../code/qcommon/vm.c):". It must be whole lines of that file, as
#     they are there, with none left out;
#   - the list under a heading "How it was built" is a step's commits, one to
#     an item, as list_commits.cmake prints them. Each must link to its
#     commit, which must be in the history of COMMIT.
#
# Code is read for none of these, except where it's all of a link's text

if(NOT SOURCE_DIR)
    get_filename_component(SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/../.. ABSOLUTE)
endif()

if(NOT COMMIT)
    set(COMMIT HEAD)
endif()

find_program(GIT git)

set(SHALLOW "")
if(GIT)
    execute_process(
        COMMAND ${GIT} -C ${SOURCE_DIR} rev-parse --is-shallow-repository
        OUTPUT_VARIABLE SHALLOW
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
endif()

# A list splits at semicolons, except in brackets or after a backslash, so
# a line read into a list holds these control characters in their places
string(ASCII 1 SEMICOLON)
string(ASCII 2 OPEN_BRACKET)
string(ASCII 3 CLOSE_BRACKET)
string(ASCII 4 BACKSLASH)

set(FAILURES 0)

# Reports a problem at LINE_NUMBER in DOC
function(fail TEXT)
    message("${DOC}:${LINE_NUMBER}: ${TEXT}")
    math(EXPR FAILURES "${FAILURES} + 1")
    set(FAILURES ${FAILURES} PARENT_SCOPE)
endfunction()

# Sets VAR to the list of FILE's lines, each to be decoded by decode_line
function(read_lines FILE VAR)
    file(READ ${FILE} CONTENT)
    string(REPLACE "\r" "" CONTENT "${CONTENT}")
    string(REPLACE ";" "${SEMICOLON}" CONTENT "${CONTENT}")
    string(REPLACE "[" "${OPEN_BRACKET}" CONTENT "${CONTENT}")
    string(REPLACE "]" "${CLOSE_BRACKET}" CONTENT "${CONTENT}")
    string(REPLACE "\\" "${BACKSLASH}" CONTENT "${CONTENT}")
    string(REPLACE "\n" ";" LINES "${CONTENT}")
    set(${VAR} "${LINES}" PARENT_SCOPE)
endfunction()

# Puts back the characters read_lines left out of the line in VAR
macro(decode_line VAR)
    string(REPLACE "${SEMICOLON}" ";" ${VAR} "${${VAR}}")
    string(REPLACE "${OPEN_BRACKET}" "[" ${VAR} "${${VAR}}")
    string(REPLACE "${CLOSE_BRACKET}" "]" ${VAR} "${${VAR}}")
    string(REPLACE "${BACKSLASH}" "\\" ${VAR} "${${VAR}}")
endmacro()

# Sets VAR to the fence of the code block that the line after LINE is in, or
# to nothing, given FENCE, the fence of the one LINE is in. A block ends at
# a fence of the same character, at least as long as the one it started with
function(get_next_fence LINE FENCE VAR)
    if(FENCE)
        if(LINE MATCHES "^ *(```+|~~~+) *$")
            string(FIND "${CMAKE_MATCH_1}" "${FENCE}" POSITION)
            if(POSITION EQUAL 0)
                set(FENCE "")
            endif()
        endif()
    elseif(LINE MATCHES "^ *(```+)[^`]*$")
        set(FENCE "${CMAKE_MATCH_1}")
    elseif(LINE MATCHES "^ *(~~~+)")
        set(FENCE "${CMAKE_MATCH_1}")
    endif()

    set(${VAR} "${FENCE}" PARENT_SCOPE)
endfunction()

# Sets LEVEL_VAR to the level of the heading LINE is, or to nothing when it
# isn't one, and TEXT_VAR to the heading's text
function(get_heading LINE LEVEL_VAR TEXT_VAR)
    set(${LEVEL_VAR} "" PARENT_SCOPE)
    if(LINE MATCHES "^ ? ? ?(#+)[ \t]+(.*)")
        set(TEXT "${CMAKE_MATCH_2}")
    elseif(LINE MATCHES "^ ? ? ?(#+)$")
        set(TEXT "")
    else()
        return()
    endif()

    string(LENGTH "${CMAKE_MATCH_1}" LEVEL)
    string(REGEX REPLACE "[ \t]+#+[ \t]*$" "" TEXT " ${TEXT}")
    string(STRIP "${TEXT}" TEXT)
    if(LEVEL LESS_EQUAL 6)
        set(${LEVEL_VAR} ${LEVEL} PARENT_SCOPE)
        set(${TEXT_VAR} "${TEXT}" PARENT_SCOPE)
    endif()
endfunction()

# Sets VAR to the anchors GitHub gives the headings in the Markdown file
# FILE: each heading's words, in lower case and joined by hyphens, without
# the punctuation, code marks and links' destinations among them. Headings
# whose anchor is already taken are numbered, from -1
function(get_anchors FILE VAR)
    read_lines(${FILE} LINES)

    set(ANCHORS "")
    set(FENCE "")
    foreach(LINE IN LISTS LINES)
        decode_line(LINE)
        get_next_fence("${LINE}" "${FENCE}" NEXT_FENCE)
        if(NOT FENCE AND NOT NEXT_FENCE)
            get_heading("${LINE}" LEVEL TEXT)
        else()
            set(LEVEL "")
        endif()
        set(FENCE "${NEXT_FENCE}")

        if(LEVEL)
            string(REGEX REPLACE "!?\\[([^]]*)\\]\\([^)]*\\)" "\\1" ANCHOR "${TEXT}")
            string(TOLOWER "${ANCHOR}" ANCHOR)
            string(REGEX REPLACE "[]!\"#$%&'()*+,./:;<=>?@[\\^`{|}~]" "" ANCHOR "${ANCHOR}")
            string(REPLACE " " "-" ANCHOR "${ANCHOR}")

            set(NUMBERED_ANCHOR "${ANCHOR}")
            set(NUMBER 0)
            list(FIND ANCHORS "${NUMBERED_ANCHOR}" INDEX)
            while(NOT INDEX EQUAL -1)
                math(EXPR NUMBER "${NUMBER} + 1")
                set(NUMBERED_ANCHOR "${ANCHOR}-${NUMBER}")
                list(FIND ANCHORS "${NUMBERED_ANCHOR}" INDEX)
            endwhile()
            list(APPEND ANCHORS "${NUMBERED_ANCHOR}")
        endif()
    endforeach()

    set(${VAR} "${ANCHORS}" PARENT_SCOPE)
endfunction()

# Sets PATH_VAR to the path that LINK, in DOC, leads to, and ANCHOR_VAR to the
# anchor it leads to there, if any. A link to an anchor alone leads to DOC.
# PATH_VAR is set to nothing for a link to another site, which isn't checked
function(get_link_path LINK PATH_VAR ANCHOR_VAR)
    set(${PATH_VAR} "" PARENT_SCOPE)
    set(${ANCHOR_VAR} "" PARENT_SCOPE)
    if(LINK MATCHES "^[A-Za-z][A-Za-z0-9+.-]*:" OR LINK MATCHES "^//")
        return()
    endif()

    string(REGEX REPLACE "\\?[^#]*" "" LINK "${LINK}")
    if(LINK MATCHES "#(.*)$")
        set(${ANCHOR_VAR} "${CMAKE_MATCH_1}" PARENT_SCOPE)
        string(REGEX REPLACE "#.*$" "" LINK "${LINK}")
    endif()

    # As on GitHub, a path from / starts at the top of the source
    if(LINK STREQUAL "")
        set(PATH ${SOURCE_DIR}/${DOC})
    elseif(LINK MATCHES "^/+(.*)")
        get_filename_component(PATH "${CMAKE_MATCH_1}" ABSOLUTE BASE_DIR ${SOURCE_DIR})
    else()
        get_filename_component(BASE_DIR ${SOURCE_DIR}/${DOC} DIRECTORY)
        get_filename_component(PATH "${LINK}" ABSOLUTE BASE_DIR ${BASE_DIR})
    endif()

    set(${PATH_VAR} ${PATH} PARENT_SCOPE)
endfunction()

# Sets VAR to whether FILE holds IDENTIFIER whole, rather than as part of a
# longer word
function(find_identifier FILE IDENTIFIER VAR)
    set(WORD_CHARACTER "[A-Za-z0-9_]")
    set(NOT_WORD_CHARACTER "[^A-Za-z0-9_]")

    string(REGEX REPLACE "([][+.*()^$?|\\\\])" "\\\\\\1" PATTERN "${IDENTIFIER}")
    if(IDENTIFIER MATCHES "^${WORD_CHARACTER}")
        string(PREPEND PATTERN "(^|${NOT_WORD_CHARACTER})")
    endif()
    if(IDENTIFIER MATCHES "${WORD_CHARACTER}$")
        string(APPEND PATTERN "(${NOT_WORD_CHARACTER}|$)")
    endif()

    file(READ ${FILE} CONTENT)
    if(CONTENT MATCHES "${PATTERN}")
        set(${VAR} TRUE PARENT_SCOPE)
    else()
        set(${VAR} FALSE PARENT_SCOPE)
    endif()
endfunction()

# Checks the link to LINK, with TEXT, on the current line
function(check_link TEXT LINK)
    get_link_path("${LINK}" PATH ANCHOR)
    if(NOT PATH)
        return()
    endif()

    cmake_path(IS_PREFIX SOURCE_DIR ${PATH} NORMALIZE INSIDE)
    if(NOT INSIDE)
        fail("${LINK} is outside the source")
    elseif(NOT EXISTS ${PATH})
        fail("${LINK} doesn't exist")
    else()
        # Anchors are only known in Markdown, where GitHub gives each heading one
        if(NOT ANCHOR STREQUAL "" AND PATH MATCHES "\\.md$" AND NOT IS_DIRECTORY ${PATH})
            get_anchors(${PATH} ANCHORS)
            list(FIND ANCHORS "${ANCHOR}" INDEX)
            if(INDEX EQUAL -1)
                fail("${LINK} leads to no heading")
            endif()
        endif()

        # A link whose text is all code names an identifier in what it leads to
        if(TEXT MATCHES "^`([^`]+)`$")
            set(IDENTIFIER "${CMAKE_MATCH_1}")
            if(IS_DIRECTORY ${PATH})
                fail("${LINK} is a folder, so it can't hold ${IDENTIFIER}")
            else()
                find_identifier(${PATH} "${IDENTIFIER}" FOUND)
                if(NOT FOUND)
                    fail("${LINK} has no ${IDENTIFIER}")
                endif()
            endif()
        endif()
    endif()

    set(FAILURES ${FAILURES} PARENT_SCOPE)
endfunction()

# Checks EXCERPT, the code block starting at line START, which follows a line
# ending in a link to LINK. It must be whole lines of the file LINK leads to,
# as they are there
function(check_excerpt START LINK EXCERPT)
    set(LINE_NUMBER ${START})

    # A link that leads nowhere has been reported already
    get_link_path("${LINK}" PATH ANCHOR)
    if(NOT PATH)
        return()
    endif()
    cmake_path(IS_PREFIX SOURCE_DIR ${PATH} NORMALIZE INSIDE)
    if(NOT INSIDE OR NOT EXISTS ${PATH})
        return()
    endif()

    if(IS_DIRECTORY ${PATH})
        fail("${LINK} is a folder, so this excerpt can't be from it")
    elseif(EXCERPT STREQUAL "")
        fail("this excerpt from ${LINK} is empty")
    else()
        file(READ ${PATH} CONTENT)
        string(REPLACE "\r" "" CONTENT "${CONTENT}")
        string(FIND "\n${CONTENT}\n" "\n${EXCERPT}\n" POSITION)
        if(POSITION EQUAL -1)
            fail("${LINK} doesn't have this excerpt's lines")
        endif()
    endif()

    set(FAILURES ${FAILURES} PARENT_SCOPE)
endfunction()

# Checks ITEM, an item on the current line in a list of a step's commits. It
# must link to a commit in the history of COMMIT, and the short hash it
# shows must be that commit's
function(check_commit ITEM)
    if(NOT ITEM MATCHES "\\]\\([^)]*/commit/([0-9a-f]+)\\)")
        fail("this item in a list of commits has no commit")
        set(FAILURES ${FAILURES} PARENT_SCOPE)
        return()
    endif()
    set(HASH ${CMAKE_MATCH_1})

    if(ITEM MATCHES "\\[`([0-9a-f]+)`\\]")
        string(FIND ${HASH} ${CMAKE_MATCH_1} POSITION)
        if(NOT POSITION EQUAL 0)
            fail("${CMAKE_MATCH_1} isn't the commit it links to, ${HASH}")
        endif()
    endif()

    if(NOT GIT)
        fail("git wasn't found, so ${HASH} can't be looked for in the history of ${COMMIT}")
    else()
        execute_process(
            COMMAND ${GIT} -C ${SOURCE_DIR} merge-base --is-ancestor ${HASH} ${COMMIT}
            RESULT_VARIABLE RESULT
            OUTPUT_QUIET
            ERROR_VARIABLE ERROR
            ERROR_STRIP_TRAILING_WHITESPACE)

        if(RESULT EQUAL 1)
            fail("${HASH} isn't in the history of ${COMMIT}")
        elseif(NOT RESULT EQUAL 0 AND SHALLOW STREQUAL "true")
            fail("${HASH} isn't in this clone, which is shallow: git fetch --unshallow fetches the rest of its history")
        elseif(NOT RESULT EQUAL 0)
            fail("git can't find ${HASH} in the history of ${COMMIT}: ${ERROR}")
        endif()
    endif()

    set(FAILURES ${FAILURES} PARENT_SCOPE)
endfunction()

# Checks one Markdown file, DOC, relative to SOURCE_DIR
function(check_doc DOC)
    read_lines(${SOURCE_DIR}/${DOC} LINES)

    # A link's text that is all code is marked by these while the rest of the
    # line's code is taken out
    string(ASCII 5 CODE_START)
    string(ASCII 6 CODE_END)

    set(DESTINATION_PATTERN "[ \t]*(<[^>]*>|[^ \t)]*)[^)]*")

    set(FENCE "")
    set(CAPTION_LINK "")
    set(COMMITS_LEVEL "")
    set(LINE_NUMBER 0)
    foreach(LINE IN LISTS LINES)
        math(EXPR LINE_NUMBER "${LINE_NUMBER} + 1")
        decode_line(LINE)
        get_next_fence("${LINE}" "${FENCE}" NEXT_FENCE)

        # The lines of a code block lose as much of their indent as its
        # opening fence has. A block that's an excerpt is checked once it
        # has ended
        if(FENCE)
            set(FENCE "${NEXT_FENCE}")
            if(EXCERPT_LINK STREQUAL "")
                continue()
            elseif(NOT FENCE)
                check_excerpt(${EXCERPT_START} "${EXCERPT_LINK}" "${EXCERPT}")
                continue()
            endif()

            if(LINE MATCHES "^( +)")
                string(LENGTH "${CMAKE_MATCH_1}" SPACES)
                if(SPACES GREATER INDENT)
                    set(SPACES ${INDENT})
                endif()
                string(SUBSTRING "${LINE}" ${SPACES} -1 LINE)
            endif()
            if(EXCERPT_STARTED)
                string(APPEND EXCERPT "\n${LINE}")
            else()
                set(EXCERPT "${LINE}")
                set(EXCERPT_STARTED TRUE)
            endif()
            continue()
        endif()

        # A code block is an excerpt of the file linked at the end of the
        # caption before it
        if(NEXT_FENCE)
            set(FENCE "${NEXT_FENCE}")
            set(INDENT 0)
            if(LINE MATCHES "^( +)")
                string(LENGTH "${CMAKE_MATCH_1}" INDENT)
            endif()
            set(EXCERPT_LINK "${CAPTION_LINK}")
            set(EXCERPT_START ${LINE_NUMBER})
            set(EXCERPT "")
            set(EXCERPT_STARTED FALSE)
            set(CAPTION_LINK "")
            continue()
        endif()

        # A chapter lists its step's commits under the heading "How it was
        # built", until a heading as high or higher
        get_heading("${LINE}" LEVEL HEADING)
        if(LEVEL)
            if(COMMITS_LEVEL AND LEVEL LESS_EQUAL COMMITS_LEVEL)
                set(COMMITS_LEVEL "")
            endif()
            if(HEADING STREQUAL "How it was built")
                set(COMMITS_LEVEL ${LEVEL})
            endif()
        elseif(COMMITS_LEVEL AND LINE MATCHES "^[ \t]*([-*+]|[0-9]+[.)])[ \t]")
            check_commit("${LINE}")
        endif()

        # A caption is the last line before a code block that isn't blank,
        # when it ends with a link and a colon
        if(LINE MATCHES "\\]\\(${DESTINATION_PATTERN}\\):[ \t]*$")
            string(REGEX REPLACE "^<(.*)>$" "\\1" CAPTION_LINK "${CMAKE_MATCH_1}")
        elseif(NOT LINE MATCHES "^[ \t]*$")
            set(CAPTION_LINK "")
        endif()

        string(REGEX REPLACE "\\[`([^`]+)`\\]\\(" "[${CODE_START}\\1${CODE_END}](" LINE "${LINE}")
        string(REGEX REPLACE "``([^`]|`[^`])*``" "" LINE "${LINE}")
        string(REGEX REPLACE "`[^`]*`" "" LINE "${LINE}")
        string(REPLACE "${CODE_START}" "`" LINE "${LINE}")
        string(REPLACE "${CODE_END}" "`" LINE "${LINE}")

        # A link's destination may be in <>, and may be followed by a title,
        # in the link or in the definition a reference link names
        if(LINE MATCHES "^ ? ? ?\\[[^]]+\\]:(${DESTINATION_PATTERN})$")
            set(LINE "[](${CMAKE_MATCH_1})")
        endif()

        while(LINE MATCHES "\\[([^]]*)\\]\\(${DESTINATION_PATTERN}\\)(.*)")
            set(TEXT "${CMAKE_MATCH_1}")
            set(LINE "${CMAKE_MATCH_3}")
            string(REGEX REPLACE "^<(.*)>$" "\\1" LINK "${CMAKE_MATCH_2}")
            check_link("${TEXT}" "${LINK}")
        endwhile()
    endforeach()

    set(FAILURES ${FAILURES} PARENT_SCOPE)
endfunction()

file(GLOB_RECURSE DOCS RELATIVE ${SOURCE_DIR} ${SOURCE_DIR}/docs/*.md)
if(EXISTS ${SOURCE_DIR}/README.md)
    list(PREPEND DOCS README.md)
endif()

foreach(DOC IN LISTS DOCS)
    message(STATUS "Checking ${DOC}")
    check_doc(${DOC})
endforeach()

if(FAILURES EQUAL 1)
    message(FATAL_ERROR "The docs have 1 problem")
elseif(FAILURES)
    message(FATAL_ERROR "The docs have ${FAILURES} problems")
endif()
