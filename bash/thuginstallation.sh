#!/bin/bash
# Script for installing Thug, the low-interaction Python honeyclient
# https://buffer.github.io/thug/

# Copyright (C) 2016 Payload Security UG (haftungsbeschränkt)
#
# Licensed  GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# see https://github.com/PayloadSecurity/VxCommunity/blob/master/LICENSE.md
#
# Date - 01.03.2016
# Version - 0.0.1

# Instructions:
#
# chmod +x thuginstallation.sh
# sudo ./thuginstallation.sh
#

# * INIT
# * GOOGLEV8
# * REQUIREMENTS
# * YARA
# * TEST

# * Exit code 0 - Successful exit 
# * Exit code 1 - General error
# * Exit code 126 - Run with sudo rights

# User validation for installing 

echo -e "\n#----------------------- Thug Honeyclient Setup ------------------------#" >&2
echo "# This script will install Thug, the low-interaction Python honeyclient #" >&2
echo "#-----------------------------------------------------------------------#" >&2

# Usage options 

USAGE () {

	echo "Usage: $0 --options"
	echo "-h --help: Print help"
	echo "-v --verbose: Use verbose output"
	exit 1

}

while [ "$#" -gt 0 ]; do
	option="$1"
	shift
	case "$option" in
		-h|--help)
			USAGE
			;;

		-v|--verbose) 
			set -o xtrace
			;;

		--ignore-yara) 
			IGNOREYARA="YES"
			;;

		*)
			echo "$0: Invalid argument.. $1" >&2
			USAGE
			exit 1
			;;
	esac
done

# Check if script run as root

if [ "$(id -u)" -ne 0 ]; then
	echo "Please run this script as root!"
	exit 126
fi

# Initial dependencies

INIT() {

	# Get working directory 

	DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

	# Enable logging

	echo -e "\n-----------THUG INSTALLATION-----------" >> $DIR/bootstrap.log 
	exec &> >(tee -a "$DIR/bootstrap.log")

	# Update apt
	
	echo -e "\nUpdating apt..." && apt-get -qq update || {
		echo "Failed to update. Exiting!"
		exit 1
	}
	
	# Install Thug dependencies 

	echo -e "\nInstalling python-socksipy..." && apt-get install -qq python-socksipy || {
	
		echo -e "\nFailed to install, trying python-socks now ..." && apt-get install -qq python-socks || {
			echo "Fatal error: failed to unpack the archive using 7zip. Exiting ..."
			exit 1
		}
	}

	echo -e "\nInstalling Thug dependencies..." && apt-get install -qq build-essential python-dev python-setuptools libboost-python-dev libboost-all-dev subversion python-pip libxml2-dev libxslt-dev git libtool autoconf >> $DIR/bootstrap.log 2>&1 && echo -e "\nSuccessfully installed Thug dependencies!" || {

		echo "Failed to install Thug dependencies! Exiting!"
		exit 1
	}
	
	# Download Thug

	test -d /opt/thug && rm -rf /opt/thug # If a Thug folder already exists, then delete it

	echo -e "\nDownloading Thug..." && cd /opt && git clone https://github.com/buffer/thug.git >> $DIR/bootstrap.log 2>&1 && echo -e "\nSuccessfully downloaded Thug!" || {

		echo "Failed to download Thug! Exiting!"
		exit 1
	}
}

# Google V8 setup

GOOGLEV8() {

	# Download Google V8

	echo -e "\nDownloading Google PyV8..." && cd /tmp && git clone https://github.com/buffer/pyv8.git >> $DIR/bootstrap.log && echo -e "\nSuccessfully downloaded PyV8!" || {

		echo "Failed to download Google V8! Exiting!"
		exit 1
	}

	# Install Google V8

	echo -e "\nInstalling Google V8 and PyV8... (This might take some time)" && cd pyv8 && python setup.py build > /dev/null 2>> $DIR/bootstrap.log && sudo python setup.py install > /dev/null 2>> $DIR/bootstrap.log && echo -e "\nSuccessfully installed Google V8 and PyV8!" || {

		echo "Failed to install Google V8! Exiting!"
		exit 1
	}
}

# Install requirements for Thug

REQUIREMENTS() {


	# Install beautifulsoup4

	pip install beautifulsoup4 -q && echo -e "\nSuccessfully installed beautifulsoup4!" || {

		echo "Failed to install beautifulsoup4! Exiting!"
		exit 1
	}

	# Install html5lib

	pip install html5lib -q && echo -e "\nSuccessfully installed html5lib!" || {

		echo "Failed to install html5lib! Exiting!"
		exit 1
	}

	# Install jsbeautifier

	pip install jsbeautifier -q && echo -e "\nSuccessfully installed jsbeautifier!" || {

		echo "Failed to install jsbeautifier! Exiting!"
		exit 1
	}

	# Install libemu

	cd /tmp && git clone git://github.com/buffer/libemu.git >> $DIR/bootstrap.log 2>&1 && cd libemu && autoreconf -v -i >> $DIR/bootstrap.log 2>&1 && ./configure --prefix=/opt/libemu >> $DIR/bootstrap.log 2>&1 && sudo make install >> $DIR/bootstrap.log 2>&1 && echo -e "\nSuccessfully installed libemu!" || {

		echo "Failed to install libemu!"
		exit 1
	}

	# Install pylibemu

	pip install pylibemu -q && echo -e "\nSuccessfully installed pylibemu!" || {

		echo "Failed to install pylibemu! Exiting!"
		exit 1
	}

	# Fix libemu shared libs

	touch /etc/ld.so.conf.d/libemu.conf && echo "/opt/libemu/lib/" > /etc/ld.so.conf.d/libemu.conf && ldconfig && echo -e "\nSuccessfully fixed libemu shared libaries!" || {

		echo "Failed to fix libemu shared libaries! Exiting!"
		exit 1
	}


	# Install pefile

	pip install pefile -q && echo -e "\nSuccessfully installed pefile!" || {

		echo "Failed to install pefile! Exiting!"
		exit 1
	}

	# Install chardet

	pip install chardet -q && echo -e "\nSuccessfully installed chardet!" || {

		echo "Failed to install chardet! Exiting!"
		exit 1
	}

	# Install requests

	pip install requests -q && echo -e "\nSuccessfully installed requests!" || {

		echo "Failed to install requests! Exiting!"
		exit 1
	}

	# Install PySocks

	pip install PySocks -q && echo -e "\nSuccessfully installed PySocks!" || {

		echo "Failed to install PySocks! Exiting!"
		exit 1
	}

	# Install cssutils

	pip install cssutils -q && echo -e "\nSuccessfully installed cssutils!" || {

		echo "Failed to install cssutils! Exiting!"
		exit 1
	}

	# Install zope.interface

	pip install zope.interface -q && echo -e "\nSuccessfully installed zope.interface!" || {

		echo "Failed to install zope.interface! Exiting!"
		exit 1
	}

	# Install pyparsing

	pip install pyparsing -q && echo -e "\nSuccessfully installed pyparsing!" || {

		echo "Failed to install pyparsing! Exiting!"
		exit 1
	}

	# Install python-magic

	pip install python-magic -q && echo -e "\nSuccessfully installed python-magic!" || {

		echo "Failed to install python-magic! Exiting!"
		exit 1
	}

	# Install rarfile

	pip install rarfile -q && echo -e "\nSuccessfully installed rarfile!" || {

		echo "Failed to install rarfile! Exiting!"
		exit 1
	}

	# Install graphviz 

	pip install graphviz -q && echo -e "\nSuccessfully installed graphviz!" || {

		echo "Failed to install graphviz! Exiting!"
		exit 1
	}

	# Install graphviz-dev

	apt-get install -qq graphviz-dev >> $DIR/bootstrap.log 2>&1 && echo -e "\nSuccessfully installed graphviz-dev!" || {

		echo "Failed to install graphviz-dev! Exiting!"
		exit 1
	}

	# Install pygraphviz

	pip install pygraphviz -q --install-option="--include-path=/usr/include/graphviz" --install-option="--library-path=/usr/lib/graphviz/" && echo -e "\nSuccessfully installed pygraphviz!" || {

		echo "Failed to install pygraphviz! Exiting!"
		exit 1
	}

	# Install lxml 

	pip install lxml -q && echo -e "\nSuccessfully installed lxml!" || {

		echo "Failed to install lxml! Exiting!"
		exit 1
	}

}

# Install YARA

YARA () {

	if [ "$IGNOREYARA" == "YES" ]; then

		echo -e "\nIgnoring YARA installation"

	else

		# Install YARA prerequisites 

		echo -e "Installing YARA prerequisites..." && apt-get install -qq automake >> $DIR/bootstrap.log 2>&1 && apt-get install -qq libtool >> $DIR/bootstrap.log 2>&1 && echo -e "\nSuccessfully installed prerequisites for YARA!\n" || {
			echo "Failed to install prerequisites for YARA!"
		}

		# Download YARA & Unzip it 

		echo "Downloading YARA..." && cd $DIR && wget https://github.com/VirusTotal/yara/archive/v3.5.0.tar.gz 2>> $DIR/bootstrap.log && tar xf v3.4.0.tar.gz && echo -e "\nSuccessfully downloaded and unzipped YARA!\n" || {
			echo "Failed to download or unzip YARA!"
		}

		# Compile and install YARA

		echo -e "Compiling and installing YARA...\n" && cd yara-3.5.0/ && ./bootstrap.sh >> $DIR/bootstrap.log && ./configure >> $DIR/bootstrap.log && make >> $DIR/bootstrap.log && sudo make install >> $DIR/bootstrap.log && ldconfig && echo -e "\nSuccessfully installed YARA!\n" || {
			echo "Failed to compile or install YARA!"
		}   

		# Install yara-python

		echo -e "Installing yara-python...\n" && sudo pip install yara-python && echo -e "\nSuccessfully installed yara-python!" || {

			echo "Failed to install yara-python!"
		}

	fi

}

TEST() {

	# Test Thug

	echo -e "\nTesting Thug..." && python /opt/thug/src/thug.py -h >> $DIR/bootstrap.log 2>&1 && echo -e "\nThug is working." && echo -e "\nSuccessfully installed Thug!" && exit 0

}

# Call out the main functions 

INIT
GOOGLEV8
REQUIREMENTS
YARA
TEST
