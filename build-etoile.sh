#!/bin/sh

LOG_NAME=etoile-build

# Languages compilation might break if -j flag is passed to GNUstep Make 
J=

# TODO: Support building tagged versions in Etoile SVN

#if [ "$ETOILE_VERSION" = "stable" ]; then
#	ETOILE_REP_PATH=stable
#elif [ "$ETOILE_VERSION" = "trunk" ]; then
#	ETOILE_REP_PATH=trunk/Etoile
#fi

if [ -n "$ETOILE_VERSION" ]; then

	LIBDISPATCH_SOURCE_DIR=$BUILD_DIR/libdispatch-objc2

	echo "Fetching libdispatch into $PWD"
	if [ ! -d $LIBDISPATCH_SOURCE_DIR ]; then
		git clone https://github.com/etoile/libdispatch-objc2.git $LIBDISPATCH_SOURCE_DIR
	else
		cd $LIBDISPATCH_SOURCE_DIR
		git pull
		cd ..	
	fi
	#${SVN_ACCESS}svn.gna.org/svn/etoile/trunk/Dependencies/libdispatch-objc2

	echo "Building & Installing libdispatch"
	cd $LIBDISPATCH_SOURCE_DIR/libdispatch
	rm -rf Build && mkdir Build
	cd Build
	if [ "$TEST_BUILD" = "yes" ]; then
		# Create 'include' and 'lib' directories inside the Build directory
		CMAKEOPTS='-DCMAKE_INSTALL_PREFIX=.' 
	fi
	($DUMP_ENV) && ( eval cmake -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_BUILD_TYPE=Release $CMAKEOPTS .. $LOG_RULE_TEMPLATE ) && ($MAKE_BUILD) && ($MAKE_INSTALL)
	STATUS=$?
	if [ "$TEST_BUILD" = "yes" ]; then
		# In case, libdispatch was not installed as a dependency previously (e.g. in /usr/local)
		# we create symbolic links just to support building Etoile immediately.
		ln -sf $PWD/lib/* $GNUSTEP_LOCAL_ROOT/Library/Libraries 
		ln -sf $PWD/include/* $GNUSTEP_LOCAL_ROOT/Library/Headers
	else
		# If libdispatch is installed in /usr/local, but /usr/local is not in the search paths, 
		# we create symbolic links to expose libdispatch to the Etoile build.
		ln -sf /usr/local/lib/libdispatch* $GNUSTEP_LOCAL_ROOT/Library/Libraries 
		ln -sf /usr/local/include/dispatch $GNUSTEP_LOCAL_ROOT/Library/Headers/dispatch
	fi
	# If libdispatch is installed in /usr/local, clang searches /usr/local/include/dispatch/ and 
	# not just /usr/local/include (not sure why). For other install locations, we have to declare
	# the header search path for CoreObject or projects that import CoreObject headers.
	export CPATH="$GNUSTEP_LOCAL_ROOT/Library/Headers/dispatch:$CPATH"
	fi
	cd ../../..

	if [ $STATUS -ne 0 ]; then exit 2; fi

	ETOILE_SOURCE_DIR=$BUILD_DIR/etoile-${ETOILE_VERSION}

	echo "Fetching Etoile into $PWD"
	if [ ! -d $ETOILE_SOURCE_DIR ]; then
		git clone https://github.com/etoile/Etoile.git $ETOILE_SOURCE_DIR
	else
		cd $ETOILE_SOURCE_DIR
		git pull
		cd ..
	fi 	
	#${SVN_ACCESS}svn.gna.org/svn/etoile/${ETOILE_REP_PATH} etoile-${ETOILE_VERSION}

	echo "Fetching Etoile Repositories"
	cd $ETOILE_SOURCE_DIR
	./etoile-fetch.sh

	echo "Building & Installing Etoile"
	($DUMP_ENV) && ($MAKE_CLEAN) && ($MAKE_BUILD) && ($MAKE_INSTALL)
	exit $?

else

	echo 
	echo "--> Finished... Warning: Etoile has not been built as requested!"
	echo
	exit # Don't report build failures if Etoile is not built

fi
