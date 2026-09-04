if(NOT DEFINED PROJECT_ROOT OR "${PROJECT_ROOT}" STREQUAL "")
    message(FATAL_ERROR "PROJECT_ROOT is required")
endif()

if(NOT DEFINED HEADERS OR "${HEADERS}" STREQUAL "")
    message(FATAL_ERROR "HEADERS is required")
endif()

set(_header_guard_violations)

foreach(_header IN LISTS HEADERS)
    if(IS_ABSOLUTE "${_header}")
        set(_path "${_header}")
    else()
        set(_path "${PROJECT_ROOT}/${_header}")
    endif()

    if(NOT EXISTS "${_path}")
        list(APPEND _header_guard_violations "${_header}: file does not exist")
        continue()
    endif()

    file(STRINGS "${_path}" _lines)
    list(LENGTH _lines _line_count)
    if(_line_count LESS 3)
        list(APPEND _header_guard_violations "${_header}: file is too short to contain a header guard")
        continue()
    endif()

    list(GET _lines 0 _ifndef_line)
    list(GET _lines 1 _define_line)
    list(GET _lines -1 _endif_line)

    if(NOT _ifndef_line MATCHES "^#[ \t]*ifndef[ \t]+([A-Z][A-Z0-9_]*)[ \t]*$")
        list(APPEND _header_guard_violations "${_header}: first line must be #ifndef HEADER_GUARD")
        continue()
    endif()

    set(_guard "${CMAKE_MATCH_1}")
    if(NOT _define_line MATCHES "^#[ \t]*define[ \t]+${_guard}[ \t]*$")
        list(APPEND _header_guard_violations "${_header}: second line must define ${_guard}")
    endif()

    if(NOT _endif_line MATCHES "^#[ \t]*endif([ \t]*//[ \t]*${_guard})?[ \t]*$")
        list(APPEND _header_guard_violations "${_header}: final line must close ${_guard}")
    endif()

    file(READ "${_path}" _contents)
    if(_contents MATCHES "#[ \t]*pragma[ \t]+once")
        list(APPEND _header_guard_violations "${_header}: #pragma once is not allowed")
    endif()
endforeach()

if(_header_guard_violations)
    list(JOIN _header_guard_violations "\n  - " _formatted_violations)
    message(FATAL_ERROR "Header guard check failed:\n  - ${_formatted_violations}")
endif()

message(STATUS "Traditional header guards passed")
