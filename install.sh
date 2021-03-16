#!/bin/bash
# VxStream Sandbox installer for automated installation of VxStream Sandbox
# Compatibility: Ubuntu 16.04 LTS

# Copyright (C) 2021 Hybrid Analysis GmbH
#
# Licensed  GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# see https://github.com/PayloadSecurity/VxCommunity/blob/master/LICENSE.md
#
# Date - 01.03.2021
# Version - 1.5

# Functions:
#
# * usage
# * cleanHost
# * conf
# * checks
# * main
# * commandOutput
# * success
# * failure

# Instructions:
#
# chmod +x install.sh
# sudo ./install.sh
#

# * Exit code 0 - Successfully exit 
# * Exit code 1 - General error
# * Exit code 126 - Run as root

# Version
version="1.5"

# User validation for installing 

echo -e "\n#----------------------- VxStream Sandbox Installer ------------------------#" >&2
echo "#---- This is an experimental beta-script and may not work as expected! ----#" >&2
echo -e "#---------------------------------------------------------------------------#\n" >&2

# Make sure script is not run as root

if [ "$(id -u)" -eq 0 ]; then
    echo "Please do not run this script as root."
    echo "You will be asked for root rights if the script will continue successfully to VxBootstrapUI initalization."
    exit 126
fi

# Usage options

usage() {

    echo "Copyright (C) 2021 CrowdStrike Inc."
    echo "Version: $version"
    echo -e "\nDescription:"
    echo "VxStream Sandbox installer for automated installation of VxStream Sandbox."
    echo "This scipt will download necessary resources and continue with the installation of VxStream Sandbox."
    echo -e "\nUsage:"
    echo -e  " $0 commands [parameters]\n"
    echo "Commands:"
    echo " --password          [Required] Password used for downloading resources"
    echo " --bypass-ssh        [Optional] Will download resources from Github over HTTPS instead of SSH. Use this only if downloading VxBootstrap or VxBootstrapUI fails"
    echo " --skip-mitm         [Optional] Will skip the Github SSH key verification for MITM attack mitigation"
    echo " --root-password     [Optional] The root password of the current user. If this is not passed, then the password will be prompted if the script will continue successfully to VxBootstrapUI initalization"
    echo " --no-sysupgrade     [Optional] Will skip a system upgrade (part of the underlying backend process)"
    echo -e "\nParameters:"
    echo " -h, --help          Print this help message"
    echo " -v, --verbose       Print verbose messages to stdout (debugging mode)"
    echo -e "\nPlease use single quotes around command line arguments.\n"
    echo "Example:" 
    echo -e " $0 --password 'insertpasswordhere'\n"
    exit 1

}

# Command line arguments parsing

args=":hv-:"
while getopts "$args" optchar; do 
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                password)
                    gpgPassword="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                bypass-ssh)
                    byPassSSH=true
                    ;;
                skip-mitm)
                    skipMitm=true
                    ;;
                root-password)
                    installUserPassword="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                no-sysupgrade)
                    noSysupgrade=true
                    ;;
                help)
                    usage
                    exit 1
                    ;;
                verbose)
                    set -o xtrace
                    ;;
                *)
                    if [ "$OPTERR" != 1 ] || [ "${args:0:1}" = ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                        echo "Try '$0 --help' for more information" >&2
                        exit 1
                    fi
                    ;;
            esac;;
        h)
            usage
            exit 1
            ;;
        v)
            set -o xtrace
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${args:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
                echo "Try '$0 --help' for more information" >&2
                exit 1
            fi
            ;;
    esac
done

# If no correct arguments were passed, then exit

if [ $OPTIND -eq 1 ]; then

    echo "No valid arguments were passed. Exiting..." >&2
    echo "Try '$0 --help' for more information" >&2
    exit 1

fi

# Check for correct number of arguments 

if [[ "$#" -lt 2 || "$#" -gt 6 ]]; then

    echo "Invalid number of arguments..."
    echo "Try '$0 --help' for more information" >&2
    exit 1

fi

# Clean-up trap exec
trap cleanHost EXIT

# Clean-up trap

cleanHost() {

    # If exit code is greater than 0, then clean the host
    if [ $? -gt 0 ]; then

        # Cleanup the installation directory
        echo
        failure
        echo "Fatal error caught. Cleaning up..."

        # Reenable automatic updates
        test -f /etc/apt/apt.conf.d/disabled_automatic_updates

        if [ $? -eq 0 ]; then

            test -f "/etc/apt/apt.conf.d/10periodic" && sudo sed -i 's#APT::Periodic::Update-Package-Lists "0";#APT::Periodic::Update-Package-Lists "1";#' /etc/apt/apt.conf.d/10periodic
            test -f "/etc/apt/apt.conf.d/20auto-upgrades" && sudo sed -i 's#APT::Periodic::Update-Package-Lists "0";#APT::Periodic::Update-Package-Lists "1";#' /etc/apt/apt.conf.d/20auto-upgrades 
            sudo rm -f "/etc/apt/apt.conf.d/disabled_automatic_updates"
            success && echo -e "Successfully reenabled automatic updates"

        fi

        echo "Cleaning up finished. Aborting..."
        exit 1

    fi
}

# Configuration

conf() {

    # Get working directory 
    DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

    # Installation directory
    installDir="$DIR"/vxstreaminstallation

    # Generate an installation directory
    test -d "$installDir" || mkdir -p "$installDir" && cd "$installDir"

    # Enable logging
    logFile=""$installDir"/install.log"
    echo -e "\nStarting install.sh... \nTimestamp:" >> "$logFile" && date >> "$logFile"
    exec &> >(tee -a "$logFile")

    # Export user who executed the script
    export installUser=$(whoami)

    # Make sure .ssh dir and known_hosts file exist
    test -d ~/.ssh/ || mkdir ~/.ssh
    test -f ~/.ssh/known_hosts || touch ~/.ssh/known_hosts

    # Download resources from Github over HTTPS instead of SSH
    if [ "$byPassSSH" == true ]; then

        git config --global url."https://".insteadOf git://

    fi

    # Decrypted authentication key file name
    decryptedKeyFile=""$installDir"/vxinstaller.key"

    # Authentication key file name
    authKeyFileName="vxinstallerkey.gpg"

    # Authentication key URL
    authKeyURL="https://www.crowdstrike.com/wp-content/sandbox/$authKeyFileName"

    # Correct authentication key type
    correctFileType="$(echo -e "binary/octet-stream" | tr -d '[[:space:]]')"

    # Get authentication key type
    fileTypeNow=$(curl -A "VxStream Sandbox" -ISsk "$authKeyURL" 2>> "$logFile" | grep "Content-Type:" | awk {'print $2'})
    fileTypeNow="$(echo -e "${fileTypeNow}" | tr -d '[[:space:]]')"

    # Get the status code of curl
    curlStatusCode=$(curl -A "VxStream Sandbox" -ISsk "$authKeyURL" 2>> "$logFile" | head -n 1 | cut -d$' ' -f2)

    # VxBootstrap Archive Name
    vxBootstrapArchiveName="VxBootstrap.zip"

    # VxBootstrap Package URL
    vxBootstrapURL="https://www.crowdstrike.com/wp-content/sandbox/$vxBootstrapArchiveName"

    # VxBootstrap Directory Name
    vxBootstrapDir="VxBootstrap"

}

# Run mandatory checks 

checks() {

    echo -e "----------------- Mandatory Checks ----------------\n"

    # Check if curl is installed and if not, then install it
    dpkg --get-selections | grep -w "curl" >> "$logFile" 2>&1

    if [ $? -eq 0 ]; then
        success && echo "Curl is installed"
    else

        # Install curl
        echo "Curl is not installed. Installing curl..." && sudo apt-get -qq install curl >> "$logFile" 2>&1 && success && echo "Successfully installed curl" || {

            failure
            echo "Fatal error: was not able to install curl. Please install it manually with: sudo apt-get install curl"
            echo "See $logFile for more information. Exiting..."
            exit 1

        }

    fi

    # Check if curl works 
    curl -s -S www.google.com | head -1 >> "$logFile" 2>&1 

    if [ $? -eq 0 ]; then
        success && echo "Curl is working"
    else
        failure
        echo "Fatal error: curl isn't working"
        echo "See $logFile for more information. Exiting..."
        exit 1
    fi

    # Check if Git works
    git --version >> "$logFile" 2>&1

    if [ $? -eq 0 ]; then
        success && echo -e "Git is working\n"
    else
        failure
        echo "Fatal error: Git isn't working. Make sure Git is installed"
        echo "See $logFile for more information. Exiting..."
        exit 1
    fi

    # If curl status code for downloading authentication key was not 200, then quit

    if [ "$curlStatusCode" == "200" ]; then

        success
        echo "Authentication key can be fetched from remote server"
    else

        failure
        echo "Fatal error: authentication key can not be fetched from remote server: $authKeyURL"
        echo "Curl status code: $curlStatusCode"
        echo "Please contact Payload Security. Exiting..."
        exit 1
    fi

    # Make sure authentication key type is correct
    if [ "$fileTypeNow" == "$correctFileType" ]; then

        success
        echo -e "Authentication key type is correct: $fileTypeNow\n"
    else

        failure
        echo "Fatal error: authentication key type is not correct: $fileTypeNow"
        echo "Please contact Payload Security. Exiting..."
        exit 1
    fi

    # Get release 
    codeName=$(lsb_release -cs)
    releaseDescription=$(lsb_release -ds)

    # Make sure the system uptime is atleast 5 minutes and the dpkg has finished it's processes
    if [ "$codeName" == "xenial" ]; then

        success
        echo "Distribution used: Ubuntu 16.04"

        systemUptime=$(cat /proc/uptime | awk '{r = sprintf("%.0f",$1/60); print r}')

        if [ "$systemUptime" -lt 5 ]; then

            failure
            echo "Fatal error: the system uptime is only: $systemUptime minutes"
            echo "Because dpkg might be locked just after system boot, it is advised to wait 5 minutes before installing VxStream. Exiting for now..."
            exit 1

        fi

        # Make sure dpkg has finished the initial boot update processes

        dpkgCounter=30

        while [ "$dpkgCounter" -gt 0 ]; do

            ps aux | grep '[a]pt.systemd.daily' >> "$logFile" 2>&1 

            if [ $? -eq 0 ]; then

                echo "Dpkg is still busy. Waiting for one minute..."
                sleep 60
                ((dpkgCounter--))

            else

                success
                echo -e "Looks like dpkg is not busy. Continuing...\n"
                break

            fi

        done

    elif [ "$codeName" == "trusty" ]; then

        failure
        echo "Fatal error: release used: $releaseDescription"
        echo "Supported release is Ubuntu 16.04 LTS. Exiting..."
        exit 1
        
    fi
    
}

# Download authentication key, repositories and initialize VxBootstrapUI 

main() {

    echo -e "----------------------- Main ----------------------\n"

    # Disable automatic updates during the installation so apt won't get locked
    if [ "$codeName" == "xenial" ]; then

        # Get current settings for automatic updates. 0 - disabled and 1 - enabled
        test -f "/etc/apt/apt.conf.d/10periodic"

        if [ $? -eq 0 ]; then

            automaticUpdatesSettings1=$(cat /etc/apt/apt.conf.d/10periodic | grep "Update-Package-Lists" | cut -d'"' -f2 | xargs)
        else

            automaticUpdatesSettings1=false
        fi

        test -f "/etc/apt/apt.conf.d/20auto-upgrades"

        if [ $? -eq 0 ]; then

            automaticUpdatesSettings2=$(cat /etc/apt/apt.conf.d/20auto-upgrades | grep "Update-Package-Lists" | cut -d'"' -f2 | xargs)
        else

            automaticUpdatesSettings2=false
        fi

        # If automatic updates are enabled, then disable them
        if [[ "$automaticUpdatesSettings1" == 1 ]] && [[ "$automaticUpdatesSettings2" == 1 ]]; then

            echo "Automatic updates are enabled at the moment"
            echo "We have to disable them during the installation so apt/dpkg won't get locked out. Sudo needed:"

            sudo sed -i 's#APT::Periodic::Update-Package-Lists "1";#APT::Periodic::Update-Package-Lists "0";#' /etc/apt/apt.conf.d/10periodic && 
            sudo sed -i 's#APT::Periodic::Update-Package-Lists "1";#APT::Periodic::Update-Package-Lists "0";#' /etc/apt/apt.conf.d/20auto-upgrades && 
            success && echo -e "Successfully disabled automatic updates during the installation\n" || {

                failure
                echo -e "Failed to disable automatic updates for the remainder of the installation\n"
            }

            # Create a file system token
            sudo touch /etc/apt/apt.conf.d/disabled_automatic_updates

        elif [[ "$automaticUpdatesSettings1" == 1 ]]; then

            echo "Automatic updates are enabled at the moment"
            echo "We have to disable them during the installation so apt/dpkg won't get locked out. Sudo needed:"

            sudo sed -i 's#APT::Periodic::Update-Package-Lists "1";#APT::Periodic::Update-Package-Lists "0";#' /etc/apt/apt.conf.d/10periodic && 
            success && echo -e "Successfully disabled automatic updates during the installation\n" || {

                failure
                echo -e "Failed to disable automatic updates for the remainder of the installation\n"
            }

            # Create a file system token
            sudo touch /etc/apt/apt.conf.d/disabled_automatic_updates  

        elif [[ "$automaticUpdatesSettings2" == 1 ]]; then

            echo "Automatic updates are enabled at the moment"
            echo "We have to disable them during the installation so apt/dpkg won't get locked out. Sudo needed:"

            sudo sed -i 's#APT::Periodic::Update-Package-Lists "1";#APT::Periodic::Update-Package-Lists "0";#' /etc/apt/apt.conf.d/20auto-upgrades && 
            success && echo -e "Successfully disabled automatic updates during the installation\n" || {

                failure
                echo -e "Failed to disable automatic updates for the remainder of the installation\n"
            }

            # Create a file system token
            sudo touch /etc/apt/apt.conf.d/disabled_automatic_updates  

        fi

    fi

    # Install 7zip and unrar to unpack VxBootstrap.zip later
    echo -e "Updating Repositories ... sudo needed:" && sudo apt update -q >> "$logFile" 2>&1 && echo -e "Installing 7zip, Unrar && zip ..." && sudo apt install -y -q p7zip-full p7zip-rar zip unzip unrar >> "$logFile" 2>&1 && success && echo -e "Successfully installed $

        failure
        echo "Fatal error: failed to install 7zip or unrar. Exiting ..."
        exit 1
    }

    # Download authentication key
    curl -A "VxStream Sandbox" -k -s -S "$authKeyURL" -o "$installDir"/"$authKeyFileName" 2>> "$logFile" && success && echo "Successfully downloaded authentication key" || {

        failure
        echo "Fatal error: failed to download authentication key"
        echo "See $logFile for more information. Exiting..."
        exit 1
    }

    # Decrypt the authentication key
    gpg -q --yes --passphrase "$gpgPassword" --decrypt --output "$decryptedKeyFile" "$installDir"/"$authKeyFileName" 2>> "$logFile" && success && echo -e "Successfully decrypted authentication key\n" || {

        failure
        echo "Fatal error: failed to decrypt authentication key"
        echo "See $logFile for more information. Exiting..."
        exit 1
    }

    # Check if authKeyVxBootstrapUI is correct
    head -27 "$decryptedKeyFile" > "$installDir"/authKeyVxBootstrapUI && chmod 600 "$installDir"/authKeyVxBootstrapUI && ssh-keygen -P "" -y -e -f "$installDir"/authKeyVxBootstrapUI >> "$logFile" 2>&1 && success && echo "VxBootstrapUI authentication key is correct" || {

        failure
        echo "Fatal error: VxBootstrapUI authentication key is invalid"
        echo "See $logFile for more information. Exiting..."
        exit 1
    }

    # Check if authKeyVxBootstrap is correct
    tail -28 "$decryptedKeyFile" > "$installDir"/authKeyVxBootstrap && chmod 600 "$installDir"/authKeyVxBootstrap && ssh-keygen -P "" -y -e -f "$installDir"/authKeyVxBootstrap >> "$logFile" 2>&1 && success && echo -e "VxBootstrap authentication key is correct\n" || {

        failure
        echo "Fatal error: VxBootstrap authentication key is invalid"
        echo "See $logFile for more information. Exiting..."
        exit 1
    }

    # Verify SSH key fingerprint to mitigate MITM
    # Skip verification if --skip-mitm argument is used
    if [ "$skipMitm" != true ]; then

        # Add Github as a trusted host
        tmpSSHKey=$(mktemp)
        ssh-keyscan -t rsa github.com > "$tmpSSHKey" 2>> "$logFile" && ssh-keygen -lf "$tmpSSHKey" &>> "$logFile"

        if [ $? -ne 0 ]; then

            failure
            echo "Fatal error: unable to retrieve Github SSH key"
            echo "The installer requires SSH access (default: port 22) in order to download the resources from Github"
            echo "If you have SSH (default: port 22) blocked in the firewall, then please enable it in order to continue with the installation. Exiting..."
            exit 1

        fi

        ssh-keygen -lf "$tmpSSHKey" | grep -E "SHA256:nThbg6kXUpJWGl7E1IGOCspRomTxdCARLviKw6E5SY8|16:27:ac:a5:76:28:2d:36:63:1b:56:4d:eb:df:a6:48" &>> "$logFile"

        if [ $? -ne 0 ]; then

            failure
            echo "Fatal error: Github SSH key fingerprint mismatch"
            echo "A possible man-in-the-middle attack detected"
            echo "If you wish to skip this check, then run the script again with argument: --skip-mitm. Exiting..."
            exit 1

        fi

    fi

    # Add the SSH key
    ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts 2>> "$logFile" && success && echo -e "Successfully added Github as a trusted host\n" || {

        failure
        echo "Fatal error: failed to add Github as a trusted host"
        echo "See $logFile for more information. Exiting..."
        exit 1
    }

    # Download VxBootstrapUI
    echo "Downloading VxBootstrapUI..." && ssh-agent bash -c "ssh-add "$installDir"/authKeyVxBootstrapUI &>> "$logFile"; git clone git@github.com:PayloadSecurity/VxBootstrapUI.git &>> $logFile"

    if [ $? -eq 0 ]; then

        success
        echo -e "Successfully downloaded VxBootstrapUI\n"

    else

        failure
        echo "Fatal error: Was not able to download VxBootstrapUI"
        echo "See $logFile for more information. Exiting..."
        exit 1

    fi

    # Download VxBootstrap Archive
    echo "Downloading VxBootstrap Package" && curl -A "VxStream Sandbox" -k -s -S "$vxBootstrapURL" -o "$installDir"/"$vxBootstrapArchiveName" 2>> "$logFile" && success && echo "Successfully downloaded VxBootstrap" || {

        failure
        echo "Fatal error: failed to download VxBootstrap"
        echo "See $logFile for more information. Exiting..."
        exit 1
    }

    # Unzip VxBootstrap Archive

    echo "Unpacking VxBootstrap..." && 7z -y x "$installDir"/"$vxBootstrapArchiveName" -o"$installDir" && success && echo -e "Successfully unzipped the archive with 7zip" || {

        failure
        echo "Fatal error: failed to unpack the archive using 7zip. Exiting ..."
        exit 1
    }
    
    # Create a soft link of VxBootstrap to user home dir if it does not exist yet
    test -d $HOME/VxBootstrap

    if [ $? -ne 0 ]; then

        ln -s "$installDir"/VxBootstrap $HOME >> "$logFile" 2>&1 && success && echo "Successfully created a softlink of VxBootstrap to $HOME" || {

            failure
            echo "Failed to create a softlink of VxBootstrap to $HOME"
            echo "See $logFile for more information"
        }
    fi
    
    # Set write permissions to the configuration file (used later by the UI)
    echo "Adding write permissions to the bootstrap configuration file..." && chmod 666 "$installDir"/VxBootstrap/bootstrap.cfg > /dev/null 2>> "$logFile" && success && echo -e "Successfully changed permissions\n" || {

        failure
        echo "Fatal error: failed to set correct permissions for "$installDir"/VxBootstrap/bootstrap.cfg. Exiting..."
        exit 1
    }

    # Initialize VxBootstrapUI 
    echo -e "Initializing VxBootstrapUI [need to ensure root rights]...\n" && sudo -k

    # Prompt for user password until a correct password has been provided
    while [[ "$userId" != 0 ]]; do

        # If --root-password was not provided, then prompt for it
        if [ -z "$installUserPassword" ]; then

            echo -n "[sudo] password for $installUser": 
            read -s installUserPassword

        fi

        # Check if given password is correct 
        userId=$(echo "$installUserPassword" | sudo -S id -u 2> /dev/null)

        if [ "$userId" = 0 ]; then 

            declare -x installUserPassword=$installUserPassword
            echo

        else

            echo -e "\nSorry, the provided password is incorrect. Please try again!"
            installUserPassword=""

        fi

    done

    # Add init.sh and bootstrap.sh to sudoers
    echo "$installUserPassword" | sudo -S bash -c "echo \"$installUser ALL=(ALL) NOPASSWD:SETENV: $installDir/VxBootstrapUI/scripts/init.sh, $installDir/VxBootstrap/bootstrap.sh\" >> /etc/sudoers"

    # Execute VxBootstrapUI installer
    if [ "$noSysupgrade" = true ]; then
        cd "$installDir"/VxBootstrapUI/scripts && sudo installUser="$installUser" installUserPassword="$installUserPassword" termColumns="$termColumns" ./init.sh --no-sysupgrade
    else
        cd "$installDir"/VxBootstrapUI/scripts && sudo installUser="$installUser" installUserPassword="$installUserPassword" termColumns="$termColumns" ./init.sh
    fi

    if [ $? -eq 0 ]; then

        exit 0

    else

        exit 1

    fi
}

# Success and error message colouring

commandOutput() {

    # Column number to place the status message
    termColumns=$(tput cols)
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

# Call out functions
commandOutput
conf
checks
main
