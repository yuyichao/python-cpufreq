cmake_minimum_required(VERSION 2.8)
project(python-cpufreq)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})
include(CythonMacro)

set(CMAKE_C_FLAGS
  "-Wall -Wextra -Wno-sign-compare -Wno-unused-parameter ${CMAKE_C_FLAGS}")
set(CMAKE_CXX_FLAGS
  "-Wall -Wextra -Wno-sign-compare -Wno-unused-parameter ${CMAKE_CXX_FLAGS}")
set(CMAKE_SHARED_LINKER_FLAGS "-Wl,--as-needed ${CMAKE_SHARED_LINKER_FLAGS}")
set(CMAKE_MODULE_LINKER_FLAGS "-Wl,--as-needed ${CMAKE_MODULE_LINKER_FLAGS}")

add_subdirectory(src)
