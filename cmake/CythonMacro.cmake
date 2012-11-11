#   Copyright (C) 2012~2012 by Yichao Yu
#   yyc1992@gmail.com
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, version 2 of the License.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the
#   Free Software Foundation, Inc.,
#   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

include(CMakeParseArguments)
include(PythonMacros)
find_package(PkgConfig REQUIRED)
pkg_check_modules(PYTHON_MODULE REQUIRED python-${PYTHON_SHORT_VERSION})

function(__cython_get_unique_target_name _name _unique_name)
  set(propertyName "_CYTHON_UNIQUE_COUNTER_${_name}")
  get_property(currentCounter GLOBAL PROPERTY "${propertyName}")
  if(NOT currentCounter)
    set(currentCounter 1)
  endif()
  set(${_unique_name} "${_name}_${currentCounter}" PARENT_SCOPE)
  math(EXPR currentCounter "${currentCounter} + 1")
  set_property(GLOBAL PROPERTY ${propertyName} ${currentCounter} )
endfunction()

function(__cython_get_target_names python cmake target)
  __cython_get_unique_target_name(cython_module_target name)
  set(fullname "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${name}")
  set(${python} "${fullname}.py" PARENT_SCOPE)
  set(${cmake} "${fullname}.cmake" PARENT_SCOPE)
  set(${target} "${name}" PARENT_SCOPE)
endfunction()

function(__cython_get_target_type type file)
  cython_get(ftype type "${file}")
  if(NOT ftype)
    get_filename_component(ext "${file}" EXT)
    if("${ext}" STREQUAL ".py")
      set(ftype "python")
    elseif("${ext}" STREQUAL ".pxd")
      set(ftype "pxd")
    else()
      set(ftype "c")
    endif()
  endif()
  set(${type} "${ftype}" PARENT_SCOPE)
endfunction()

get_filename_component(CYTHON_MACROS_MODULE_PATH
  "${CMAKE_CURRENT_LIST_FILE}" PATH)

function(cython_set option value)
  string(TOUPPER "CYTHON_${option}" propname)
  foreach(file ${ARGN})
    set_source_files_properties("${file}"
      PROPERTIES "${propname}" "${value}")
  endforeach()
endfunction()

function(cython_get var option file)
  string(TOUPPER "CYTHON_${option}" propname)
  get_source_file_property(prop "${file}" "${propname}")
  set(${var} "${prop}" PARENT_SCOPE)
endfunction()

function(__cython_set_property_list file basename)
  set(argv ${ARGN})
  list(LENGTH argv __len)
  math(EXPR __max "${__len} - 1")
  string(TOUPPER "CYTHON_${basename}" basename)
  set_source_files_properties("${file}" PROPERTIES
    "${basename}_LENGTH" "${__len}")
  foreach(index RANGE ${__max})
    list(GET argv ${index} ele)
    set_source_files_properties("${file}" PROPERTIES
      "${basename}_PROP_${index}" "${ele}")
  endforeach()
endfunction()

function(__cython_get_property_list file basename output)
  set(values)
  string(TOUPPER "CYTHON_${basename}" basename)
  get_source_file_property(__len "${file}" "${basename}_LENGTH")
  if(NOT __len)
    set(${output} "" PARENT_SCOPE)
    return()
  endif()
  math(EXPR __max "${__len} - 1")
  foreach(index RANGE ${__max})
    get_source_file_property(ele "${file}" "${basename}_PROP_${index}")
    list(APPEND values "${ele}")
  endforeach()
  set(${output} ${values} PARENT_SCOPE)
endfunction()

function(cython_set_c_sources file)
  __cython_set_property_list("${file}" c_sources ${ARGN})
endfunction()

function(cython_set_link_libraries file)
  __cython_set_property_list("${file}" link_libraries ${ARGN})
endfunction()

find_file(_cython_add_file_py CythonAddFiles.py PATHS ${CMAKE_MODULE_PATH})
find_file(_cython_check_cmake_sh CythonCheckWrap.sh PATHS ${CMAKE_MODULE_PATH})

function(_cython_add_args_for_file args file)
  __cython_get_target_type(type "${file}")
  set(_args)
  if("${type}" STREQUAL "python")
    list(APPEND _args --type "python")
    list(APPEND _args --source "${file}")
  else()
    cython_get(api api "${file}")
    cython_get(header header "${file}")
    __cython_get_property_list("${file}" c_sources c_sources)
    __cython_get_property_list("${file}" link_libraries link_libraries)
    if(api)
      list(APPEND _args --api)
    endif()
    if(header)
      list(APPEND _args --header)
    endif()
    if("${type}" STREQUAL "cpp")
      list(APPEND _args --type "cpp")
    else()
      list(APPEND _args --type "c")
    endif()
    list(APPEND _args --source "${file}")
    foreach(c_source ${c_sources})
      list(APPEND _args --c-sources "${c_source}")
    endforeach()
    foreach(link ${link_libraries} ${PYTHON_LIBRARY})
      list(APPEND _args --link "${link}")
    endforeach()
  endif()
  set(${args} ${_args} PARENT_SCOPE)
endfunction()

function(__cython_run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE ret_val)
  if(ret_val)
    message(FATAL_ERROR "")
  endif()
endfunction()

function(__cython_compile source cout rel_path install_path suffix)
  __cython_get_unique_target_name(cython_compile_target target)
  set(options "")
  set(oneValueArgs "")
  set(multiValueArgs "LINKS" "DEPS" "OUTPUTS" "CSOURCES" "INCLUDE_FLAGS")
  cmake_parse_arguments(CYTHON_COMPILE "${options}"
    "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  get_filename_component(_out_path "${cout}" PATH)
  # TODO find cython executable
  add_custom_command(
    OUTPUT ${CYTHON_COMPILE_OUTPUTS}
    COMMAND cmake -E make_directory "${_out_path}"
    COMMAND cython -o "${cout}" ${CYTHON_COMPILE_INCLUDE_FLAGS} "${source}"
    DEPENDS "${source}" ${CYTHON_COMPILE_DEPS}
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    )
  set(lib_file "${rel_path}${suffix}")
  get_filename_component(libpath "${lib_file}" PATH)
  # should be fine, just in case
  file(MAKE_DIRECTORY "${libpath}")
  add_library(${target} MODULE "${cout}" ${CYTHON_COMPILE_CSOURCES})
  target_link_libraries(${target} ${CYTHON_COMPILE_LINKS})
  set_target_properties(${target} PROPERTIES OUTPUT_NAME "${lib_file}"
    PREFIX "" SUFFIX "")
  install(TARGETS ${target} DESTINATION "${install_path}")
endfunction()

function(__cython_check_cmake python cmake)
  __cython_get_unique_target_name(cython_check_target target)
  add_custom_command(
    OUTPUT "${cmake}.stemp"
    COMMAND bash "${_cython_check_cmake_sh}" "${PYTHON_EXECUTABLE}"
    "${_cython_add_file_py}" "${python}" "${cmake}" "${PROJECT_BINARY_DIR}"
    "${PROJECT_SOURCE_DIR}"
    DEPENDS ${ARGN} "${python}" "${_cython_check_cmake_sh}"
    "${_cython_add_file_py}"
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}")
  add_custom_target("${target}" ALL
    DEPENDS "${cmake}.stemp")
endfunction()

function(cython_module)
  set(options "")
  set(oneValueArgs "")
  set(multiValueArgs "INCLUDE_PATH" "SOURCES" "PXD_FILES")
  include_directories(${PYTHON_INCLUDE_PATH})
  cmake_parse_arguments(CYTHON_MODULE "${options}"
    "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  __cython_get_target_names(python_file cmake_file target_name)
  file(REMOVE "${python_file}")
  set(_cython_add_cmd_base "${PYTHON_EXECUTABLE}" "${_cython_add_file_py}"
    --py-result "${python_file}"
    --cmake "${cmake_file}")
  set(GLOBAL_FLAGS --basedir "${CMAKE_CURRENT_SOURCE_DIR}"
    --outputdir "${CMAKE_CURRENT_BINARY_DIR}" --target "${target_name}")
  foreach(include ${CYTHON_MODULE_INCLUDE_PATH})
    list(APPEND GLOBAL_FLAGS --include "${include}")
  endforeach()
  __cython_run(${_cython_add_cmd_base} ${GLOBAL_FLAGS})
  foreach(source ${CYTHON_MODULE_SOURCES})
    message("Adding source file ${source}")
    _cython_add_args_for_file(c_args "${source}")
    __cython_run(${_cython_add_cmd_base} ${c_args})
  endforeach()
  foreach(pxd ${CYTHON_MODULE_PXD_FILES})
    message("Adding pxd file ${pxd}")
    __cython_run(${_cython_add_cmd_base} --type pxd --source "${pxd}")
  endforeach()
  __cython_run(${_cython_add_cmd_base} --check-write)
  include("${cmake_file}")
endfunction()
