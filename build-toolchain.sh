#! /usr/bin/env bash
# Copyright (c) 2011, 2012, ARM Limited
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of ARM nor the names of its contributors may be used
#       to endorse or promote products derived from this software without
#       specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

set -e
set -x
set -u
set -o pipefail

umask 022

exec < /dev/null

script_path=`cd $(dirname $0) && pwd -P`
. $script_path/build-common.sh

# This file contains the sequence of commands used to build the ARM EABI toolchain.
usage ()
{
    echo "Usage:" >&2
    echo "      $0 [--skip_mingw32] [--debug]" >&2
    exit 1
}
if [ $# -gt 2 ] ; then
    usage
fi
skip_mingw32=yes
DEBUG_BUILD_OPTIONS=no
for ac_arg; do
    case $ac_arg in
        --skip_mingw32)
            skip_mingw32=yes
            ;;
        --debug)
            DEBUG_BUILD_OPTIONS="-O0 -g "
            ;;
        *)
            usage
            ;;
    esac
done

mkdir -p $BUILDDIR_LINUX
rm -rf $INSTALLDIR_LINUX && mkdir -p $INSTALLDIR_LINUX
if [ "x$skip_mingw32" != "xyes" ] ; then
mkdir -p $BUILDDIR_MINGW
rm -rf $INSTALLDIR_MINGW && mkdir -p $INSTALLDIR_MINGW
fi
rm -rf $PACKAGEDIR && mkdir -p $PACKAGEDIR

cd $SRCDIR

echo Task [III-0] /$HOST_LINUX/binutils/
rm -rf $BUILDDIR_LINUX/binutils && mkdir -p $BUILDDIR_LINUX/binutils
pushd $BUILDDIR_LINUX/binutils
saveenv
saveenvvar CFLAGS "-I$BUILDDIR_LINUX/host-libs/zlib/include -O2"
saveenvvar CPPFLAGS "-I$BUILDDIR_LINUX/host-libs/zlib/include"
saveenvvar LDFLAGS "-L$BUILDDIR_LINUX/host-libs/zlib/lib"
$SRCDIR/$BINUTILS/configure --build=$BUILD \
    --host=$HOST_LINUX \
    --target=$TARGET \
    --prefix=$INSTALLDIR_LINUX \
    --disable-nls \
    --with-sysroot=$INSTALLDIR_LINUX/arm-none-eabi \
    "--with-pkgversion=$PKGVERSION"

if [ "x$DEBUG_BUILD_OPTIONS" != "xno" ] ; then
    make CFLAGS="-I$BUILDDIR_LINUX/host-libs/zlib/include $DEBUG_BUILD_OPTIONS" -j$JOBS
else
    make -j$JOBS
fi

make infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install
restoreenv
popd

pushd $INSTALLDIR_LINUX
rm -rf ./lib
popd

echo Task [III-1] /$HOST_LINUX/gcc-first/
rm -rf $BUILDDIR_LINUX/gcc-first && mkdir -p $BUILDDIR_LINUX/gcc-first
pushd $BUILDDIR_LINUX/gcc-first
$SRCDIR/$GCC/configure --build=$BUILD --host=$HOST_LINUX --target=$TARGET \
    --prefix=$INSTALLDIR_LINUX \
    --enable-languages=c \
    --disable-decimal-float \
    --disable-libffi \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libstdcxx-pch \
    --disable-lto \
    --disable-nls \
    --disable-shared \
    --disable-threads \
    --disable-tls \
    --with-newlib \
    --without-headers \
    --with-gnu-as \
    --with-gnu-ld \
    --with-sysroot=$INSTALLDIR_LINUX/arm-none-eabi \
    --with-gmp=$BUILDDIR_LINUX/host-libs/usr \
    --with-mpfr=$BUILDDIR_LINUX/host-libs/usr \
    --with-mpc=$BUILDDIR_LINUX/host-libs/usr \
    --with-ppl=$BUILDDIR_LINUX/host-libs/usr \
    --with-cloog=$BUILDDIR_LINUX/host-libs/usr \
    --with-libelf=$BUILDDIR_LINUX/host-libs/usr \
    "--with-host-libstdcxx=-lstdc++" \
    "--with-pkgversion=$PKGVERSION" \
    --with-extra-multilibs=armv6-m,armv7-m,armv7e-m

make -j$JOBS all-gcc

make infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install-gcc

popd

pushd $INSTALLDIR_LINUX
rm -rf bin/arm-none-eabi-gccbug
rm -rf ./lib/libiberty.a
test -d include && rmdir include
popd

echo Task [III-2] /$HOST_LINUX/newlib/
saveenv
prepend_path PATH $INSTALLDIR_LINUX/bin
saveenvvar CFLAGS_FOR_TARGET '-g -O2 -fno-unroll-loops -ffunction-sections -fdata-sections'
rm -rf $BUILDDIR_LINUX/newlib && mkdir -p $BUILDDIR_LINUX/newlib
pushd $BUILDDIR_LINUX/newlib

$SRCDIR/$NEWLIB/configure --build=$BUILD \
    --host=$HOST_LINUX \
    --target=$TARGET \
    --prefix=$INSTALLDIR_LINUX \
    --enable-newlib-io-long-long \
    --enable-newlib-register-fini \
    --disable-newlib-supplied-syscalls \
    --disable-nls

make -j$JOBS

make infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install

popd
restoreenv

echo Task [III-3] /$HOST_LINUX/gcc-final/
rm -f $INSTALLDIR_LINUX/arm-none-eabi/usr
mkdir -p $INSTALLDIR_LINUX/arm-none-eabi
ln -s . $INSTALLDIR_LINUX/arm-none-eabi/usr

rm -rf $BUILDDIR_LINUX/gcc-final && mkdir -p $BUILDDIR_LINUX/gcc-final
pushd $BUILDDIR_LINUX/gcc-final

$SRCDIR/$GCC/configure --build=$BUILD --host=$HOST_LINUX --target=$TARGET \
    --prefix=$INSTALLDIR_LINUX \
    --enable-languages=c,c++ \
    --disable-decimal-float \
    --disable-libffi \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libstdcxx-pch \
    --disable-lto \
    --disable-nls \
    --disable-shared \
    --disable-threads \
    --disable-tls \
    --with-gnu-as \
    --with-gnu-ld \
    --with-newlib \
    --with-headers=yes \
    --with-sysroot=$INSTALLDIR_LINUX/arm-none-eabi \
    --with-gmp=$BUILDDIR_LINUX/host-libs/usr \
    --with-mpfr=$BUILDDIR_LINUX/host-libs/usr \
    --with-mpc=$BUILDDIR_LINUX/host-libs/usr \
    --with-ppl=$BUILDDIR_LINUX/host-libs/usr \
    --with-cloog=$BUILDDIR_LINUX/host-libs/usr \
    --with-libelf=$BUILDDIR_LINUX/host-libs/usr \
    "--with-host-libstdcxx=-lstdc++" \
    "--with-pkgversion=$PKGVERSION" \
    --with-extra-multilibs=armv6-m,armv7-m,armv7e-m

if [ "x$DEBUG_BUILD_OPTIONS" != "xno" ] ; then
    make CFLAGS="$DEBUG_BUILD_OPTIONS" -j$JOBS
else
    make -j$JOBS
fi

make htmldir=$INSTALLDIR_LINUX/share/doc/html pdfdir=$INSTALLDIR_LINUX/share/doc/pdf infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install

pushd $INSTALLDIR_LINUX
rm -rf bin/arm-none-eabi-gccbug
LIBIBERTY_LIBRARIES=`find $INSTALLDIR_LINUX/arm-none-eabi/lib -name libiberty.a`
for libiberty_lib in $LIBIBERTY_LIBRARIES ; do
    rm -rf $libiberty_lib
done
rm -rf ./lib/libiberty.a
test -d include && rmdir include
popd

rm -f $INSTALLDIR_LINUX/arm-none-eabi/usr
popd

echo Task [III-4] /$HOST_LINUX/gdb/
rm -rf $BUILDDIR_LINUX/gdb && mkdir -p $BUILDDIR_LINUX/gdb
pushd $BUILDDIR_LINUX/gdb
saveenv
saveenvvar CFLAGS "-I$BUILDDIR_LINUX/host-libs/zlib/include -O2"
saveenvvar CPPFLAGS "-I$BUILDDIR_LINUX/host-libs/zlib/include"
saveenvvar LDFLAGS "-L$BUILDDIR_LINUX/host-libs/usr/lib -L$BUILDDIR_LINUX/host-libs/zlib/lib"
$SRCDIR/$GDB/configure --build=$BUILD \
    --host=$HOST_LINUX \
    --target=$TARGET \
    --prefix=$INSTALLDIR_LINUX \
    --disable-nls \
    --disable-sim \
    --with-libexpat-prefix=$BUILDDIR_LINUX/host-libs/usr \
    --with-system-gdbinit=$INSTALLDIR_LINUX/i686-pc-linux-gnu/arm-none-eabi/lib/gdbinit \
    '--with-gdb-datadir='\''${prefix}'\''/arm-none-eabi/share/gdb' \
    "--with-pkgversion=$PKGVERSION"

if [ "x$DEBUG_BUILD_OPTIONS" != "xno" ] ; then
    make CFLAGS="-I$BUILDDIR_LINUX/host-libs/zlib/include $DEBUG_BUILD_OPTIONS" -j$JOBS
else
    make -j$JOBS
fi

make infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install
restoreenv
popd

echo Task [III-5] /$HOST_LINUX/pretidy/
rm -rf $INSTALLDIR_LINUX/lib/libiberty.a
find $INSTALLDIR_LINUX -name '*.la' -exec rm '{}' ';'

echo Task [III-6] /$HOST_LINUX/strip_host_objects/
if [ "x$DEBUG_BUILD_OPTIONS" = "xno" ] ; then
    STRIP_BINARIES=`find $INSTALLDIR_LINUX/bin/ -name arm-none-eabi-\*`
    for bin in $STRIP_BINARIES ; do
        strip_binary strip $bin
    done

    STRIP_BINARIES=`find $INSTALLDIR_LINUX/arm-none-eabi/bin/ -maxdepth 1 -mindepth 1 -name \*`
    for bin in $STRIP_BINARIES ; do
        strip_binary strip $bin
    done

    STRIP_BINARIES=`find $INSTALLDIR_LINUX/libexec/gcc/arm-none-eabi/$GCC_VER/ -name \*`
    for bin in $STRIP_BINARIES ; do
        strip_binary strip $bin
    done
fi

echo Task [III-7] /$HOST_LINUX/strip_target_objects/
saveenv
prepend_path PATH $INSTALLDIR_LINUX/bin
TARGET_LIBRARIES=`find $INSTALLDIR_LINUX/arm-none-eabi/lib -name \*.a`
for target_lib in $TARGET_LIBRARIES ; do
    arm-none-eabi-objcopy -R .comment -R .note -R .debug_info -R .debug_aranges -R .debug_pubnames -R .debug_pubtypes -R .debug_abbrev -R .debug_line -R .debug_str -R .debug_ranges -R .debug_loc $target_lib || true
done

TARGET_OBJECTS=`find $INSTALLDIR_LINUX/arm-none-eabi/lib -name \*.o`
for target_obj in $TARGET_OBJECTS ; do
    arm-none-eabi-objcopy -R .comment -R .note -R .debug_info -R .debug_aranges -R .debug_pubnames -R .debug_pubtypes -R .debug_abbrev -R .debug_line -R .debug_str -R .debug_ranges -R .debug_loc $target_obj || true
done

TARGET_LIBRARIES=`find $INSTALLDIR_LINUX/lib/gcc/arm-none-eabi/$GCC_VER -name \*.a`
for target_lib in $TARGET_LIBRARIES ; do
    arm-none-eabi-objcopy -R .comment -R .note -R .debug_info -R .debug_aranges -R .debug_pubnames -R .debug_pubtypes -R .debug_abbrev -R .debug_line -R .debug_str -R .debug_ranges -R .debug_loc $target_lib || true
done

TARGET_OBJECTS=`find $INSTALLDIR_LINUX/lib/gcc/arm-none-eabi/$GCC_VER -name \*.o`
for target_obj in $TARGET_OBJECTS ; do
    arm-none-eabi-objcopy -R .comment -R .note -R .debug_info -R .debug_aranges -R .debug_pubnames -R .debug_pubtypes -R .debug_abbrev -R .debug_line -R .debug_str -R .debug_ranges -R .debug_loc $target_obj || true
done
restoreenv

echo Task [III-8] /$HOST_LINUX/package_tbz2/
rm -f $PACKAGEDIR/$PACKAGE_NAME.tar.bz2
pushd $BUILDDIR_LINUX
rm -f $INSTALL_PACKAGE_NAME
cp $ROOT/$RELEASE_FILE $INSTALLDIR_LINUX/
cp $ROOT/$README_FILE $INSTALLDIR_LINUX/
cp $ROOT/$LICENSE_FILE $INSTALLDIR_LINUX/
ln -s $INSTALLDIR_LINUX $INSTALL_PACKAGE_NAME
tar cjf $PACKAGEDIR/$PACKAGE_NAME.tar.bz2   \
    --exclude=host-$HOST_LINUX              \
    --exclude=host-$HOST_MINGW              \
    $INSTALL_PACKAGE_NAME/arm-none-eabi     \
    $INSTALL_PACKAGE_NAME/bin               \
    $INSTALL_PACKAGE_NAME/lib               \
    $INSTALL_PACKAGE_NAME/libexec           \
    $INSTALL_PACKAGE_NAME/share             \
    $INSTALL_PACKAGE_NAME/$RELEASE_FILE     \
    $INSTALL_PACKAGE_NAME/$README_FILE      \
    $INSTALL_PACKAGE_NAME/$LICENSE_FILE
rm -f $INSTALL_PACKAGE_NAME
popd

# skip building mingw32 toolchain if "--skip_mingw32" specified
# this huge if statement controls all $BUILDDIR_MINGW tasks till "task [3-1]"
if [ "x$skip_mingw32" != "xyes" ] ; then
saveenv
saveenvvar CC_FOR_BUILD gcc
saveenvvar CC $HOST_MINGW_TOOL-gcc
saveenvvar CXX $HOST_MINGW_TOOL-g++
saveenvvar AR $HOST_MINGW_TOOL-ar
saveenvvar RANLIB $HOST_MINGW_TOOL-ranlib
saveenvvar STRIP $HOST_MINGW_TOOL-strip
saveenvvar NM $HOST_MINGW_TOOL-nm

echo Task [IV-0] /$HOST_MINGW/host_unpack/
rm -rf $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX && mkdir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX
pushd $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX
ln -s . $INSTALL_PACKAGE_NAME
tar xf $PACKAGEDIR/$PACKAGE_NAME.tar.bz2 --bzip2
rm $INSTALL_PACKAGE_NAME
popd

if [ `uname` == Darwin ]; then
    # no need to repackage the sources
    exit 0
fi

echo Task [IV-1] /$HOST_MINGW/binutils/
prepend_path PATH $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/bin
rm -rf $BUILDDIR_MINGW/binutils && mkdir -p $BUILDDIR_MINGW/binutils
pushd $BUILDDIR_MINGW/binutils
saveenv
saveenvvar CFLAGS "-I$BUILDDIR_MINGW/host-libs/zlib/include -O2"
saveenvvar CPPFLAGS "-I$BUILDDIR_MINGW/host-libs/zlib/include"
saveenvvar LDFLAGS "-L$BUILDDIR_MINGW/host-libs/zlib/lib"
$SRCDIR/$BINUTILS/configure --build=$BUILD \
    --host=$HOST_MINGW \
    --target=$TARGET \
    --prefix=$INSTALLDIR_MINGW \
    --disable-nls \
    --with-sysroot=$INSTALLDIR_MINGW/arm-none-eabi \
    "--with-pkgversion=$PKGVERSION"

make -j$JOBS

make htmldir=$INSTALLDIR_MINGW/share/doc/html pdfdir=$INSTALLDIR_MINGW/share/doc/pdf infodir=$INSTALLDIR_MINGW/share/doc/info mandir=$INSTALLDIR_MINGW/share/doc/man install install-html install-pdf
restoreenv
popd

pushd $INSTALLDIR_MINGW
rm -rf lib/charset.alias
rm -rf ./lib/libiberty.a
rmdir ./lib
popd

echo Task [IV-2] /$HOST_MINGW/copy_libs/
copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/share/doc/html $INSTALLDIR_MINGW/share/doc/html
copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/share/doc/pdf $INSTALLDIR_MINGW/share/doc/pdf
#copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/share/doc/info $INSTALLDIR_MINGW/share/doc/info
#copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/share/doc/man $INSTALLDIR_MINGW/share/doc/man
copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/arm-none-eabi/lib $INSTALLDIR_MINGW/arm-none-eabi/lib
copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/arm-none-eabi/include $INSTALLDIR_MINGW/arm-none-eabi/include
copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/arm-none-eabi/include/c++ $INSTALLDIR_MINGW/arm-none-eabi/include/c++
copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/lib/gcc/arm-none-eabi $INSTALLDIR_MINGW/lib/gcc/arm-none-eabi

echo Task [IV-3] /$HOST_MINGW/gcc-final/
saveenv
saveenvvar AR_FOR_TARGET $TARGET-ar
saveenvvar NM_FOR_TARGET $TARGET-nm
saveenvvar OBJDUMP_FOR_TARET $TARGET-objdump
saveenvvar STRIP_FOR_TARGET $TARGET-strip
saveenvvar CC_FOR_TARGET $TARGET-gcc
saveenvvar GCC_FOR_TARGET $TARGET-gcc
saveenvvar CXX_FOR_TARGET $TARGET-g++
pushd $INSTALLDIR_MINGW/arm-none-eabi/
rm -f usr
ln -s . usr
popd
rm -rf $BUILDDIR_MINGW/gcc && mkdir -p $BUILDDIR_MINGW/gcc
pushd $BUILDDIR_MINGW/gcc
$SRCDIR/$GCC/configure --build=$BUILD --host=$HOST_MINGW --target=$TARGET \
    --prefix=$INSTALLDIR_MINGW \
    --enable-languages=c,c++ \
    --disable-decimal-float \
    --disable-libffi \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libstdcxx-pch \
    --disable-lto \
    --disable-nls \
    --disable-shared \
    --disable-threads \
    --disable-tls \
    --with-gnu-as \
    --with-gnu-ld \
    --with-headers=yes \
    --with-newlib \
    --with-sysroot=$INSTALLDIR_MINGW/arm-none-eabi \
    --with-libiconv-prefix=$BUILDDIR_MINGW/host-libs/usr \
    --with-gmp=$BUILDDIR_MINGW/host-libs/usr \
    --with-mpfr=$BUILDDIR_MINGW/host-libs/usr \
    --with-mpc=$BUILDDIR_MINGW/host-libs/usr \
    --with-ppl=$BUILDDIR_MINGW/host-libs/usr \
    --with-cloog=$BUILDDIR_MINGW/host-libs/usr \
    --with-libelf=$BUILDDIR_MINGW/host-libs/usr \
    "--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm" \
    "--with-pkgversion=$PKGVERSION" \
    --with-extra-multilibs=armv6-m,armv7-m,armv7e-m

make -j$JOBS all-gcc

make htmldir=$INSTALLDIR_MINGW/share/doc/html pdfdir=$INSTALLDIR_MINGW/share/doc/pdf infodir=$INSTALLDIR_MINGW/share/doc/info mandir=$INSTALLDIR_MINGW/share/doc/man install-gcc install-html-gcc install-pdf-gcc
popd

pushd $INSTALLDIR_MINGW
rm -rf bin/arm-none-eabi-gccbug
rmdir include
popd

copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/lib/gcc/arm-none-eabi $INSTALLDIR_MINGW/lib/gcc/arm-none-eabi
#copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/arm-none-eabi/lib $INSTALLDIR_MINGW/arm-none-eabi/lib
#copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_LINUX/arm-none-eabi/include/c++ $INSTALLDIR_MINGW/arm-none-eabi/include/c++
rm -rf $INSTALLDIR_MINGW/arm-none-eabi/usr
restoreenv

echo Task [IV-4] /$HOST_MINGW/gdb/
rm -rf $BUILDDIR_MINGW/gdb && mkdir -p $BUILDDIR_MINGW/gdb
pushd $BUILDDIR_MINGW/gdb
saveenv
saveenvvar CFLAGS "-I$BUILDDIR_MINGW/host-libs/zlib/include -O2"
saveenvvar CPPFLAGS "-I$BUILDDIR_MINGW/host-libs/zlib/include"
saveenvvar LDFLAGS "-L$BUILDDIR_MINGW/host-libs/zlib/lib"
$SRCDIR/$GDB/configure --build=$BUILD \
    --host=$HOST_MINGW \
    --target=$TARGET \
    --prefix=$INSTALLDIR_MINGW \
    --disable-nls \
    --disable-sim \
    --with-libexpat=$BUILDDIR_MINGW/host-libs/usr \
    --with-libiconv-prefix=$BUILDDIR_MINGW/host-libs/usr \
    --with-system-gdbinit=$INSTALLDIR_MINGW/$HOST_MINGW/arm-none-eabi/lib/gdbinit \
    '--with-gdb-datadir='\''${prefix}'\''/arm-none-eabi/share/gdb' \
    "--with-pkgversion=$PKGVERSION"

make -j$JOBS

make htmldir=$INSTALLDIR_MINGW/share/doc/html pdfdir=$INSTALLDIR_MINGW/share/doc/pdf infodir=$INSTALLDIR_MINGW/share/doc/info mandir=$INSTALLDIR_MINGW/share/doc/man install install-html install-pdf
restoreenv
popd

echo Task [IV-5] /$HOST_MINGW/pretidy/
pushd $INSTALLDIR_MINGW
rm -rf ./lib/libiberty.a
rm -rf $INSTALLDIR_MINGW/share/doc/info
rm -rf $INSTALLDIR_MINGW/share/doc/man

find $INSTALLDIR_MINGW -name '*.la' -exec rm '{}' ';'

echo Task [IV-6] /$HOST_MINGW/strip_host_objects/
STRIP_BINARIES=`find $INSTALLDIR_MINGW/bin/ -name arm-none-eabi-\*.exe`
for bin in $STRIP_BINARIES ; do
    strip_binary $HOST_MINGW_TOOL-strip $bin
done

STRIP_BINARIES=`find $INSTALLDIR_MINGW/arm-none-eabi/bin/ -maxdepth 1 -mindepth 1 -name \*.exe`
for bin in $STRIP_BINARIES ; do
    strip_binary $HOST_MINGW_TOOL-strip $bin
done

STRIP_BINARIES=`find $INSTALLDIR_MINGW/libexec/gcc/arm-none-eabi/$GCC_VER/ -name \*.exe`
for bin in $STRIP_BINARIES ; do
    strip_binary $HOST_MINGW_TOOL-strip $bin
done

echo Task [IV-7] /$HOST_MINGW/installation/
rm -f $PACKAGEDIR/$PACKAGE_NAME.exe
pushd $BUILDDIR_MINGW
rm -f $INSTALL_PACKAGE_NAME
cp $ROOT/$RELEASE_FILE $INSTALLDIR_MINGW/
cp $ROOT/$README_FILE $INSTALLDIR_MINGW/
cp $ROOT/$LICENSE_FILE $INSTALLDIR_MINGW/
dos2unix -u $INSTALLDIR_MINGW/$RELEASE_FILE
dos2unix -u $INSTALLDIR_MINGW/$README_FILE
dos2unix -u $INSTALLDIR_MINGW/$LICENSE_FILE
ln -s $INSTALLDIR_MINGW $INSTALL_PACKAGE_NAME
$SRCDIR/$INSTALLATION/build_win_pkg.sh --package=$INSTALL_PACKAGE_NAME --release_ver=$RELEASEVER --date=$RELEASEDATE
cp -rf $SRCDIR/$INSTALLATION/output/$PACKAGE_NAME.exe $PACKAGEDIR/
rm -f $INSTALL_PACKAGE_NAME
popd
restoreenv
fi #end of if [ "x$skip_mingw32" != "xyes" ] ;

echo Task [V-0] /package_sources/
pushd $PACKAGEDIR
rm -rf $PACKAGE_NAME && mkdir -p $PACKAGE_NAME/src
cp -f $SRCDIR/$CLOOG_PPL_PACK $PACKAGE_NAME/src/
cp -f $SRCDIR/$EXPAT_PACK $PACKAGE_NAME/src/
cp -f $SRCDIR/$GMP_PACK $PACKAGE_NAME/src/
cp -f $SRCDIR/$LIBELF_PACK $PACKAGE_NAME/src/
cp -f $SRCDIR/$LIBICONV_PACK $PACKAGE_NAME/src/
cp -f $SRCDIR/$MPC_PACK $PACKAGE_NAME/src/
cp -f $SRCDIR/$MPFR_PACK $PACKAGE_NAME/src/
cp -f $SRCDIR/$PPL_PACK $PACKAGE_NAME/src/
cp -f $SRCDIR/$ZLIB_PATCH $PACKAGE_NAME/src/
cp -f $SRCDIR/$ZLIB_PACK $PACKAGE_NAME/src/
copy_dir_clean $SRCDIR/$BINUTILS $PACKAGE_NAME/src/$BINUTILS
copy_dir_clean $SRCDIR/$GCC $PACKAGE_NAME/src/$GCC
copy_dir_clean $SRCDIR/$GDB $PACKAGE_NAME/src/$GDB
copy_dir_clean $SRCDIR/$NEWLIB $PACKAGE_NAME/src/$NEWLIB
if [ "x$skip_mingw32" != "xyes" ] ; then
    copy_dir_clean $SRCDIR/$INSTALLATION $PACKAGE_NAME/src/$INSTALLATION
fi
pushd $PACKAGE_NAME/src
tar cjf $BINUTILS.tar.bz2 $BINUTILS && rm -rf $BINUTILS
tar cjf $GCC.tar.bz2 $GCC && rm -rf $GCC
tar --exclude="gdb/testsuite/config/qemu.exp" --exclude="sim" -cjf $GDB.tar.bz2 $GDB && rm -rf $GDB
tar cjf $NEWLIB.tar.bz2 $NEWLIB && rm -rf $NEWLIB
if [ "x$skip_mingw32" != "xyes" ] ; then
    tar --exclude=build.log --exclude=output -cjf $INSTALLATION.tar.bz2 $INSTALLATION && rm -rf $INSTALLATION
fi
popd
cp $ROOT/$RELEASE_FILE $PACKAGE_NAME/
cp $ROOT/$README_FILE $PACKAGE_NAME/
cp $ROOT/$LICENSE_FILE $PACKAGE_NAME/
cp $ROOT/build-common.sh $PACKAGE_NAME/
cp $ROOT/build-prerequisites.sh $PACKAGE_NAME/
cp $ROOT/build-toolchain.sh $PACKAGE_NAME/
tar cjf $PACKAGE_NAME-src.tar.bz2 $PACKAGE_NAME
rm -rf $PACKAGE_NAME
popd

echo Task [V-1] /md5_checksum/
pushd $PACKAGEDIR
rm -rf md5.txt
md5sum -b $PACKAGE_NAME.tar.bz2     >>md5.txt
if [ "x$skip_mingw32" != "xyes" ] ; then
    md5sum -b $PACKAGE_NAME.exe         >>md5.txt
fi
md5sum -b $PACKAGE_NAME-src.tar.bz2 >>md5.txt
popd
