#!/bin/bash

PYTHON_EXECUTABLE="$1"
add_file="$2"
python_file="$3"
cmake_file="$4"
project_bin="$5"
project_src="$6"

run_check() {
    "${PYTHON_EXECUTABLE}" "${add_file}" --check-changed \
        --py-result "${python_file}" \
        --cmake "${cmake_file}" || {
            cd "${project_bin}"
            cmake -H"${project_src}" -B"${project_bin}" \
                --check-build-system CMakeFiles/Makefile.cmake 0
        }
}

run_check
touch "${cmake_file}.stemp"
