#!/bin/bash

#
# This script will install the R3BROOT package including
# the FAIRROOT dependency in the current directory
# 
# Author: Bastian L�her <b.loeher@gsi.de>
# Date: Thu Feb 12 11:46:18 CET 2015
#

set -e
set -u

r3broot_versions=('trunk' 'sep12' 'apr13' 'feb14')
fairsoft_versions=('jul15p2' 'jul14p3' 'jul14p3' 'jul14p3')
fairroot_versions=('v-15.07' 'v-14.11' 'v-14.11' 'v-14.11')

if [ $# -ne 1 ] ; then
  echo "Usage $0 <r3broot version>"
  echo "Available: ${r3broot_versions[*]}"
  exit
fi

r3broot_version=$1

function die { echo -e $1; exit; }
function join { local IFS="$1"; shift; echo "$*"; }

CWD=$(pwd)

# Check arguments
if [ $# -ne 1 ] ; then
	tmp=$(echo ${r3broot_versions[@]})
	die "Usage: $0 [$tmp]"
fi

# Do we have a suitable version?
ok=0
i=0
for v in ${r3broot_versions[@]} ; do
	if [ "$v" == "$r3broot_version" ] ; then
		ok=1
		break
	fi
	((i++))
done
if [ $ok -eq 0 ] ; then
	die "Not a supported version $r3broot_version"
fi
fairsoft_version=${fairsoft_versions[i]}
echo "Selected corresponding fairsoft version $fairsoft_version"
fairroot_version=${fairroot_versions[i]}
echo "Selected corresponding fairroot version $fairroot_version"

# Check, if we have access to cvmfs
if [ -d "/cvmfs" ] ; then
  HAS_CVMFS=1
else
  HAS_CVMFS=0
fi

# Set up cvmfs paths
if [ "$r3broot_version" != "trunk" ] ; then
  CVMFS_FAIRSOFT=/cvmfs/fairroot.gsi.de/fairsoft/$fairsoft_version
  CVMFS_FAIRROOT=/cvmfs/fairroot.gsi.de/fairroot/${fairroot_version}_fairsoft-$fairsoft_version
else
  CVMFS_FAIRSOFT=/cvmfs/fairroot.gsi.de/gcc_4.8.4/fairsoft/$fairsoft_version
  CVMFS_FAIRROOT=/cvmfs/fairroot.gsi.de/gcc_4.8.4/fairroot/${fairroot_version}_fairsoft-$fairsoft_version
fi

# Check what we need to compile
NEED_FAIRSOFT=0
NEED_FAIRROOT=0
if [ "$HAS_CVMFS" -eq "0" ] ; then
  NEED_FAIRSOFT=1
  NEED_FAIRROOT=1
  export FAIRSOFT_PATH=$CVMFS_FAIRSOFT
  export FAIRROOT_PATH=$CVMFS_FAIRROOT
else
  if [ ! -d $CVMFS_FAIRSOFT ] ; then
    NEED_FAIRSOFT=1
  fi
  if [ ! -d $CVMFS_FAIRROOT ] ; then
    NEED_FAIRROOT=1
  fi
fi

# Export SIMPATH
export SIMPATH=/cvmfs/fairroot.gsi.de/fairsoft/$fairsoft_version

# ------------------------------------------------------------------

if [ "$NEED_FAIRSOFT" -eq "1" ] ; then
# Install FAIRSOFT
echo "Installing FAIRSOFT"

# Make the source directory
ok="y"
srcdir=fairsoft
echo "Sources are placed in a directory '$srcdir/$fairsoft_version' inside the current dir."
echo -n "OK? [Y/n]"
read ok
if [ "$ok" != "y" ] && [ ! -z $ok ] ; then
	die "Aborting..."
fi

mkdir -p $srcdir
cd $CWD/$srcdir

# Get the source
gitpath=https://github.com/FairRootGroup/FairSoft
if [ -d "$fairsoft_version" ] ; then
	echo "Source dir $fairsoft_version already exists."
else
	echo -n "FAIRSOFT This will take a few minutes..."
	git clone -q -b "$fairsoft_version" $gitpath $fairsoft_version \
		|| die "FAILED\nCould not checkout the sources from github"
	echo "DONE"
fi
cd $CWD/$srcdir/$fairsoft_version
git checkout tags/$fairsoft_version || die "Could not checkout tag"

# Build
installdir=$CWD/fairsoft_install/$fairsoft_version
echo "FAIRSOFT Creating install directory $CWD/$installdir"
cd $CWD
mkdir -p $installdir
cd $CWD/$srcdir/$fairsoft_version

FAIRSOFT_OPTIONS="compiler=gcc
debug=yes
optimize=no
geant4_download_install_data_automatic=yes
geant4_install_data_from_dir=no
build_python=no
install_sim=yes
build_root6=no
SIMPATH_INSTALL=$installdir"

echo "Fairsoft Options:"
echo ${FAIRSOFT_OPTIONS[*]}
echo $FAIRSOFT_OPTIONS | tr ' ' '\n' > configure.in

echo "FAIRSOFT Running configure..."
./configure.sh configure.in

cd $CWD
echo "FAIRROOT Finished"

# Export SIMPATH
export FAIRSOFT_PATH=$installdir

else # NEED_FAIRSOFT

export FAIRSOFT_PATH=$CVMFS_FAIRSOFT

fi # NEED_FAIRSOFT

export SIMPATH=$FAIRSOFT_PATH

# ------------------------------------------------------------------

if [ "$NEED_FAIRROOT" -eq "1" ] ; then
# Install FAIRROOT
echo "Installing FAIRROOT"

# Make the source directory
ok="y"
srcdir=fairroot
echo "Sources are placed in a directory '$srcdir/$fairroot_version' inside the current dir."
echo -n "OK? [Y/n]"
read ok
if [ "$ok" != "y" ] && [ ! -z $ok ] ; then
	die "Aborting..."
fi

mkdir -p $srcdir
cd $CWD/$srcdir

# Get the source
gitpath=http://github.com/FairRootGroup/FairRoot.git
if [ -d "$fairroot_version" ] ; then
	echo "Source dir $fairroot_version already exists."
else
	echo -n "FAIRROOT This will take a few minutes..."
	git clone -q -b "$fairroot_version" $gitpath $fairroot_version \
		|| die "FAILED\nCould not checkout the sources from github"
	echo "DONE"
fi
cd $CWD/$srcdir/$fairroot_version
git checkout tags/$fairroot_version || die "Could not checkout tag"
cd $CWD/$srcdir

# Build
builddir=$CWD/fairroot_build/$fairroot_version
installdir=$CWD/fairroot_install/$fairroot_version
echo "FAIRROOT Creating build directory $CWD/$builddir"

cd $CWD
mkdir -p $builddir
cd $builddir

echo "FAIRROOT Running cmake..."
cmake -DCMAKE_INSTALL_PREFIX="$installdir" $CWD/$srcdir/$fairroot_version \
	|| die "cmake FAILED"

echo "FAIRROOT Running make"
make -j$(nproc) || die "make FAILED"

# Install
mkdir -p $installdir
echo "FAIRROOT Installing to $installdir"
make install || die "make install FAILED"

cd $CWD
echo "FAIRROOT Finished"

# Export FAIRROOTPATH

export FAIRROOT_PATH=$installdir

else # NEED_FAIRROOT

export FAIRROOT_PATH=$CVMFS_FAIRROOT

fi # NEED_FAIRROOT

export FAIRROOTPATH=$FAIRROOT_PATH

# ------------------------------------------------------------------

# Install R3BROOT

echo "Installing R3BROOT"

# Make the source directory
ok="y"
srcdir=r3broot
echo "Sources are placed in a directory '$srcdir/$r3broot_version' inside the current dir."
echo -n "OK? [Y/n]"
read ok
if [ "$ok" != "y" ] && [ ! -z $ok ] ; then
	die "Aborting..."
fi

mkdir -p $srcdir

CWD=$(pwd)
cd $srcdir

# Get the source
echo -n "R3BROOT This will take a few minutes..."
svnpath=https://subversion.gsi.de/fairroot/r3broot
if [ "$r3broot_version" != "trunk" ] ; then
	svnpath=$svnpath/release
fi
svn co -q $svnpath/$r3broot_version $r3broot_version \
	|| die "FAILED\nCould not checkout the sources from SVN"
echo "DONE"

# Build
builddir=r3broot_build/$r3broot_version
echo "R3BROOT Creating build directory $CWD/$builddir"

cd $CWD
mkdir -p $builddir
cd $builddir

echo "R3BROOT Running cmake..."
cmake $CWD/$srcdir/$r3broot_version || die "cmake FAILED"

echo "R3BROOT Running make"
make -j || die "make FAILED"

export R3BROOT_BUILD_DIR=$builddir
export R3BROOT_SOURCE_DIR=$CWD/$srcdir/$r3broot_version

cd $CWD
echo "R3BROOT Finished"

echo -e "\n\n"
echo "###############################################"
echo "#  Building finished successfully"
echo "#  "
echo "#  Add the following lines to your ~/.profile"
echo "\\  -------------------------------------------/"
echo ""
echo "# BEGIN setup R3BROOT"
echo "export FAIRROOTPATH=$FAIRROOTPATH"
echo "export SIMPATH=$SIMPATH"
echo "export R3BROOT_BUILD_DIR=$R3BROOT_BUILD_DIR"
echo "export R3BROOT_SOURCE_DIR=$R3BROOT_SOURCE_DIR"
echo "source $R3BROOT_BUILD_DIR/config.sh"
echo "# END setup R3BROOT"
echo ""
echo "/  -------------------------------------------\\"
echo "###############################################"
echo -e "\n\n"
echo "For testing, you can now run"
echo "cd $builddir/macros/r3b ; ./r3bsim.sh"
echo -e "\n\n"
