#!/bin/sh

if [ ! -n "`which apt-get`" ]; then
	echo "WARNING: Dependencies have to be installed manually or using another script (apt-get is missing)."
	echo "You can comment out DEPENDENCY_SCRIPT variable in the build profile to turn off this warning."
	exit
fi

# Install Etoile and GNUstep dependencies for Ubuntu 9.04 (copied from INSTALL.Ubuntu)
# Universe repository needs to be enabled in /etc/apt/sources.list for libonig-dev to show up

# The installs have been split up in to multiple apt-get commands because apt-get install
# will fail to install all packages if a single package isn't available, and some packages
# like hal are no longer available in recent Ubuntu versions. 

sudo apt-get -q=2 install hal

sudo apt-get -q=2 install libjpeg-dev libtiff-dev libpng-dev libgif-dev
sudo apt-get -q=2 install libjpeg62-dev libtiff4-dev libpng12-dev libgif-dev

sudo apt-get -q=2 install cmake gobjc libxml2-dev libxslt1-dev libffi-dev libssl-dev libgnutls-dev libicu-dev libfreetype6-dev libx11-dev libcairo2-dev libxft-dev libxmu-dev dbus libdbus-1-dev libstartup-notification0-dev libxcursor-dev libxss-dev xscreensaver g++ libpoppler-dev libonig-dev  lemon libgmp3-dev libsqlite3-dev libkqueue-dev libpthread-workqueue-dev libavcodec-dev libavformat-dev libtagc0-dev libmp4v2-dev discount libgraphviz-dev

sudo apt-get -q=2 install clang-3.3

# Install Subversion to be able to check out Etoile and Git for LLVM

sudo apt-get -q=2 install subversion git
