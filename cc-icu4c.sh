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
#  https://unicode-org.github.io/icu/userguide/icu_data/buildtool.html
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
    --install-include-dir=path  path to the output dir for the include files. default=./build/install/include
    --install-libs-dir=path     path to the output dir for the library files. default=./build/install/libs
    --install-data-dir=path     path to the output dir for the data files (only used when the --data-packaging option
                                is either 'files' or 'archive'). default=./build/install/data
    --ndk-dir=path              path to the NDK installation. If not defined, this script attempts to find the path
                                on its own. default=

    --lib-data=yes|no           if the 'data' library should be built. default=yes [NYI]
    --lib-i18n=yes|no           if the 'i18n' library should be built. default=no [NYI]
    --lib-io=yes|no             if the 'io' library should be built. default=no
    --lib-tu=yes|no             if the 'tu' library should be built. default=no [NYI]
    --lib-uc=yes|no             if the 'uc' library should be built. default=yes [NYI]

    --library-type=value        specify the library type. Possible values:
        shared      shared library (.dll/.so/etc.) (default)
        static      static library (.a/.lib/etc.)
    --library-bits=bits         specify the bits to use for the library (32, 64, 64else32, nochange). default=nochange
    --library-suffix=suffix     tag a suffix to the library names. default=

    --data-filter-file=path     specify a filter JSON file to reduce ICU data size. default=
                                See https://unicode-org.github.io/icu/userguide/icu_data/buildtool.html for more info.
    --data-packaging            specify how to package ICU data. Possible values:
        files       raw files (.res, etc)
        archive     build a single icudtXX.dat file
        shared      shared library (.dll/.so/etc.)
        static      static library (.a/.lib/etc.)
        auto        build shared if possible (default)

    --require-PIC[=yes|no]      if a static library is built, specifies if the compiler flag -fPIC (Position
                                Independent Code) should be set. default=yes

    --enable-FEATURE[=yes|no]   enable/disable a FEATURE (list below)
    --enable-collation          turn on collation and collation-based string search. default=yes
    --enable-draft              enable draft APIs (and internal APIs). default=yes
    --enable-formatting         turn on all formatting and calendar/timezone services. default=yes
    --enable-legacy-converters  enable legacy converters (everything apart from UTF, CESU-8, SCSU, BOCU-1, US-ASCII,
                                and ISO-8859-1). default=no
    --enable-regex              turn on the regular expression functionality. default=yes
    --enable-samples            build ICU samples. default=no
    --enable-tests              build ICU tests. default=no
    --enable-transliteration    turn on script-to-script transliteration. default=yes
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

readonly YES="yes"
readonly NO="no"

readonly ACTION_BUILD="build"
readonly ACTION_CLEAN="clean"

readonly LIB_TYPE_FILES="files"
readonly LIB_TYPE_ARCHIVE="archive"
readonly LIB_TYPE_SHARED="shared"
readonly LIB_TYPE_STATIC="static"
readonly LIB_TYPE_AUTO="auto"

readonly BITS_32="32"
readonly BITS_64="64"
readonly BITS_64ELSE32="64else32"
readonly BITS_NOCHANGE="nochange"

bool_to_int() {
    if [ "$1" = $YES ]; then
        echo -e "1"
    else
        echo -e "0"
    fi
}
bool_to_int_inv() {
    if [ "$1" = $YES ]; then
        echo -e "0"
    else
        echo -e "1"
    fi
}


### --------- Initialize script global variables  ---------

working_dir=$(pwd)

flag_help=$NO
flag_version=$NO

action=""

arch_list="arm64"
api=23
build_dir="./build"
icu_src_dir="./icu/icu4c"
install_include_dir="./build/install/include"
install_libs_dir="./build/install/libs"
install_data_dir="./build/install/data"
ndk_dir=""

lib_data=$YES
lib_i18n=$NO
lib_io=$NO
lib_tu=$NO
lib_uc=$YES

library_type=$LIB_TYPE_SHARED
library_bits=$BITS_NOCHANGE
library_suffix=""

data_filter_file=""
data_packaging=$LIB_TYPE_AUTO

require_PIC=$YES

enable_collation=$YES
enable_draft=$YES
enable_formatting=$YES
enable_legacy_converters=$NO
enable_regex=$YES
enable_samples=$NO
enable_tests=$NO
enable_transliteration=$YES


### --------- Action logic  ---------

prepare_icu_c_cxx_cpp() {
    icu_configure_args="\
        --enable-strict=no --enable-extras=no --enable-draft=$enable_draft \
        --enable-samples=$enable_samples --enable-tests=$enable_tests \
        --enable-renaming=no --enable-icuio=$lib_io --enable-layoutex=no \
        --with-library-bits=$library_bits --with-library-suffix=$library_suffix"
    __FLAGS="-Os -fno-short-wchar -fno-short-enums -ffunction-sections -fdata-sections -fvisibility=hidden \
        -DU_USING_ICU_NAMESPACE=0 -DU_HAVE_NL_LANGINFO_CODESET=0 -DU_TIMEZONE=0 \
        -DU_DISABLE_RENAMING=1 \
        -DUCONFIG_NO_COLLATION=$(bool_to_int_inv $enable_collation) \
        -DUCONFIG_NO_FORMATTING=$(bool_to_int_inv $enable_formatting) \
        -DUCONFIG_NO_LEGACY_CONVERSION=$(bool_to_int_inv $enable_legacy_converters) \
        -DUCONFIG_NO_REGULAR_EXPRESSIONS=$(bool_to_int_inv $enable_regex) \
        -DUCONFIG_NO_TRANSLITERATION=$(bool_to_int_inv $enable_transliteration)"

    case "$library_type" in
    "$LIB_TYPE_SHARED" )
        icu_configure_args+=" --enable-static=no --enable-shared=yes"
        ;;
    "$LIB_TYPE_STATIC" )
        icu_configure_args+=" --enable-static=yes --enable-shared=no"
        __FLAGS+=" -DU_STATIC_IMPLEMENTATION"
        ;;
    esac
    if [ $data_packaging = $LIB_TYPE_SHARED ]; then
        icu_configure_args+=" --with-data-packaging=library"
    else
        icu_configure_args+=" --with-data-packaging=$data_packaging"
    fi
    if [ $require_PIC = $YES ]; then
        __FLAGS+=" -fPIC"
    fi

    export CFLAGS="$__FLAGS"
    export CXXFLAGS="$__FLAGS"
    export CPPFLAGS="$__FLAGS"

    if [ -n "$data_filter_file" ]; then
        if ICU_DATA_FILTER_FILE=$(realpath "$data_filter_file"); then
            export ICU_DATA_FILTER_FILE=$ICU_DATA_FILTER_FILE
        fi
    fi
}

build() {
    case $OSTYPE in
    darwin* )
        host_os_name="darwin"
        host_os_arch="darwin-x86_64" # TODO: find correct host arch
        host_os_build_type="MacOSX/GCC" # Identifier as wanted by the ICU configure script
        ;;
    linux* )
        host_os_name="linux"
        host_os_arch="linux-x86_64" # TODO: find correct host arch
        host_os_build_type="Linux" # Identifier as wanted by the ICU configure script
        ;;
    * )
        echo_error "${OSTYPE} is not supported, currently only support darwin* and linux*. Exiting"
        exit 1
        ;;
    esac
    echo "Host OS name:         $host_os_name"
    echo "Host OS arch:         $host_os_arch"
    echo "Host OS build type:   $host_os_build_type"
    echo

    mkdir -p "$build_dir"
    if ! build_dir=$(realpath "$build_dir"); then
        echo_error "Cannot find real path for given build dir '$build_dir'. Exiting"
        return 1
    fi
    if ! icu_src_dir=$(realpath "$icu_src_dir"); then
        echo_error "Cannot find real path for given ICU src dir '$icu_src_dir'. Exiting"
        return 1
    fi

    prepare_icu_c_cxx_cpp

    if ! build_host; then
        echo_error "Building for host failed. Exiting"
        exit 1
    fi
    if ! copy_host_include_files; then
        exit 1
    fi
    if ! copy_host_data_files; then
        exit 1
    fi

    IFS=',' read -ra tmp_arch <<< "$arch_list"
    for tmp in "${tmp_arch[@]}"
    do
        if ! build_android "$tmp"; then
            exit 1
        fi
    done
    unset tmp
    unset tmp_arch

    return 0
}

build_host() {
    echo "Begin build process for host"
    echo

    host_build_dir="$build_dir/host"
    mkdir -p "$host_build_dir"

    if [ -d "$host_build_dir/icu_build" ]; then
        echo "Host build already exists at '$host_build_dir', reusing."
        echo
        return 0
    fi

    cd "$host_build_dir" || return 1

    export ICU_SOURCES=$icu_src_dir
    # -pthread is needed, see https://github.com/protocolbuffers/protobuf/issues/4958
    LDFLAGS="-std=gnu++17 -pthread"
    # C, CXX and CPP flags have already been set

    if [ $host_os_name = "linux" ]; then
        LDFLAGS+=" -Wl,--gc-sections"
    elif [ $host_os_name = "darwin" ]; then
        # gcc on OSX does not support --gc-sections
        LDFLAGS+=" -Wl,-dead_strip"
    fi
    export LDFLAGS

    # Set --prefix option to disable install to the system,
    # since we only need the libraries and header files
    # shellcheck disable=SC2086
    (exec "$ICU_SOURCES/source/runConfigureICU" $host_os_build_type \
    --prefix="$host_build_dir/icu_build" $icu_configure_args)

    if ! make -j16; then
        cd "$working_dir" || return 1
        return 1
    fi

    if ! make install; then
        cd "$working_dir" || return 1
        return 1
    fi

    if [ ! -d "$host_build_dir/icu_build/include/unicode" ]; then
        cd "$working_dir" || return 1
        return 1
    fi

    #if ! test; then
    #    cd "$working_dir" || return 1
    #    return 1
    #fi

    cd "$working_dir" || return 1
    return 0
}

build_android() {
    local arch=$1

    echo "Begin build process for Android (arch=$arch)"
    echo

    if [ -z "$arch" ]; then
        echo_error "No arch specified, exiting."
        exit 1
    fi
    case $arch in
    "arm" )
        local abi="armeabi-v7a"
        local target="armv7a-linux-androideabi"
        ;;
    "arm64" )
        local abi="arm64-v8a"
        local target="aarch64-linux-android"
        ;;
    "x86" )
        local abi="x86"
        local target="i686-linux-android"
        ;;
    "x86_64" )
        local abi="x86_64"
        local target="x86_64-linux-android"
        ;;
    * )
        echo_error "Specified arch '$arch' is not supported by this build script. Exiting"
        exit 1
    esac
    echo "Arch:     $arch"
    echo "ABI:      $abi"
    echo "Target:   $target"
    echo

    if [ "$ndk_dir" = "" ]; then
        echo "Searching for NDK installation..."
        if [ -n "$NDK" ] && [ -d "$NDK" ]; then
            :
        else
            if ! NDK=$(dirname "$(command -v ndk-build)"); then
                echo_error "Failed to find an NDK installation. Either it is not installed or missing from \$PATH. Exiting"
                exit 1
            fi
        fi
    else
        if ! NDK=$(realpath "$ndk_dir"); then
            echo_error "Failed find real path for given NDK dir '$ndk_dir'. Exiting"
            exit 1
        fi
    fi
    if [ -z "$NDK" ] || [ ! -d "$NDK" ] || [ ! -f "$NDK/ndk-build" ]; then
        echo_error "NDK installation at '$NDK' could not be verified for its validity. Exiting"
        exit 1
    fi
    echo "Found and using NDK installation at '$NDK'"

    local toolchain="$NDK/toolchains/llvm/prebuilt/$host_os_arch"
    if [ ! -d "$toolchain" ]; then
        echo_error "Expected toolchain '$toolchain', could not resolve path. Exiting"
        exit 1
    fi
    echo "Selecting toolchain '$toolchain'"
    echo

    android_build_dir="$working_dir/build/android/$arch"
    mkdir -p "$android_build_dir"
    cd "$android_build_dir" || return 1

    export TARGET=$target
    export TOOLCHAIN=$toolchain
    export API=$api
    export AR=$TOOLCHAIN/bin/llvm-ar
    export CC=$TOOLCHAIN/bin/$TARGET$API-clang
    export AS=$CC
    export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
    export LD=$TOOLCHAIN/bin/ld

    export ICU_SOURCES=$icu_src_dir
    export ICU_CROSS_BUILD=$host_build_dir
    export ANDROIDVER=$API
    export NDK_STANDARD_ROOT=$TOOLCHAIN
    export LDFLAGS="-lc -lstdc++ -Wl,--gc-sections,-rpath-link=$NDK_STANDARD_ROOT/sysroot/usr/lib/"
    export PATH=$PATH:$NDK_STANDARD_ROOT/bin

    # shellcheck disable=SC2086
    (exec "$ICU_SOURCES/source/configure" --with-cross-build="$ICU_CROSS_BUILD" \
    $icu_configure_args --host=$TARGET --prefix="$PWD/icu_build")

    if ! make -j16; then
        cd "$working_dir" || return 1
        return 1
    fi

    cd "$working_dir" || return 1

    copy_android_lib_files "$abi"

    return 0
}

copy_host_include_files() {
    local include_src_dir="$host_build_dir/icu_build/include"

    mkdir -p "$install_include_dir"
    if ! install_include_dir=$(realpath "$install_include_dir"); then
        echo_error "Cannot find real path for given install include dir '$install_include_dir'. Exiting"
        return 1
    fi

    echo "Copying include files"
    echo " from src: $include_src_dir"
    echo " to dst:   $install_include_dir"
    if cp -r "$include_src_dir/"* "$install_include_dir"; then
        echo "OK"
        return 0
    else
        echo "FAILED"
        return 1
    fi
}

copy_host_data_files() {
    if ! [ $data_packaging == $LIB_TYPE_ARCHIVE ]; then
        return 0
    fi
    local data_src_dir="$host_build_dir/data/out"
    local install_dataa_dir="$install_data_dir"

    mkdir -p "$install_dataa_dir"
    if ! install_dataa_dir=$(realpath "$install_dataa_dir"); then
        echo_error "Cannot find real path for given install data dir '$install_dataa_dir'. Exiting"
        return 1
    fi

    echo "Copying data files"
    echo " from src: $data_src_dir"
    echo " to dst:   $install_dataa_dir"
    if cp -r "$data_src_dir/"*".dat" "$install_dataa_dir"; then
        echo "OK"
        return 0
    else
        echo "FAILED"
        return 1
    fi
}

copy_android_lib_files() {
    local lib_src_dir="$android_build_dir/lib"
    local install_lib_dir="$install_libs_dir/$1"

    mkdir -p "$install_lib_dir"
    if ! install_lib_dir=$(realpath "$install_lib_dir"); then
        echo_error "Cannot find real path for given install libs dir '$install_lib_dir'. Exiting"
        return 1
    fi

    echo "Copying library files"
    echo " from src: $lib_src_dir"
    echo " to dst:   $install_lib_dir"
    if cp -r "$lib_src_dir/"* "$install_lib_dir"; then
        echo "OK"
        if [ $data_packaging == $LIB_TYPE_ARCHIVE ]; then
            local lib_src_dir="$android_build_dir/stubdata"

            echo "Copying library files for stubdata"
            echo " from src: $lib_src_dir"
            echo " to dst:   $install_lib_dir"
            if cp -r "$lib_src_dir/libicudata"* "$install_lib_dir"; then
                echo "OK"
                return 0
            else
                echo "FAILED"
                return 1
            fi
        fi
        return 0
    else
        echo "FAILED"
        return 1
    fi
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
            flag_help=$YES
            ;;
        "version" )
            flag_version=$YES
            ;;
        "arch" )
            arch_list="$arg_value"
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
        "install-include-dir" )
            install_include_dir="$arg_value"
            ;;
        "install-libs-dir" )
            install_libs_dir="$arg_value"
            ;;
        "install-data-dir" )
            install_data_dir="$arg_value"
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
        "data-filter-file" )
            data_filter_file="$arg_value"
            ;;
        "data-packaging" )
            data_packaging="$arg_value"
            ;;
        "require-PIC" )
            require_PIC="$arg_value"
            ;;
        "enable-collation" )
            enable_collation="$arg_value"
            ;;
        "enable-draft" )
            enable_draft="$arg_value"
            ;;
        "enable-formatting" )
            enable_formatting="$arg_value"
            ;;
        "enable-legacy-converters" )
            enable_legacy_converters="$arg_value"
            ;;
        "enable-regex" )
            enable_regex="$arg_value"
            ;;
        "enable-samples" )
            enable_samples="$arg_value"
            ;;
        "enable-tests" )
            enable_tests="$arg_value"
            ;;
        "enable-transliteration" )
            enable_transliteration="$arg_value"
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

if [ $flag_version = $YES ]; then
    version
    exit 0
fi

case $action in
"$ACTION_BUILD" )
    if [ $flag_help = $YES ]; then
        usage_build
    else
        if ! build ; then
            echo_error "Build failed!"
        else
            echo_success "Build suceeded!"
        fi
    fi
    ;;
"$ACTION_CLEAN" )
    if [ $flag_help = $YES ]; then
        usage_clean
    else
        clean # Will exit the script with 0 or 1
    fi
    ;;
"" )
    if [ $flag_help = $YES ]; then
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
