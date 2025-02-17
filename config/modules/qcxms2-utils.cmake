# This file is part of QCxMS2.
#########################################################################################
#########################################################################################

# Handling of subproject dependencies
macro(
  "qcxms2_find_package"
  package
  methods
  url
)

  if(NOT DEFINED ARGV3)
    set(branch "HEAD")  # Default to HEAD if branch is not provided
  else()
    set(branch "${ARGV3}")  # Use the provided branch
  endif()

  string(TOLOWER "${package}" _pkg_lc)
  string(TOUPPER "${package}" _pkg_uc)

  # iterate through lookup types in order
  foreach(method ${methods})

    if(TARGET "${package}::${package}")
      break()
    endif()

#########################################################################################

    # look for a <package>-config.cmake on the system 
    if("${method}" STREQUAL "cmake")
      if(DEFINED "${_pkg_uc}_DIR")
        set("_${_pkg_uc}_DIR")
        set("${package}_DIR" "${_pkg_uc}_DIR")
      endif()
      find_package("${package}" CONFIG)
      if("${package}_FOUND")
        message(STATUS "Found ${package} via CMake config")
        break()
      endif()
    endif()

#########################################################################################

    # look for dependency via pkgconf
    if("${method}" STREQUAL "pkgconf")
      find_package(PkgConfig QUIET)
      pkg_check_modules("${_pkg_uc}" QUIET "${package}")
      if("${_pkg_uc}_FOUND")
        message(STATUS "Found ${package} via pkg-config")

        add_library("${package}::${package}" INTERFACE IMPORTED)
        target_link_libraries(
          "${package}::${package}"
          INTERFACE
          "${${_pkg_uc}_LINK_LIBRARIES}"
        )
        target_include_directories(
          "${package}::${package}"
          INTERFACE
          "${${_pkg_uc}_INCLUDE_DIRS}"
        )
        break()
      endif()
    endif()

#########################################################################################

    # look for SOURCE in the subprojects directory (we usually prefer this one)
    if("${method}" STREQUAL "subproject")
      if(NOT DEFINED "${_pkg_uc}_SUBPROJECT")
        set("_${_pkg_uc}_SUBPROJECT")
        set("${_pkg_uc}_SUBPROJECT" "subprojects/${package}")
      endif()
      set("${_pkg_uc}_SOURCE_DIR" "${PROJECT_SOURCE_DIR}/${${_pkg_uc}_SUBPROJECT}")
      set("${_pkg_uc}_BINARY_DIR" "${PROJECT_BINARY_DIR}/${${_pkg_uc}_SUBPROJECT}")
      if(EXISTS "${${_pkg_uc}_SOURCE_DIR}/CMakeLists.txt")
        message(STATUS "Include ${package} from ${${_pkg_uc}_SUBPROJECT}")
        add_subdirectory(
          "${${_pkg_uc}_SOURCE_DIR}"
          "${${_pkg_uc}_BINARY_DIR}"
        )

        add_library("${package}::${package}" INTERFACE IMPORTED)
        target_link_libraries("${package}::${package}" INTERFACE "${package}")

        # We need the module directory in the subproject before we finish the configure stage
        if(NOT EXISTS "${${_pkg_uc}_BINARY_DIR}/include")
          make_directory("${${_pkg_uc}_BINARY_DIR}/include")
        endif()

        break()
      endif()
    endif()

#########################################################################################

    # finally, we can try to download sources
    if("${method}" STREQUAL "fetch")
      message(STATUS "Retrieving ${package} from ${url}")
      include(FetchContent)
      FetchContent_Declare(
        "${_pkg_lc}"
        GIT_REPOSITORY "${url}"
        GIT_TAG "${branch}"
      )
      FetchContent_MakeAvailable("${_pkg_lc}")

      add_library("${package}::${package}" INTERFACE IMPORTED)
      target_link_libraries("${package}::${package}" INTERFACE "${package}")

      # We need the module directory in the subproject before we finish the configure stage
      FetchContent_GetProperties("${_pkg_lc}" SOURCE_DIR "${_pkg_uc}_SOURCE_DIR")
      FetchContent_GetProperties("${_pkg_lc}" BINARY_DIR "${_pkg_uc}_BINARY_DIR")
      if(NOT EXISTS "${${_pkg_uc}_BINARY_DIR}/include")
        make_directory("${${_pkg_uc}_BINARY_DIR}/include")
      endif()

      break()
    endif()

#########################################################################################

  endforeach()

  if(TARGET "${package}::${package}")
    set("${_pkg_uc}_FOUND" TRUE)
  else()
    set("${_pkg_uc}_FOUND" FALSE)
  endif()

  unset(_pkg_lc)
  unset(_pkg_uc)

  if(DEFINED "_${_pkg_uc}_SUBPROJECT")
    unset("${_pkg_uc}_SUBPROJECT")
    unset("_${_pkg_uc}_SUBPROJECT")
  endif()
  
  if(DEFINED "_${_pkg_pc}_DIR")
    unset("${package}_DIR")
    unset("_${_pkg_pc}_DIR")
  endif()

  if(NOT TARGET "${package}::${package}")
    message(FATAL_ERROR "Could not find dependency ${package}")
  endif()
endmacro()

#########################################################################################
#########################################################################################

# Check current compiler version requirements.
function (check_minimal_compiler_version lang compiler_versions)
  while(compiler_versions)
    list(POP_FRONT compiler_versions compiler version)
    if("${CMAKE_${lang}_COMPILER_ID}" STREQUAL "${compiler}"
        AND CMAKE_${lang}_COMPILER_VERSION VERSION_LESS "${version}")
      message(FATAL_ERROR "${compiler} ${lang} compiler is too old "
          "(found \"${CMAKE_${lang}_COMPILER_VERSION}\", required >= \"${version}\")")
    endif()
  endwhile()
endfunction()

