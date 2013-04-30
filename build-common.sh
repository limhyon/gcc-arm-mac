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

error () {
    set +u
    echo "$0: error: $@" >&2
    exit 1
    set -u
}

warning () {
    set +u
    echo "$0: warning: $@" >&2
    set -u
}

copy_dir() {
    set +u
    mkdir -p "$2"

    (cd "$1" && tar cf - .) | (cd "$2" && tar xf -)
    set -u
}

copy_dir_clean() {
    set +u
    mkdir -p "$2"
    (cd "$1" && tar cf - \
	--exclude=CVS --exclude=.svn --exclude=.git --exclude=.pc \
	--exclude="*~" --exclude=".#*" \
	--exclude="*.orig" --exclude="*.rej" \
	.) | (cd "$2" && tar xf -)
    set -u
}

# Clean all global shell variables except for those needed by build scripts
clean_env () {
    set +u
    local var_list
    local var
    var_list=`export|grep "^declare -x"|sed -e "s/declare -x //"|cut -d"=" -f1`
    
    for var in $var_list ; do
        case $var in
            DEJAGNU|\
            DISPLAY|\
            HOME|\
            LD_LIBRARY_PATH|\
            LOGNAME|\
            PATH|\
            PWD|\
            SHELL|\
            SHLVL|\
            TERM|\
            USER|\
            USERNAME|\
            XAUTHORITY)
            ;;
        *)
            unset $var
            ;;
        esac
    done

    export LANG=C
    set -u
}

stack_level=0

# Start a new stack level to save variables
# Must call this before saving any variables
saveenv () {
    set +u
    # Force expr return 0 to avoid script fail
    stack_level=`expr $stack_level \+ 1 || true`
    eval stack_list_$stack_level=
    set -u
}

# Save a variable to current stack level, and set new value to this var.
# If a variable has been saved, won't save it. Just set new value
# Must be called when stack_level > 0
# $1: variable name
# $2: new variable value
saveenvvar () {
    set +u
    if [ $stack_level -le 0 ]; then
        error Must call saveenv before calling saveenvvar
    fi
    local varname="$1"
    local newval="$2"
    eval local oldval=\"\${$varname}\"
    eval local saved=\"\${level_saved_${stack_level}_${varname}}\"
    if [ "x$saved" = "x" ]; then
        # The variable wasn't saved in the level before. Save it
        eval local temp=\"\${stack_list_$stack_level}\"
        eval stack_list_$stack_level=\"$varname $temp\"
        eval save_level_${stack_level}_$varname=\"$oldval\"
        eval level_saved_${stack_level}_$varname="yes"
        eval level_preset_${stack_level}_${varname}=\"\${$varname+set}\"
        #echo Save $varname: \"$oldval\"
    fi
    eval export $varname=\"$newval\"
    #echo $varname set to \"$newval\"
    set -u
}

# Restore all variables that have been saved in current stack level
restoreenv () {
    set +u
    if [ $stack_level -le 0 ]; then
        error "Trying to restore from an empty stack"
    fi

    eval local list=\"\${stack_list_$stack_level}\"
    local varname
    for varname in $list; do
        eval local varname_preset=\"\${level_preset_${stack_level}_${varname}}\"
        if [ "x$varname_preset" = "xset" ] ; then
            eval $varname=\"\${save_level_${stack_level}_$varname}\"
        else
            unset $varname
        fi
        eval level_saved_${stack_level}_$varname=
        # eval echo $varname restore to \\\"\"\${$varname}\"\\\"
    done
    # Force expr return 0 to avoid script fail
    stack_level=`expr $stack_level \- 1 || true`
    set -u
}

prependenvvar() {
    set +u
    eval local oldval=\"\$$1\"
    saveenvvar "$1" "$2$oldval"
    set -u
}

prepend_path() {
    set +u
    eval local old_path="\"\$$1\""
    if [ x"$old_path" == "x" ]; then
        prependenvvar "$1" "$2"
    else
        prependenvvar "$1" "$2:"
    fi
    set -u
}

# Strip binary files as in "strip binary" form, for both linux and mingw.
strip_binary() {
    set +e
    if [ $# -ne 2 ] ; then
        warning "strip_binary: Missing arguments"
        return 0
    fi
    local strip="$1"
    local bin="$2"

    file $bin | grep -q -P "(\bELF\b)|(\bPE\b)|(\bPE32\b)"
    if [ $? -eq 0 ]; then
        $strip $bin 2>/dev/null || true
    fi

    set -e
}

# Clean up unnecessary global shell variables
clean_env

ROOT=`pwd`
SRCDIR=$ROOT/src

BUILDDIR_LINUX=$ROOT/build-linux
BUILDDIR_MINGW=$ROOT/build-mingw
INSTALLDIR_LINUX=$ROOT/install-linux
INSTALLDIR_MINGW=$ROOT/install-mingw

PACKAGEDIR=$ROOT/pkg

BINUTILS=binutils
CLOOG_PPL=cloog-ppl-0.15.11
EXPAT=expat-2.0.1
GCC=gcc
GDB=gdb
GMP=gmp-4.3.2
LIBELF=libelf-0.8.13
LIBICONV=libiconv-1.11.1
MPC=mpc-0.8.1
MPFR=mpfr-2.4.2
NEWLIB=newlib
PPL=ppl-0.11
ZLIB=zlib-1.2.5
INSTALLATION=installation

CLOOG_PPL_PACK=$CLOOG_PPL.tar.gz
EXPAT_PACK=$EXPAT.tar.gz
GMP_PACK=$GMP.tar.bz2
LIBELF_PACK=$LIBELF.tar.gz
LIBICONV_PACK=$LIBICONV.tar.gz
MPC_PACK=$MPC.tar.gz
MPFR_PACK=$MPFR.tar.bz2
PPL_PACK=$PPL.tar.gz
ZLIB_PACK=$ZLIB.tar.bz2

ZLIB_PATCH=$ZLIB.patch

RELEASEDATE=`date +%Y%m%d`
release_year=${RELEASEDATE:0:4}
release_month=${RELEASEDATE:4:2}
case $release_month in
    01|02|03)
        RELEASEVER=${release_year}q1
        ;;
    04|05|06)
        RELEASEVER=${release_year}q2
        ;;
    07|08|09)
        RELEASEVER=${release_year}q3
        ;;
    10|11|12)
        RELEASEVER=${release_year}q4
        ;;
esac

RELEASE_FILE=release.txt
README_FILE=readme.txt
LICENSE_FILE=license.txt
GCC_VER=`cat $SRCDIR/$GCC/gcc/BASE-VER`
GCC_VER_NAME=`echo $GCC_VER | cut -d'.' -f1,2 | sed -e 's/\./_/g'`
JOBS=`grep ^processor /proc/cpuinfo|wc -l`

BUILD=i686-linux-gnu
HOST_LINUX=i686-linux-gnu
HOST_MINGW=i586-mingw32
HOST_MINGW_TOOL=i586-mingw32msvc
TARGET=arm-none-eabi

PKGVERSION="GNU Tools for ARM Embedded Processors"
BUGURL=""

OBJ_SUFFIX_MINGW=$TARGET-$RELEASEDATE-$HOST_MINGW
OBJ_SUFFIX_LINUX=$TARGET-$RELEASEDATE-$HOST_LINUX
PACKAGE_NAME=gcc-$TARGET-$GCC_VER_NAME-$RELEASEVER-$RELEASEDATE
INSTALL_PACKAGE_NAME=gcc-$TARGET-$GCC_VER_NAME-$RELEASEVER

