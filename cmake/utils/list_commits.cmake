# Print a step's commits as the list its chapter ends with, under "How it was
# built": oldest first, each its short hash and subject, linked to the commit
# on GitHub

# Run on the step's branch before its chapter is committed, it lists what
# the branch has added to develop. FROM and TO may be set via -D to list the
# commits in TO's history but not in FROM's instead: once a step is merged,
# FROM=<the merge>^1 and TO=<the merge>^2 list its commits. SOURCE_DIR may be
# set too, and is otherwise the source this script is in

if(NOT SOURCE_DIR)
    get_filename_component(SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/../.. ABSOLUTE)
endif()

if(NOT FROM)
    set(FROM develop)
endif()

if(NOT TO)
    set(TO HEAD)
endif()

find_program(GIT git REQUIRED)

execute_process(
    COMMAND ${GIT} -C ${SOURCE_DIR} log --reverse
        "--format=- [`%h`](https://github.com/takumu-dev/quortal/commit/%H) %s"
        ${FROM}..${TO}
    COMMAND_ERROR_IS_FATAL ANY)
