#!/bin/sh

# Determine script path and directory

cd `dirname "$0"`
export SCRIPT_DIR=`pwd -L`
cd - 

PROFILE_SCRIPT=$PWD/build.config

# Process script options second (so they can override build profile)

while test $# != 0
do
  option=
  case $1 in
    --help | -h)
      echo
      echo "`basename $0` - Script to build, test and install the Etoile environment "
      echo
      echo "Note: this script appends a new line to ~/.bashrc for --update-bash-rc=yes"
      echo
      echo "Requirements: "
      echo
      echo "  wget, GNU make, gcc or clang, and sudo access (for installing dependencies)"
      echo
      echo "Actions:"
      echo
      echo "  --help                   - Print help"
      echo
      echo "Options:"
      echo "Type --option-name=value to set an option and quote the value when it contains "
      echo "spaces."
      echo
      echo "  --profile               - Path to the build profile that describes the build "
      echo "                            process (default: \$PWD/build.config)"
      echo "  --build-dir             - Name of the directory inside which the build will "
      echo "                            happen (default: \$PWD/build)"
      echo "  --prefix                - Path where GNUstep and Etoile will be installed"
      echo "                            (default:  same as --build-dir)"
      echo "  --version               - Version of the Etoile environment to check out and "
      echo "                            and build, either 'stable' or 'trunk'. The related "
      echo "                            repository code will be checked out in "
      echo "                            $build-dir/Etoile"
      echo "                            (default: trunk)"
      echo "  --test-build            - Boolean value, either 'yes' or 'no', to enable or "    
      echo "                            disable both mail reporting and test suites."
      echo "                            (default: no)"
      echo "  --force-llvm-configure  - Boolean value, either 'yes' or 'no', to indicate if "
      echo "                            configure should be run every time LLVM is built. "
      echo "                            (default: no)"
      echo "  --skip-llvm-build       - Boolean value, either 'yes' or 'no', to indicate if "
      echo "                            LLVM should be built. If 'no' is passed, LLVM must "
      echo "                            have been built before for the same LLVM version "
      echo "                            and in the same build directory."
      echo "                            (default: no)"
      echo "  --skip-gnustep-build    - Boolean value, either 'yes' or 'no', to indicate if "
      echo "                            GNUstep should be built. If 'no' is passed, GNUstep "
      echo "                            must have been built before for the same GNUstep "
      echo "                            versions and in the same build directory."
      echo "                            (default: no)"
      echo "  --update-bash-rc        - Boolean value, either 'yes' or 'no', to indicate if "
      echo "                            the ~/.bashrc file should be updated to include the "
      echo "                            environment variables required for GNUstep and "
      echo "                            development. If --test-build is yes, this option is "
      echo "                            ignored."
      echo "                            (default: no)"


      echo
      exit 0
      ;;
    --*=*)
      option=`expr "x$1" : 'x\([^=]*\)='`
      optionarg=`expr "x$1" : 'x[^=]*=\(.*\)'`
      ;;
    *)
      ;;
  esac

  case $option in
    --profile)
      PROFILE_SCRIPT_override=$optionarg;; 
    --build-dir)
      BUILD_DIR_override=$optionarg;;
    --prefix)
      PREFIX_DIR_override=$optionarg;; 
    --version)
      ETOILE_VERSION_override=$optionarg;;
    --test-build)
      TEST_BUILD=$optionarg;; 
    --force-llvm-configure)
      FORCE_LLVM_CONFIGURE=$optionarg;;
    --skip-llvm-build)
      SKIP_LLVM_BUILD=$optionarg;;
    --skip-gnustep-build)
      SKIP_GNUSTEP_BUILD=$optionarg;;
    --update-bash-rc)
      UPDATE_BASHRC=$optionarg;;
    *)
      echo "Warning: Unknow option $option"
      exit 1;;
  esac
  shift
done

# Define variables if not defined on command line or in build profile

PROFILE_SCRIPT=${PROFILE_SCRIPT:-"$PWD/build.config"}
PROFILE_SCRIPT=${PROFILE_SCRIPT_override:-"$PROFILE_SCRIPT"}
# Turn relative path into absolute path
PROFILE_SCRIPT=`( cd \`dirname $PROFILE_SCRIPT\` && pwd )`/`basename ${PROFILE_SCRIPT}`

if [ ! -f $PROFILE_SCRIPT ]; then
	echo "Warning: Found no profile script for $PROFILE_SCRIPT"
	exit 1
fi
. $PROFILE_SCRIPT

BUILD_DIR=${BUILD_DIR:-"$PWD/build"}
BUILD_DIR=${BUILD_DIR_override:-"$BUILD_DIR"}
# Turn relative path into absolute path
BUILD_DIR=`( cd \`dirname $BUILD_DIR\` && pwd )`/`basename ${BUILD_DIR}`

PREFIX_DIR=${PREFIX_DIR:-"$BUILD_DIR"}
PREFIX_DIR=${PREFIX_DIR_override:-"$PREFIX_DIR"}
# Turn relative path into absolute path
PREFIX_DIR=`( cd \`dirname $PREFIX_DIR\` && pwd )`/`basename ${PREFIX_DIR}`

ETOILE_VERSION=${ETOILE_VERSION_override:-"$ETOILE_VERSION"}

# Interpret some variables that depend on BUILD_DIR or PREFIX_DIR

LOG_BASE_DIR=`eval echo $LOG_BASE_DIR`
LOG_DIR=`eval echo $LOG_DIR`

# Create a build directory if none exists

if [ ! -d "$BUILD_DIR" ]; then
	mkdir $BUILD_DIR
else
	FOUND_EXISTING_BUILD_DIR="yes"	
fi

# Redirect standard output and error to console and log file

export LOG_SUMMARY_FILE=$BUILD_DIR/build.log

rm -f $LOG_SUMMARY_FILE

out="${TMPDIR:-/tmp}/out.$$"
mkfifo "$out"
trap 'rm "$out" ' EXIT
tee $LOG_SUMMARY_FILE < "$out" >&1 &
exec >> "$out" 2>> "$out"

#
# Another solution based on two fifos, but doesn't work so well, 
# because buffering then messes up the console ouput ordering.
#
#out="${TMPDIR:-/tmp}/out.$$" err="${TMPDIR:-/tmp}/err.$$"
#mkfifo "$out" "$err"
#trap 'rm "$out" "$err"' EXIT
#tee $LOG_SUMMARY_FILE < "$out" >&1 &
#tee $LOG_SUMMARY_FILE < "$err" >&2 &
#exec >> "$out" 2>> "$err"

# For testing the ordering of the console output 
#echo "bla"
#cd $LOG_SUMMARY_FILE

# Disable dependency install if there is no sudo access

if [ -z "$SUDO" ]; then
	DEPENDENCY_SCRIPT=
fi

# Reset the environment in case a GNUstep intallation is in use

GNUSTEP_CONFIG_TOOL_PATH=`which gnustep-config`
# 'Tools' (GNUstep layout) or 'bin' (FHS layout)
GNUSTEP_BIN_PREFIX=`basename \`dirname $GNUSTEP_CONFIG_TOOL_PATH\``

# If FHS layout is in use, don't run GNUstep-reset.sh otherwise $PATH would be mess up
if [ -n "$GNUSTEP_MAKEFILES" -a "$GNUSTEP_BIN_PREFIX" != "bin" ]; then
	
	# Patch bashism in GNUstep-reset.sh
	cp $GNUSTEP_MAKEFILES/GNUstep-reset.sh $BUILD_DIR/GNUstep-reset.sh
	sed -i -e 's/function reset_path/reset_path\(\)/' $BUILD_DIR/GNUstep-reset.sh

	. $BUILD_DIR/GNUstep-reset.sh
	unset GNUSTEP_CONFIG_FILE

	rm $BUILD_DIR/GNUstep-reset.sh
fi

# For debugging

echo
echo "Main Build Variables"
echo
echo "PROFILE_SCRIPT = $PROFILE_SCRIPT"
echo "BUILD_DIR = $BUILD_DIR"
echo "LOG_DIR = $LOG_DIR"
echo "PREFIX_DIR = $PREFIX_DIR"
echo "LLVM_VERSION = $LLVM_VERSION"
echo "ETOILE_VERSION = $ETOILE_VERSION"
echo

# Export some new or updated variables for subscripts

export BUILD_DIR
export PREFIX_DIR
export TEST_BUILD
export FORCE_LLVM_CONFIGURE

# Declare some initial values for local variables

STATUS=0
FAILED_MODULE=

# Report if an existing build directory was found 
#
# (we want to see this ouput in the build log summary, that's why we don't 
# report the existence test result immediately above)

if [ "$FOUND_EXISTING_BUILD_DIR" = "yes" ]; then
	echo "---> Found existing build directory"
	echo
fi

cd $BUILD_DIR

# Create the log directory and subdirectory for the new build

if [ ! -d $LOG_BASE_DIR ]; then
	mkdir $LOG_BASE_DIR
fi

mkdir $LOG_DIR

#
# Install Etoile and GNUstep dependencies 
#

if [ -n "$DEPENDENCY_SCRIPT" ]; then
	echo "---> Installing GNUstep and Etoile dependencies if needed"
	$SCRIPT_DIR/$DEPENDENCY_SCRIPT
	echo
fi

#
# Download, build and install LLVM
#

LLVM_ENV_FILE=$BUILD_DIR/llvm-${LLVM_VERSION}.sh

if [ $STATUS -eq 0 -a "$SKIP_LLVM_BUILD" != "yes" ]; then
	echo "---> Building LLVM/Clang"
	echo

	# The LLVM build script is sourced (unlike the other build scripts) to let it 
	# update both PATH and LD_LIBRARY_PATH.
	# The build status is exported in the script itself.
	. $SCRIPT_DIR/build-llvm.sh

	if [ $STATUS -ne 0 ]; then 
		FAILED_MODULE="LLVM" 
	fi
fi

# Source LLVM_ENV_FILE emitted in build-llvm.sh in order to get the right 
# environment variables set to use the last built LLVM (this means we can skip 
# the LLVM build above e.g. for debugging)
. $LLVM_ENV_FILE
CLANG_SUMMARY=`clang -v 2<&1 | head -n 1`
echo " == Switched to $CLANG_SUMMARY == " 
echo

#
# Download, build and Install GNUstep
#

if [ $STATUS -eq 0 -a "$SKIP_GNUSTEP_BUILD" != "yes" ]; then
	echo "---> Building GNUstep core libraries"
	echo

	$SCRIPT_DIR/build-gnustep.sh
	STATUS=$?

	case "$STATUS" in
		1) FAILED_MODULE="GNUstep Make";;
		2) FAILED_MODULE="GNUstep libobjc2";;
		3) FAILED_MODULE="GNUstep Make (second pass)";;
		4) FAILED_MODULE="GNUstep Base";;
		5) FAILED_MODULE="GNUstep Gui";;
		6) FAILED_MODULE="GNUstep Back";;
		7) FAILED_MODULE="GNUstep Gorm";;
	esac
fi

# Source GNUstep.sh to support building Etoile since build-gnustep.sh is not sourced

echo "Sourcing GNUstep.sh (for Etoile)"
export GNUSTEP_CONFIG_FILE=${PREFIX_DIR%/}/etc/GNUstep/GNUstep.conf
. ${PREFIX_DIR%/}/System/Library/Makefiles/GNUstep.sh
echo

#
# Download, build and install Etoile
#

if [ $STATUS -eq 0 ]; then
	echo "---> Building Etoile"
	echo
	
	$SCRIPT_DIR/build-etoile.sh
	STATUS=$?

	# TODO: Report failed module more precisely... e.g. LanguageKit, EtoileUI
	if [ $STATUS -ne 0 ]; then 
		FAILED_MODULE="Etoile" 
	fi
fi

#
# Send email to report build failures (or report success in the shell)
#

# On a build failure, we compare the content of the last error logs between on 
# the current build and the previous one. If the contents doesn't match, we 
# report the build failure by mail, otherwise we don't since the build failure 
# is the same than previously.
LAST_ERROR_LOG_FILE=$LOG_BASE_DIR/last-error-`basename $PROFILE_SCRIPT`.log
LAST_CHANGED_LOG_SUBDIR=$LOG_BASE_DIR/`ls -At $LOG_BASE_DIR 2> /dev/null | head -n 1`
LAST_CHANGED_LOG_FILE=$LAST_CHANGED_LOG_SUBDIR/`ls -At $LAST_CHANGED_LOG_SUBDIR/*error.log 2> /dev/null | head -n 1 | xargs basename`

if [ $STATUS -ne 0 -a -f $LAST_CHANGED_LOG_FILE ]; then
	if [ -f $LAST_ERROR_LOG_FILE ]; then

		# We limit our diff to the last few lines because Clang warnings
		# that follow an error don't have a stable ordering accross invocations.
		#
		# Note: If we use Bash, temporary named pipes would avoid the temporary file

		tail -n 10 $LAST_ERROR_LOG_FILE > ${LAST_ERROR_LOG_FILE}.tail
		BUILD_DELTA=`tail -n 10 $LAST_CHANGED_LOG_FILE | diff ${LAST_ERROR_LOG_FILE}.tail -`
		rm ${LAST_ERROR_LOG_FILE}.tail
	else
		BUILD_DELTA=`tail -n 10 $LAST_CHANGED_LOG_FILE`
	fi
	cp $LAST_CHANGED_LOG_FILE $LAST_ERROR_LOG_FILE
else
	rm -f $LAST_ERROR_LOG_FILE
fi

if [ $STATUS -ne 0 ]; then

	echo " =============== WARNING: Build Error =============== "
	echo
	echo "`tail -n 15 $LAST_ERROR_LOG_FILE`"
	echo
	echo Note: for a full log, see $LAST_ERROR_LOG_FILE
	echo
	echo " ==================================================== "
	echo
	echo "---> Failed to build Etoile - error in $FAILED_MODULE :-("
	echo

	# If the delta between the error logs has changed in the last two builds,
	# it is a new build failure that must be reported by mail, otherwise it 
	# is the same failure than previously (no need to report it once more).
	if [ -n "$BUILD_DELTA" -a "$TEST_BUILD" = "yes" ]; then
		echo "---> Sending mail to $MAIL_TO - $MAIL_SUBJECT"
		echo

		PLATFORM=`uname -s -i -o`
		tar -zcf $LOG_BASE_DIR/etoile-build-log.tar.gz -C $LOG_BASE_DIR `basename $LOG_DIR`

		MAIL_SUBJECT="Etoile Build Failure -- $FAILED_MODULE on $PLATFORM"
		MAIL_ATTACHMENTS="$LOG_BASE_DIR/etoile-build-log.tar.gz $PROFILE_SCRIPT" 
		MAIL_BODY="Test build failure on $PLATFORM at `date` -- Detailed build logs and profile are available in attachments -- \n\n`cat $LOG_SUMMARY_FILE`\n\n"
		. $SCRIPT_DIR/sendmail.sh
	fi

	exit 1

else

	# For now, setup is pretty much useless and kinda broken
	#./setup.sh

	echo
	echo "--> Finished Etoile build :-)"
	echo
	
fi

if [ $STATUS -eq 0 -a "$TEST_BUILD" != "yes" ]; then

	if [ "$UPDATE_BASHRC" = "yes" ]; then

		echo "export PATH=$LLVM_INSTALL_DIR/bin:$PATH" >> ~/.bashrc
		echo "export LD_LIBRARY_PATH=$LLVM_INSTALL_DIR/lib:$LD_LIBRARY_PATH" >> ~/.bashrc
		echo "export CC=clang" >> ~/.bashrc
		echo "export CXX=clang++" >> ~/.bashrc
		echo ". ${PREFIX_DIR%/}/System/Library/Makefiles/GNUstep.sh" >> ~/.bashrc
	else

		echo "For GNUstep and Etoile development, some environment variables must be set."
		echo "To do so, just update ~/.bashrc or a similar file to include:"
		echo
		echo "export PATH=$LLVM_INSTALL_DIR/bin:\$PATH"
		echo "export LD_LIBRARY_PATH=$LLVM_INSTALL_DIR/lib:\$LD_LIBRARY_PATH"
		echo "export CC=clang" >> ~/.bashrc
		echo "export CXX=clang++" >> ~/.bashrc
		echo ". ${PREFIX_DIR%/}/System/Library/Makefiles/GNUstep.sh"

	fi
	echo
fi

# TODO: Improve support for non-test builds
#
#echo "You now need to log out and choose Etoile session in GDM, then log in "
#echo "to start Etoile."
#echo

# TODO: Make possible to skip setup.sh and run it later manually
#
#echo "Installation of Etoile is almost finished, you now need to run setup.sh "
#echo "script by yourself to have a usable environment."
#echo
#echo " -- The script path is $BUILD_DIR/Etoile/setup.sh -- "
#echo

