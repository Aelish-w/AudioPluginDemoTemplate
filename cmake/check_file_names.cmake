# Enforces project directory and C++ filename conventions.
#
# Configure-time use from the root CMakeLists.txt:
#
#   include(cmake/check_file_names.cmake)
#   check_file_names(ROOT "${PROJECT_SOURCE_DIR}")
#
# Standalone/CI use:
#
#   cmake -DPROJECT_ROOT=/path/to/project -P cmake/check_file_names.cmake
#
# Optional additional excluded directory names can be supplied when included:
#
#   check_file_names(
#     ROOT "${PROJECT_SOURCE_DIR}"
#     EXCLUDE_DIRS assets legacy_code
#   )

if(CMAKE_SCRIPT_MODE_FILE)
  cmake_minimum_required(VERSION 3.25)
endif()

include_guard(GLOBAL)

function(check_file_names)
  set(_one_value_arguments ROOT)
  set(_multi_value_arguments EXCLUDE_DIRS)
  cmake_parse_arguments(
    FILE_NAMES
    ""
    "${_one_value_arguments}"
    "${_multi_value_arguments}"
    ${ARGN}
  )

  if(NOT FILE_NAMES_ROOT)
    message(FATAL_ERROR "check_file_names requires ROOT <project-directory>")
  endif()

  if(NOT IS_DIRECTORY "${FILE_NAMES_ROOT}")
    message(FATAL_ERROR
      "check_file_names ROOT is not a directory: ${FILE_NAMES_ROOT}"
    )
  endif()

  file(REAL_PATH "${FILE_NAMES_ROOT}" _file_naming_root)

  # Any path containing one of these directory components is ignored. Hidden
  # directories are ignored separately below.
  set(_file_naming_excluded_directories
    build
    out
    _deps
    third_party
    thirdparty
    external
    vendor
    generated
  )
  list(APPEND
    _file_naming_excluded_directories
    ${FILE_NAMES_EXCLUDE_DIRS}
  )

  set(_file_naming_allowed_extensions
    .hpp
    .cpp
    .tpp
    .cppm
  )

  # Recognized alternatives are diagnosed rather than silently ignored.
  set(_file_naming_disallowed_cpp_extensions
    .h
    .hh
    .hxx
    .h++
    .cc
    .cxx
    .c++
    .ipp
    .inl
    .txx
    .ixx
    .mpp
  )

  set(_file_naming_cpp_extensions
    ${_file_naming_allowed_extensions}
    ${_file_naming_disallowed_cpp_extensions}
  )

  file(GLOB_RECURSE _file_naming_entries
    LIST_DIRECTORIES true
    RELATIVE "${_file_naming_root}"
    "${_file_naming_root}/*"
  )
  list(SORT _file_naming_entries)

  set(_file_naming_violations)

  foreach(_file_naming_relative_path IN LISTS _file_naming_entries)
    # CMake returns forward slashes for these relative paths. Inspecting path
    # components avoids accidentally excluding a file merely because its name
    # contains a word such as "build".
    string(REPLACE "/" ";" _file_naming_path_components
      "${_file_naming_relative_path}"
    )

    set(_file_naming_is_excluded false)
    foreach(_file_naming_component IN LISTS _file_naming_path_components)
      if(
        _file_naming_component MATCHES "^\\."
        OR _file_naming_component IN_LIST _file_naming_excluded_directories
        OR _file_naming_component MATCHES "^cmake-build-"
        OR _file_naming_component MATCHES "^build[-.]"
        OR _file_naming_component MATCHES "^out[-.]"
      )
        set(_file_naming_is_excluded true)
        break()
      endif()
    endforeach()

    if(_file_naming_is_excluded)
      continue()
    endif()

    set(_file_naming_absolute_path
      "${_file_naming_root}/${_file_naming_relative_path}"
    )
    get_filename_component(
      _file_naming_name
      "${_file_naming_relative_path}"
      NAME
    )

    if(IS_DIRECTORY "${_file_naming_absolute_path}")
      if(NOT _file_naming_name MATCHES
        "^[a-z][a-z0-9]*(_[a-z0-9]+)*$"
      )
        list(APPEND _file_naming_violations
          "directory '${_file_naming_relative_path}' must be snake_case"
        )
      endif()
      continue()
    endif()

    string(REGEX MATCH "(\\.[^.]+)$"
      _file_naming_extension_match
      "${_file_naming_name}"
    )
    if(NOT _file_naming_extension_match)
      continue()
    endif()

    set(_file_naming_extension "${CMAKE_MATCH_1}")
    string(TOLOWER
      "${_file_naming_extension}"
      _file_naming_lower_extension
    )

    # Non-C++ project metadata and assets are outside this policy. Conventional
    # files such as CMakeLists.txt, README.md, and LICENSE are therefore exempt.
    if(NOT _file_naming_lower_extension IN_LIST
      _file_naming_cpp_extensions
    )
      continue()
    endif()

    if(NOT "${_file_naming_extension}" STREQUAL
      "${_file_naming_lower_extension}"
    )
      list(APPEND _file_naming_violations
        "file '${_file_naming_relative_path}' must use a lowercase extension"
      )
    endif()

    if(_file_naming_lower_extension IN_LIST
      _file_naming_disallowed_cpp_extensions
    )
      list(APPEND _file_naming_violations
        "file '${_file_naming_relative_path}' must use .hpp, .cpp, .tpp, or .cppm"
      )
    endif()

    string(REGEX REPLACE "\\.[^.]+$" ""
      _file_naming_stem
      "${_file_naming_name}"
    )
    if(NOT _file_naming_stem MATCHES
      "^[a-z][a-z0-9]*(_[a-z0-9]+)*$"
    )
      list(APPEND _file_naming_violations
        "file '${_file_naming_relative_path}' must have a snake_case basename"
      )
    endif()

    if("${_file_naming_lower_extension}" STREQUAL ".cpp")
      string(TOLOWER
        "${_file_naming_relative_path}"
        _file_naming_lower_path
      )

      if(_file_naming_lower_path MATCHES
        "(^|/)(benchmark|benchmarks)(/|$)"
      )
        if(NOT _file_naming_stem MATCHES "_benchmark$")
          list(APPEND _file_naming_violations
            "benchmark '${_file_naming_relative_path}' must end in _benchmark.cpp"
          )
        endif()
      elseif(_file_naming_lower_path MATCHES
        "(^|/)(test|tests|unit_tests|integration_tests)(/|$)"
      )
        if(NOT _file_naming_stem MATCHES "_test$")
          list(APPEND _file_naming_violations
            "test '${_file_naming_relative_path}' must end in _test.cpp"
          )
        endif()
      endif()
    endif()
  endforeach()

  if(_file_naming_violations)
    list(LENGTH _file_naming_violations _file_naming_violation_count)
    list(JOIN _file_naming_violations "\n  - "
      _file_naming_formatted_violations
    )
    message(FATAL_ERROR
      "File naming check failed with ${_file_naming_violation_count} violation(s):\n"
      "  - ${_file_naming_formatted_violations}\n\n"
      "Required conventions:\n"
      "  directories:              snake_case\n"
      "  headers:                  snake_case.hpp\n"
      "  source files:             snake_case.cpp\n"
      "  tests:                    snake_case_test.cpp\n"
      "  benchmarks:               snake_case_benchmark.cpp\n"
      "  template implementations: snake_case.tpp\n"
      "  module interfaces:        snake_case.cppm"
    )
  endif()

  message(STATUS "File naming conventions passed")
endfunction()

if(CMAKE_SCRIPT_MODE_FILE)
  if(DEFINED PROJECT_ROOT AND NOT "${PROJECT_ROOT}" STREQUAL "")
    set(_file_naming_script_root "${PROJECT_ROOT}")
  else()
    get_filename_component(
      _file_naming_script_root
      "${CMAKE_CURRENT_LIST_DIR}/.."
      REALPATH
    )
  endif()

  check_file_names(ROOT "${_file_naming_script_root}")
endif()
