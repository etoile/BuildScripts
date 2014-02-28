#!/bin/sh

#
# This script is designed to be sourced in build.sh
#

# llvm-configure-basic.sh uses CONFIGURE variable that depends on LOG_RULE_TEMPLATE (see testbuild.profile)
export LOG_NAME=llvm-build

export LLVM_SOURCE_DIR=$BUILD_DIR/llvm-$LLVM_VERSION
if [ -n "$LLVM_INSTALL_DIR" ]; then
	LLVM_MAKE_INSTALL=$MAKE_INSTALL
	LLVM_PREFIX_DIR="--prefix-dir=$LLVM_INSTALL_DIR"
else
	LLVM_MAKE_INSTALL=
	# If we pass --prefix-dir=$LLVM_SOURCE_DIR/$LLVM_BUILD_OUTPUT, then 
	# Makes.rules in LLVM breaks because it sees a conflict between the 
	# built products location and the install destination. So we must be 
	# sure the LLVM configure uses the default prefix (/usr/local) if we
	# plan no installation.
	LLVM_PREFIX_DIR=
	# If there is no install dir, LLVM_INSTALL_DIR is set to the build output
	# directories... bin and lib inside LLVM_SOURCE_DIR
	LLVM_INSTALL_DIR=$LLVM_SOURCE_DIR/$LLVM_BUILD_OUTPUT
fi

# LLVM git mirror
LLVM_URL_GIT=http://llvm.org/git/llvm.git
# Clang git mirror
CLANG_URL_GIT=http://llvm.org/git/clang.git


if [ "$LLVM_VERSION" = "packaged" ]; then

	echo "Using packaged version of LLVM/clang"

	# FIXME: Support LLVM 3.4 packages and higher.
	HAVE_CLANG_3_3=$(dpkg -s clang-3.3 | grep "install ok installed")

	if [ -z "$HAVE_CLANG_3_3" ]; then

		echo "Warning: LLVM/clang 3.3 package is not installed (more recent packages are not supported yet)"
		export STATUS=1

	else

		# Workaround for:
		# https://bugs.launchpad.net/ubuntu/+source/llvm-3.1/+bug/991493
		if [ ! -f /usr/bin/llvm-config ]; then
			echo "Symlinking /usr/bin/llvm-config to /usr/bin/llvm-config-3.3"
			sudo ln -s /usr/bin/llvm-config-3.3 /usr/bin/llvm-config
		fi

		export STATUS=0
	fi

elif [ "$LLVM_VERSION" = "trunk" ]; then

	if [ "$LLVM_ACCESS" = "svn" ]; then

		echo "Fetching LLVM and Clang $LLVM_VERSION using SVN"
		${LLVM_SVN_ACCESS}llvm.org/svn/llvm-project/llvm/${LLVM_VERSION} $LLVM_SOURCE_DIR
		${LLVM_SVN_ACCESS}llvm.org/svn/llvm-project/cfe/${LLVM_VERSION} $LLVM_SOURCE_DIR/tools/clang 
		
	elif [ "$LLVM_ACCESS" = "git" ]; then

		if [ ! -d $LLVM_SOURCE_DIR ]; then
			echo "Fetching LLVM trunk using a GIT mirror at $LLVM_URL_GIT"
			git clone $LLVM_URL_GIT $LLVM_SOURCE_DIR
		else
			echo "Updating LLVM trunk using a GIT mirror at $LLVM_URL_GIT"
			git pull $LLVM_SOURCE_DIR
		fi
	fi

elif [ -n "$LLVM_VERSION" -a ! -d $LLVM_SOURCE_DIR ]; then

	echo "Fetching LLVM $LLVM_VERSION from LLVM release server"
	wget -nc http://llvm.org/releases/${LLVM_VERSION}/llvm-${LLVM_VERSION}.src.tar.gz
	tar -xzf llvm-${LLVM_VERSION}.src.tar.gz 
	mv llvm-${LLVM_VERSION}.src llvm-${LLVM_VERSION}
	echo "Fetching Clang $LLVM_VERSION from LLVM release server"
	wget -nc  http://llvm.org/releases/${LLVM_VERSION}/cfe-${LLVM_VERSION}.src.tar.gz
	tar -xzf cfe-${LLVM_VERSION}.src.tar.gz
	mv cfe-${LLVM_VERSION}.src llvm-${LLVM_VERSION}/tools/clang

elif [ -z "$LLVM_VERSION" ]; then

	HAVE_CLANG_3_3_OR_HIGHER=$(clang -v 2>&1 | grep "clang version 3.[3-9]")

	if [ -z "$HAVE_CLANG_3_3_OR_HIGHER" ]; then
		echo "Warning: LLVM/clang 3.3 or higher is not installed (older versions are not supported)"
		export STATUS=1
	else
		export STATUS=0
	fi
fi

echo

if [ -n "$LLVM_VERSION" -a "$LLVM_VERSION" != "packaged" -a -n "$LLVM_VERSION" ]; then

	echo "Building and Installing LLVM and Clang"
	echo

	# If LLVM has been successfully configured once, the codebase is not recompiled 
	# from scratch on every build unless --force-llvm-configure option is passed to build.sh
	LLVM_CONFIG_SUCCESS_FILE="$LLVM_SOURCE_DIR/config.success"

	if [ -f $LLVM_CONFIG_SUCCESS_FILE  -a "$FORCE_LLVM_CONFIGURE" != "yes" ]; then
		LLVM_CONFIGURE_ONCE=
	else
		LLVM_CONFIGURE_ONCE="eval $SCRIPT_DIR/$LLVM_CONFIGURE && touch $LLVM_CONFIG_SUCCESS_FILE"
	fi

	cd $LLVM_SOURCE_DIR
	($DUMP_ENV) && ($LLVM_CONFIGURE_ONCE) && ($MAKE_BUILD) && ($LLVM_MAKE_INSTALL)
	export STATUS=$?
	cd ..
	
fi

if [ $STATUS -eq 0 ]; then 

	rm -f $LLVM_ENV_FILE

	# Put LLVM in the path (it must come first to take over any prior LLVM install)
	if [ "$LLVM_VERSION" = "packaged" ]; then

		( echo "export PATH=/usr/bin:\$PATH"
		  echo "export LD_LIBRARY_PATH=/usr/lib:\$LD_LIBRARY_PATH"
		  echo "export CC=clang"
		  echo "export CXX=clang++" ) > $LLVM_ENV_FILE

	elif [ -n "$LLVM_VERSION" ]; then

		( echo "export PATH=$LLVM_INSTALL_DIR/bin:\$PATH"
		  echo "export LD_LIBRARY_PATH=$LLVM_INSTALL_DIR/lib:\$LD_LIBRARY_PATH"
		  echo "export CC=clang"
		  echo "export CXX=clang++" ) > $LLVM_ENV_FILE
	else

		( echo "export CC=clang"
		  echo "export CXX=clang++" ) > $LLVM_ENV_FILE

	fi

fi
