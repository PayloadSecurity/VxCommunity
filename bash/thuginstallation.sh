#!/bin/bash
# Script for installing Thug, the low-interaction Python honeyclient
# Thug can be found from: https://buffer.github.io/thug/

# Copyright (C) 2016 Payload Security UG (haftungsbeschränkt)
#
# Licensed  GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# see https://github.com/PayloadSecurity/VxCommunity/blob/master/LICENSE.md
#
# Date - 19.12.2016
# Version - 1.0.2

# Functions:
#
# * commandOutPut
# * conf
# * checks
# * init
# * googleV8
# * requirements
# * yara
# * installThug
# * testThug

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
	echo "--ignore-yara: Will skip YARA installation. Use only if YARA is already installed"
	exit 0

}

# Arg parsing

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
			IGNOREYARA=true
			;;
		*)
			echo "$0: Invalid argument.. $1" >&2
			USAGE
			exit 1
			;;
	esac
done

# Make sure script is run as root

if [ "$(id -u)" -ne 0 ]; then
	echo "Please run this script as root!"
	exit 126
fi

# Configuration

conf() {

	# Get working directory 

	DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

	# Enable logging

	bootstrapLog="$DIR"/bootstrap.log
	echo -e "\n-----------THUG INSTALLATION-----------" >> "$bootstrapLog"
	exec &> >(tee -a "$bootstrapLog")

}

# Run mandatory checks 

checks() {

    # If pip is installed, then run mandatory checks

    dpkg --get-selections | grep python-pip >> "$bootstrapLog" 2>&1

	if [ $? -eq 0 ]; then

    	echo -e "\n--------------- Mandatory Checks ----------------\n"

		# Check if Thug is installed

		pip list | grep "thug" >> "$bootstrapLog" 2>&1

		if [ $? -eq 0 ]; then

			failure
			echo "Thug seems to be already installed. This may cause issues with the installation"
			echo "Do you wish to proceed and try to remove Thug automatically? If you choose no, then you have to remove Thug manually"
			select yn in "Yes" "No"; do
				case $yn in
					Yes )
						pip uninstall -y thug >> "$bootstrapLog" 2>&1
						break;;
					No ) 
						exit 1;;
				esac
			done

		else

			success
			echo "Thug is not installed"

		fi

		# Check if PyV8 is installed

		pip list | grep "PyV8" >> "$bootstrapLog" 2>&1

		if [ $? -eq 0 ]; then

			failure
			echo "PyV8 seems to be already installed. This may cause issues with the installation"
			echo "Do you wish to proceed and try to remove PyV8 automatically? If you choose no, then you have to remove PyV8 manually"
			select yn in "Yes" "No"; do
				case $yn in
					Yes )
						pip uninstall -y PyV8 >> "$bootstrapLog" 2>&1
						rm -rf /tmp/pyv8/
						break;;
					No ) 
						exit 1;;
				esac
			done

		else

			success
			echo "PyV8 is not installed"

		fi

	fi

}

# Initial dependencies

init() {

    echo -e "\n----------------- Dependencies ------------------\n"

	# Update repositories
	
	echo "Updating repositories..." && apt-get -qq update && success && echo -e "Successfully updated repositories\n" || {

		failure
		echo "Fatal error: failed to update repositories. Exiting..."
		exit 1
	}
	
	# Install Thug dependencies 

	echo "Installing python-socksipy..." && apt-get install -qq python-socksipy >> "$bootstrapLog" 2>&1 && success && echo -e "Successfully installed python-socksipy\n" || {
	
		echo -e "\nFailed to install python-socksipy, trying python-socks now ..." && apt-get install -qq python-socks || {

			failure
			echo "Fatal error: failed to install python-socksipy or python-socks. Exiting ..."
        	echo "See $bootstrapLog for more information"
			exit 1
		}
	}

	# Install Thug dependencies 

	echo "Installing Thug dependencies..." && apt-get install -qq build-essential python-dev python-setuptools libboost-python-dev libboost-all-dev subversion python-pip libxml2-dev libxslt-dev git libtool autoconf libffi-dev libjpeg8-dev zlib1g-dev libssl-dev pkg-config libfuzzy-dev automake graphviz graphviz-dev >> "$bootstrapLog" 2>&1 && success && echo -e "Successfully installed Thug dependencies\n" || {

		failure
		echo "Fatal error: failed to install Thug dependencies. Exiting..."
        echo "See $bootstrapLog for more information"
		exit 1
	}

	# Download Thug

	test -d /opt/thug && rm -rf /opt/thug # If a Thug folder already exists, then delete it

	echo "Downloading Thug..." && cd /opt && git clone https://github.com/buffer/thug.git >> "$bootstrapLog" 2>&1 && success && echo -e "Successfully downloaded Thug\n" || {

		failure
		echo "Fatal error: failed to download Thug. Exiting..."
        echo "See $bootstrapLog for more information"
		exit 1
	}

	# Install setuptools

	wget --quiet https://bootstrap.pypa.io/ez_setup.py -O - | sudo python >> "$bootstrapLog" 2>&1 && success && echo "Successfully installed setuptools" || {

		failure
		echo "Fatal error: failed to install setuptools. Exiting..."
        echo "See $bootstrapLog for more information"
		exit 1
	}

	# Install pygraphviz

	pip install pygraphviz -q --install-option="--include-path=/usr/include/graphviz" --install-option="--library-path=/usr/lib/graphviz/" >> "$bootstrapLog" 2>&1 && success && echo -e "Successfully installed pygraphviz\n" || {

		failure
		echo "Fatal error: failed to install pygraphviz. Exiting..."
        echo "See $bootstrapLog for more information"
		exit 1
	}
}

# Google V8 setup

googleV8() {

    echo -e "------------------- Google V8 -------------------\n"

	# Download Google V8

	echo "Downloading Google PyV8..." && cd /tmp && git clone https://github.com/buffer/pyv8.git >> "$bootstrapLog" 2>&1 && success && echo -e "Successfully downloaded PyV8\n" || {

		failure
		echo "Fatal error: failed to download Google V8. Exiting..."
        echo "See $bootstrapLog for more information"
		exit 1
	}

	# Install Google V8

	echo "Installing Google V8 and PyV8... (This might take some time)" && cd pyv8 && python setup.py build > /dev/null 2>> "$bootstrapLog" && sudo python setup.py install > /dev/null 2>> "$bootstrapLog" && success && echo -e "Successfully installed Google V8 and PyV8\n" || {

		failure
		echo "Fatal error: failed to install Google V8. Exiting..."
        echo "See $bootstrapLog for more information"
		exit 1
	}
}

# Install YARA

yara() {

    echo -e "--------------------- YARA ----------------------\n"

	if [[ "$IGNOREYARA" == true ]]; then

		echo "Skipping YARA installation..."

	else

		# Download YARA & Unzip it 

		echo "Downloading YARA..." && cd $DIR && wget https://github.com/VirusTotal/yara/archive/v3.6.3.tar.gz >> "$bootstrapLog" 2>&1 && tar xf v3.6.3.tar.gz && success && echo -e "Successfully downloaded and unzipped YARA\n" || {

			echo "Failed to download or unzip YARA. Skipping YARA installation"
	        echo "See $bootstrapLog for more information"
			return 1
		}

		# Compile and install YARA

		echo "Compiling and installing YARA..." && cd yara-3.6.3/ && ./bootstrap.sh >> "$bootstrapLog" 2>&1 && ./configure > /dev/null 2>> "$bootstrapLog" && make > /dev/null 2>> "$bootstrapLog" && sudo make install > /dev/null 2>> "$bootstrapLog" && ldconfig && success && echo -e "Successfully installed YARA\n" || {

			echo "Failed to compile or install YARA"
	        echo "See $bootstrapLog for more information"
			return 1
		}   

		# Install yara-python

		echo "Installing yara-python..." && pip install yara-python >> "$bootstrapLog" 2>&1 && success && echo -e "Successfully installed yara-python\n" || {

			echo "Failed to install yara-python"
	        echo "See $bootstrapLog for more information"
			return 1
		}

	fi

}

# Install Thug

installThug() {

    echo -e "--------------------- Thug ----------------------\n"

	# Install Thug

	echo "Installing Thug..." && pip install thug -q >> "$bootstrapLog" 2>&1 && success && echo "Successfully installed Thug" || {

		failure
		echo "Failed to install Thug. Exiting..."
		echo "See $bootstrapLog for more information"
		exit 1
	}

	# Configure libemu

	echo "/opt/libemu/lib/" > /etc/ld.so.conf.d/libemu.conf && ldconfig && success && echo -e "Successfully configured libemu\n" || {

		failure
		echo "Failed to configure libemu. Exiting..."
		echo "See $bootstrapLog for more information"
		exit 1
	}

}

# Test Thug

testThug() {

	echo "Testing Thug..." && thug -h >> "$bootstrapLog" 2>&1 && success && echo "Thug is working properly" && exit 0 || {

		failure
		echo "Fatal error: Thug is not working properly"
		echo "See $bootstrapLog for more information"
		exit 1
	}

}

# Success and error message colouring

commandOutput() {

    # Column number to place the status message
    # Get only without nested/child shells
    if [[ $SHLVL -le 2 ]]; then termColumns=$(tput cols); fi
    messageColumn=$((termColumns-20))

    # Command to move out to the configured column number
    moveToColumn="echo -en \\033[${messageColumn}G"

    # Command to set the color to SUCCESS (Green)
    setColorSuccess="echo -en \\033[32m"

    # Command to set the color to FAILED (Red)
    setColorFailure="echo -en \\033[31m"

    # Command to set the color back to normal
    setColorNormal="echo -en \\033[0;39m"

}

# Function to print the SUCCESS status message

success() {

    $moveToColumn
    echo -n "["
    $setColorSuccess
    echo -n $"  OK  "
    $setColorNormal
    echo -n "]"
    echo -ne "\r"
}

# Function to print the FAILED status message

failure() {
    
    $moveToColumn
    echo -n "["
    $setColorFailure
    echo -n $"FAILED"
    $setColorNormal
    echo -n "]"
    echo -ne "\r"
}

# Call out the main functions 

commandOutput
conf
checks
init
googleV8
yara
installThug
testThug
