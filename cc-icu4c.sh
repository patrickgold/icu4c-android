#!/bin/bash

# Copyright 2021 Patrick Goldinger
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Relvevant docs and sources this scripts uses:
#  https://unicode-org.github.io/icu/userguide/icu4c/build.html
#  https://unicode-org.github.io/icu/userguide/icu4c/packaging.html#reduce-the-number-of-libraries-used
#  https://unicode-org.github.io/icu-docs/apidoc/released/icu4c/uconfig_8h.html
#  https://developer.android.com/ndk/guides/other_build_systems
#  https://github.com/NanoMichael/cross_compile_icu4c_for_android


usage() {
    cat <<EOE
Cross-compile ICU4C for Android NDK projects

Usage: $0 <action> [options]

General options:
    --help          print this message (or specific help if <action> is defined) and exits
    --version       print the version and exits

Actions:
    build           builds the ICU library
    clean           cleans the build dir
EOE
}

usage_build() {
    cat <<EOE
Options for build action:
    --arch=arch1,arch2,...      comma-separated list of architectures to build the ICU library for. Supported
                                architectures: arm, arm64, x86 and x86_64. default=arm64
    --api=level                 minimum Android API level. default=23
    --build-dir=path            path to the build output dir. default=./build
    --icu-src-dir=path          path to the ICU4C source dir. default=./icu/icu4c
    --ndk-dir=path              path to the NDK installation. If not defined, this script attempts to find the path
                                on its own. default=

    --lib-data[=yes|no]         if the 'data' library should be built. default=yes
    --lib-i18n[=yes|no]         if the 'i18n' library should be built. default=no
    --lib-io[=yes|no]           if the 'io' library should be built. default=no
    --lib-tu[=yes|no]           if the 'tu' library should be built. default=no
    --lib-uc[=yes|no]           if the 'uc' library should be built. default=yes

    --library-type=value        specify the library type. Possible values:
        shared      shared library (.dll/.so/etc.) (default)
        static      static library (.a/.lib/etc.)
    --library-bits=bits         specify the bits to use for the library (32, 64, 64else32, nochange). default=nochange
    --library-suffix=suffix     tag a suffix to the library names. default=

    --data-packaging            specify how to package ICU data. Possible values:
        files       raw files (.res, etc)
        archive     build a single icudtXX.dat file
        shared      shared library (.dll/.so/etc.)
        static      static library (.a/.lib/etc.)
        auto        build shared if possible (default)

    --require-PIC[=yes|no]      if a static library is built, specifies if the compiler flag -fPIC (Position
                                Independent Code) should be set. default=yes

    --enable-FEATURE[=yes|no]   enable/disable a FEATURE (list below)
    --enable-draft              enable draft APIs (and internal APIs). default=yes
    --enable-legacy-converters  enable legacy converters (everything apart from UTF, CESU-8, SCSU, BOCU-1, US-ASCII,
                                and ISO-8859-1). default=no
    --enable-samples            build ICU samples. default=no
    --enable-tests              build ICU tests. default=no
EOE
}

usage_clean() {
    cat <<EOE
Options for clean action:
    --build-dir=path            path to the build output dir. default=./build
EOE
}

version() {
    cat <<EOE
ICU4C cross-compile script for Android NDK v0.1.0
Copyright (C) 2021 Patrick Goldinger
License: Apache 2.0 <http://www.apache.org/licenses/LICENSE-2.0>
EOE
}

ERR_COLOR='\033[1;31m'
SUCCESS_COLOR='\033[1;32m'
WARNING_COLOR='\033[1;33m'
NO_COLOR='\033[0m'

echo_error() {
    echo -e "${ERR_COLOR}$1${NO_COLOR}"
}
echo_warning() {
    echo -e "${WARNING_COLOR}$1${NO_COLOR}"
}
echo_success() {
    echo -e "${SUCCESS_COLOR}$1${NO_COLOR}"
}


### --------- Initialize script constants  ---------

YES="yes"
NO="no"

ACTION_BUILD="build"
ACTION_CLEAN="clean"

LIB_TYPE_FILES="files"
LIB_TYPE_ARCHIVE="archive"
LIB_TYPE_SHARED="shared"
LIB_TYPE_STATIC="static"
LIB_TYPE_AUTO="auto"

BITS_32="32"
BITS_64="64"
BITS_64ELSE32="64else32"
BITS_NOCHANGE="nochange"


### --------- Initialize script global variables  ---------

flag_help=NO
flag_version=NO

action=""

arch="arm64"
api=23
build_dir="build"
icu_src_dir="icu/icu4c"
ndk_dir=""

lib_data=YES
lib_i18n=NO
lib_io=NO
lib_tu=NO
lib_uc=YES

library_type=LIB_TYPE_SHARED
library_bits=BITS_NOCHANGE
library_suffix=""

data_packaging=LIB_TYPE_AUTO

require_PIC=YES

enable_draft=YES
enable_legacy_converters=NO
enable_samples=NO
enable_tests=NO


### --------- Action logic  ---------

build() {
    echo "BUILD!!!!"
    return 0
}

clean() {
    echo "CLEAN!!!!"
    return 0
}


### --------- Parse action and arguments  ---------

for arg in "$@"
do
    if [[ "$arg" = --* ]]; then
        # Is option
        arg=${arg:2}
        arg_name="$arg"
        arg_value=""
        if [[ $arg = *=* ]]; then
            IFS='=' read -ra tmp_args <<< "$arg"
            n=0
            for tmp in "${tmp_args[@]}"
            do
                if [ $n = 0 ]; then
                    arg_name="$tmp"
                elif [ $n = 1 ]; then
                    arg_value="$tmp"
                else
                    echo_error "Invalid syntax at --$arg: Unexpected second assignment character '='. exiting..."
                    exit 1
                fi
                n=$((n + 1))
            done
            unset n
            unset tmp
            unset tmp_args
        fi
        case "$arg_name" in
        "help" )
            flag_help=YES
            ;;
        "version" )
            flag_version=YES
            ;;
        "arch" )
            arch="$arg_value"
            ;;
        "api" )
            api="$arg_value"
            ;;
        "build-dir" )
            build_dir="$arg_value"
            ;;
        "icu-src-dir" )
            icu_src_dir="$arg_value"
            ;;
        "ndk-dir" )
            ndk_dir="$arg_value"
            ;;
        "lib-data" )
            lib_data="$arg_value"
            ;;
        "lib-i18n" )
            lib_i18n="$arg_value"
            ;;
        "lib-io" )
            lib_io="$arg_value"
            ;;
        "lib-tu" )
            lib_tu="$arg_value"
            ;;
        "lib-uc" )
            lib_uc="$arg_value"
            ;;
        "library-type" )
            library_type="$arg_value"
            ;;
        "library-bits" )
            library_bits="$arg_value"
            ;;
        "library-suffix" )
            library_suffix="$arg_value"
            ;;
        "data-packaging" )
            data_packaging="$arg_value"
            ;;
        "require-PIC" )
            require_PIC="$arg_value"
            ;;
        "enable-draft" )
            enable_draft="$arg_value"
            ;;
        "enable-legacy-converters" )
            enable_legacy_converters="$arg_value"
            ;;
        "enable-samples" )
            enable_samples="$arg_value"
            ;;
        "enable-tests" )
            enable_tests="$arg_value"
            ;;
        * )
            echo_warning "Ignoring unknown option '$arg_name'"
            ;;
        esac
        unset arg_name
        unset arg_value
    else
        # Assume is action
        action="$arg"
    fi
done


### --------- Execute action  ---------

if [ $flag_version = YES ]; then
    version
    exit 0
fi

case $action in
"$ACTION_BUILD" )
    if [ $flag_help = YES ]; then
        usage_build
    else
        build # Will exit the script with 0 or 1
    fi
    ;;
"$ACTION_CLEAN" )
    if [ $flag_help = YES ]; then
        usage_clean
    else
        clean # Will exit the script with 0 or 1
    fi
    ;;
"" )
    if [ $flag_help = YES ]; then
        usage
    else
        echo_error "No action specified. Try --help to see how to use this script."
        exit 1
    fi
    ;;
* )
    echo_error "Unknown action '$action'. Try --help to see how to use this script."
    exit 1
    ;;
esac

exit 0
