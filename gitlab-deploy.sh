#!/bin/bash
#---------- see https://github.com/joelong01/Bash-Wizard----------------
# bashWizard version 0.909
# this will make the error text stand out in red - if you are looking at these errors/warnings in the log file
# you can use cat <logFile> to see the text in color.
function echoError() {
    RED=$(tput setaf 1)
    NORMAL=$(tput sgr0)
    echo "${RED}${1}${NORMAL}"
}
function echoWarning() {
    YELLOW=$(tput setaf 3)
    NORMAL=$(tput sgr0)
    echo "${YELLOW}${1}${NORMAL}"
}
function echoInfo {
    GREEN=$(tput setaf 2)
    NORMAL=$(tput sgr0)
    echo "${GREEN}${1}${NORMAL}"
}
# make sure this version of *nix supports the right getopt
! getopt --test 2>/dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echoError "'getopt --test' failed in this environment. please install getopt."
    read -r -p "install getopt using brew? [y,n]" response
    if [[ $response == 'y' ]] || [[ $response == 'Y' ]]; then
        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" < /dev/null 2> /dev/null
        brew install gnu-getopt
        #shellcheck disable=SC2016
        echo 'export PATH="/usr/local/opt/gnu-getopt/bin:$PATH"' >> ~/.bash_profile
        echoWarning "you'll need to restart the shell instance to load the new path"
    fi
   exit 1
fi

function usage() {
    
    echo ""
    echo ""
    echo "Usage: $0  -g|--resourceGroupName -n|--vmName -u|--adminUser " 1>&2
    echo ""
    echo " -g | --resourceGroupName     Required     "
    echo " -n | --vmName                Required     "
    echo " -u | --adminUser             Optional     "
    echo ""
    exit 1
}
function echoInput() {
    echo "jenkins-deploy.sh:"
    echo -n "    resourceGroupName.... "
    echoInfo "$resourceGroupName"
    echo -n "    vmName............... "
    echoInfo "$virtualMachine"
    echo -n "    adminUser............ "
    echoInfo "$adminUser"

}

function parseInput() {
    
    local OPTIONS=g:n:u:
    local LONGOPTS=resourceGroupName:,vmName:,adminUser:

    # -use ! and PIPESTATUS to get exit code with errexit set
    # -temporarily store output to be able to check for errors
    # -activate quoting/enhanced mode (e.g. by writing out "--options")
    # -pass arguments only via -- "$@" to separate them correctly
    ! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        # e.g. return value is 1
        # then getopt has complained about wrong arguments to stdout
        usage
        exit 2
    fi
    # read getopt's output this way to handle the quoting right:
    eval set -- "$PARSED"
    while true; do
        case "$1" in
        -g | --resourceGroupName)
            resourceGroupName=$2
            shift 2
            ;;
        -n | --vmName)
            virtualMachine=$2
            shift 2
            ;;
        -u | --adminUser)
            adminUser=$2
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echoError "Invalid option $1 $2"
            exit 3
            ;;
        esac
    done
}
# input variables 
declare resourceGroupName=
declare virtualMachine=
declare adminUser=azureuser

parseInput "$@"

#verify required parameters are set
if [ -z "${resourceGroupName}" ] || [ -z "${virtualMachine}" ]; then
    echo ""
    echoError "Required parameter missing! "
    echoInput #make it easy to see what is missing
    echo ""
    usage
    exit 2
fi


    # --- BEGIN USER CODE ---
    dnsSuffix=$(head /dev/urandom | tr -dc a-z0-9 | head -c 5)

    # Create a resource group.
    az group create --name $resourceGroupName --location WestUS2

    # Create a new virtual machine, this creates SSH keys if not present.
    az vm create --resource-group $resourceGroupName --name $virtualMachine --admin-username $adminUser --image UbuntuLTS --generate-ssh-keys --public-ip-address-dns-name "gitlab-$dnsSuffix"

    # Open port 80 to allow web traffic to host.
    az vm open-port --port 80 --resource-group $resourceGroupName --name $virtualMachine  --priority 101

    # Open port 22 to allow web traffic to host.
    az vm open-port --port 22 --resource-group $resourceGroupName --name $virtualMachine --priority 102
    
    # Get public FQDN
    fqdn=$(az network public-ip show -n "${virtualMachine}PublicIP" -g $resourceGroupName --query "dnsSettings.fqdn" --output tsv)

    # Use CustomScript extension to install NGINX.
    az vm extension set --publisher Microsoft.Azure.Extensions --version 2.0 --name CustomScript --vm-name $virtualMachine --resource-group $resourceGroupName --settings '{"fileUris": ["https://raw.githubusercontent.com/omusavi/gitlab-install/master/gitlab-config.sh"],"commandToExecute": "./gitlab-config.sh '$fqdn'"}'

    echo "Installed! Open a browser to http://${fqdn}"
    # --- END USER CODE ---
