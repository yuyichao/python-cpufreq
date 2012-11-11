#!/usr/bin/env python

#   Copyright (C) 2012~2012 by Yichao Yu
#   yyc1992@gmail.com
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

import argparse, json, traceback, os
from os import path
from distutils import sysconfig
from Cython.Build.Dependencies import *

# utility functions

def print_except():
    try:
        print(traceback.format_exc())
    except:
        pass
def new_wrapper(getter, setter, direr=None):
    class _wrapper:
        def __getattr__(self, key):
            if key.startswith('_') or not hasattr(getter, '__call__'):
                raise AttributeError("Attribute %s not found" % key)
            return getter(key)
        def __setattr__(self, key, value):
            if key.startswith('_') or not hasattr(setter, '__call__'):
                raise AttributeError("Attribute %s is read-only" % key)
            setter(key, value)
        def __getitem__(self, key):
            return self.__getattr__(key)
        def __setitem__(self, key, value):
            self.__setattr__(key, value)
        def __dir__(self):
            if direr is None:
                return []
            return direr()
        def __iter__(self):
            return self.__dir__().__iter__()
    return _wrapper()
def wrap_dict(d):
    def getter(key):
        return d[key]
    def setter(key, value):
        d[key] = value
    def direr():
        return list(d.keys())
    return new_wrapper(getter, setter, direr)


# cmake functions

def cmake_quote_string(s):
    return ('"' + s.replace('\\', '\\\\')
            .replace('$', '\\$')
            .replace('"', '\\"')
            .replace('\n', '\\n') + '"')

def write_call(fh, name, argv):
    fh.write("%s(%s)\n" % (name, ' '.join([cmake_quote_string(s)
                                           for s in argv])))
cmake_comment = (("############################################\n"
                  "#\n"
                  "# This file is generated automatically by %s\n"
                  "#\n"
                  "############################################\n")
                  % path.basename(__file__))

def write_comment(fh):
    fh.write(cmake_comment)

def write_cmake(result):
    if not 'sources' in result:
        return
    with open(result.cmake, "w") as fh:
        write_comment(fh)
        write_call(fh, "__cython_check_cmake",
                   [result.py_result, result.cmake] + list(result.sources))
        for source, option in result.sources.items():
            option = wrap_dict(option)
            if option.type == 'python':
                write_call(fh, "python_install_all",
                           [option.install_path, source])
            elif option.type in ['c', 'cpp']:
                args = [source, option.c_file, option.rel_path,
                        option.install_path, sysconfig.get_config_var('SO')]
                if option.link:
                    args.append("LINKS")
                    args += option.link
                if option.deps:
                    args.append("DEPS")
                    args += option.deps
                args.append("OUTPUTS")
                args += option.output
                if option.c_sources:
                    args.append("CSOURCES")
                    args += option.c_sources
                includes = include_for_result(result)
                if includes:
                    args.append("INCLUDE_FLAGS")
                    for include in includes:
                        args += ["-I", include]
                write_call(fh, "__cython_compile", args)
            elif option.type in ['pxd']:
                # TODO get install path from cython module
                write_call(fh, "install",
                           ["FILES", source, "DESTINATION",
                            sysconfig.get_python_lib() + "/Cython/Includes/" +
                            path.dirname(option.rel_path)])
            else:
                raise TypeError("Unkown target type " + option.type)


# json file function

def load_py(fname):
    try:
        with open(fname, "r") as fh:
            d = json.loads(fh.read())
        if not isinstance(d, dict):
            d = {}
    except:
        d = {}
    return wrap_dict(d)

def save_py(fname, result):
    d = {key: result[key] for key in result}
    string = json.dumps(d)
    with open(fname, "w") as fh:
        fh.write(string)


# handle command line input

def check_global(result, arg_res):
    result.py_result = arg_res.py_result
    result.cmake = arg_res.cmake
    if 'include' in arg_res:
        result.include = arg_res.include
    if 'base' in arg_res:
        result.base = arg_res.base
    if 'output' in arg_res:
        result.output = arg_res.output
    if 'target' in arg_res:
        result.target = arg_res.target

def check_file(result, arg_res):
    if not 'source_file' in arg_res:
        return
    if not 'sources' in result:
        result.sources = {}
    result.sources[arg_res.source_file] = {}
    for key in ["type", "api", "header", "c_sources", "link"]:
        result.sources[arg_res.source_file][key] = getattr(arg_res, key)


# Cython functions
def include_for_result(result):
    include = []
    if 'include' in result:
        include += result.include
    if 'base' in result:
        include.append(result.base)
    if 'output' in result:
        include.append(result.output)
    return include

def dep_tree_for_result(result):
    include = include_for_result(result)
    ctx = Context(include, CompilationOptions(default_options))
    return create_dependency_tree(ctx)

def _get_dep(dep_tree, src_file, deps):
    ndeps = set(dep_tree.cimported_files(src_file)) - deps
    deps.update(ndeps)
    for dep in ndeps:
        _get_dep(dep_tree, dep, deps)

def dep_for_single(dep_tree, src_file, src_opt):
    if src_opt.type == 'python':
        src_opt.deps = []
        return False
    try:
        old_deps = set(src_opt.deps)
    except:
        old_deps = set()
    deps = set()
    _get_dep(dep_tree, src_file, deps)
    src_opt.deps = list(deps)
    return not old_deps == deps

def check_dependency(result):
    if not ('sources' in result and 'base' in result and 'output' in result):
        return True
    os.chdir(result.base)
    dep_tree = dep_tree_for_result(result)
    res = False
    for src_file, src_opt in result.sources.items():
        if dep_for_single(dep_tree, src_file, wrap_dict(src_opt)):
            res = True
    return res

def output_for_single(result, src_file, src_opt):
    res = False
    base = path.realpath(result.base)
    output = path.realpath(result.output)
    src_file = path.realpath(src_file)
    if src_file.startswith(base):
        rel_path = src_file[len(base):]
    elif src_file.startswith(output):
        rel_path = src_file[len(output):]
    else:
        raise ValueError("source file have to be under either "
                         "CMAKE_CURRENT_SOURCE_DIRECTORY or "
                         "CMAKE_CURRENT_BINARY_DIRECTORY")
    install_path = path.dirname(sysconfig.get_python_lib() + rel_path)
    try:
        if not src_opt.install_path == install_path:
            res = True
    except:
        res = True
    src_opt.install_path = install_path
    if rel_path.endswith('.py') or rel_path.endswith('.pyx'):
        rel_path = path.splitext(rel_path)[0]
    src_file = output + rel_path
    if rel_path.startswith('/'):
        rel_path = rel_path[1:]
    try:
        if not src_opt.rel_path == rel_path:
            res = True
    except:
        res = True
    src_opt.rel_path = rel_path
    # k output is not empty for python,
    # but PythonMacros.cmake will take care of that
    if src_opt.type == 'python':
        src_opt.output = []
        return res
    try:
        old_output = set(src_opt.output)
        old_out_base = src_opt.out_base
        old_c_file = src_opt.c_file
    except:
        old_output = set()
        old_out_base = ""
        old_c_file = ""
    ofiles = []
    src_opt.output = ofiles
    if not src_file == old_out_base:
        res = True
    src_opt.out_base = src_file
    if src_opt.type == 'cpp':
        c_file = src_file + '.cpp'
    else:
        c_file = src_file + '.c'
    ofiles.append(c_file)
    if not c_file == old_c_file:
        res = True
    src_opt.c_file = c_file
    if src_opt.api:
        ofiles.append(src_file + '_api.h')
    if src_opt.header:
        ofiles.append(src_file + '.h')
    if not set(ofiles) == old_output:
        res = True
    return res

def check_output(result):
    if not ('sources' in result and 'base' in result and 'output' in result):
        return True
    os.chdir(result.base)
    res = False
    for src_file, src_opt in result.sources.items():
        if output_for_single(result, src_file, wrap_dict(src_opt)):
            res = True
    return res

def check_relation(result):
    res = False
    if check_dependency(result):
        res = True
    if check_output(result):
        res = True
    return res


def main():
    parser = argparse.ArgumentParser(argument_default=argparse.SUPPRESS)
    parser.add_argument('--include', dest='include',
                        action='append', help='Include Directories.')
    parser.add_argument('--basedir', dest='base',
                        action='store', help='Base Directory.')
    parser.add_argument('--outputdir', dest='output',
                        action='store', help='Output Directory.')
    parser.add_argument('--target', dest='target',
                        action='store', help='Make target name.')
    parser.add_argument('--py-result', dest='py_result',
                        action='store', help='Python result file.')
    parser.add_argument('--cmake', dest='cmake',
                        action='store', help='CMake result file.')

    parser.add_argument('--check-write', dest='write',
                        action='store_true', help='Check Dependency.',
                        default=False)
    # TODO
    parser.add_argument('--check-changed', dest='check',
                        action='store_true',
                        help='Check if cmake file need to be regenerated.',
                        default=False)

    parser.add_argument('--type', dest='type',
                        action='store', help='Compile type.', default='c')
    parser.add_argument('--api', dest='api',
                        action='store_true', help='Generate api file.',
                        default=False)
    parser.add_argument('--header', dest='header',
                        action='store_true', help='Generate header file.',
                        default=False)
    parser.add_argument('--source', dest='source_file',
                        action='store', help='Cython/Python source file.')
    parser.add_argument('--c-sources', dest='c_sources',
                        action='append', help='Additional c/cpp source file.',
                        default=[])
    parser.add_argument('--link', dest='link',
                        action='append', help='Additional libraries to link to.',
                        default=[])
    arg_res = parser.parse_args()
    result = load_py(arg_res.py_result)
    if arg_res.check:
        if check_relation(result):
            write_cmake(result)
            exit(-1)
        return
    check_global(result, arg_res)
    check_file(result, arg_res)
    if arg_res.write:
        check_relation(result)
    save_py(arg_res.py_result, result)
    if arg_res.write:
        write_cmake(result)

if __name__ == '__main__':
    try:
        main()
    except Exception:
        print_except()
        exit(-1)
    exit(0)
