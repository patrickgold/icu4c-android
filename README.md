# icu4c-android

WIP project for cross-compiling of ICU4C for Android NDK projects.

## How to use

### Requirements

- Host OS: 64-bit linux* or darwin*, if you are on Windows you can try
  using WSL
- Android NDK r19 or newer (it won't work with older versions!!)
- `realpath` for working with paths (should be installed on any modern distro)
- ICU source code (either use the source code from the submodule or download
  a source code archive and unpack it)

### Usage

A simple usage of the script, which will build ICU for arm and arm64 and
install them to the default location, is shown below:

```
$ chmod +x cc-icu4c.sh
$ ./cc-icu4c.sh build --arch=arm,arm64 --library-type=static
```

There are a lot of configuration options available, see below or use
```
$ ./cc-icu4c.sh build --help
```
to get the list of available options. Note: the `clean` action as well as the `--lib-*` options currently do nothing.

### Help output

```
Usage: ./cc-icu4c.sh <action> [options]

General options:
    --help          print this message (or specific help if <action> is defined) and exits
    --version       print the version and exits

Actions:
    build           builds the ICU library
    clean           cleans the build dir

Options for build action:
    --arch=arch1,arch2,...      comma-separated list of architectures to build the ICU library for. Supported
                                architectures: arm, arm64, x86 and x86_64. default=arm64
    --api=level                 minimum Android API level. default=23
    --build-dir=path            path to the build output dir. default=./build
    --icu-src-dir=path          path to the ICU4C source dir. default=./icu/icu4c
    --install-include-dir=path  path to the output dir for the include files. default=./build/install/include
    --install-libs-dir=path     path to the output dir for the library (and data) files. default=./build/install/libs
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
```

## Attribution

The following sources have helped a lot to write this script:
- https://unicode-org.github.io/icu/userguide/icu4c/build.html
- https://unicode-org.github.io/icu/userguide/icu4c/packaging.html#reduce-the-number-of-libraries-used
- https://unicode-org.github.io/icu-docs/apidoc/released/icu4c/uconfig_8h.html
- https://unicode-org.github.io/icu/userguide/icu_data/buildtool.html
- https://developer.android.com/ndk/guides/other_build_systems
- https://github.com/NanoMichael/cross_compile_icu4c_for_android

## License

```
Copyright 2021 Patrick Goldinger

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
