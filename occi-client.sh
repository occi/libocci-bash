#!/bin/bash
OCCI_CLIENT_VERSION="0.1"

##############################################################################
#  Copyright 2012 
#  Gesellschaft für wissenschaftliche Datenverarbeitung mbH Göttingen
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
##############################################################################

##############################################################################
# Description: BASH OCCI Client
# Author(s):   Florian Feldhaus
##############################################################################

##############################################################################
# Initialize client configuration

DEBUG=false
GUI=true
OCCI_ENDPOINT="http://localhost/"
CONTENT_TYPE="text/plain"
ACCEPT="text/plain"

##############################################################################
# Handle options

function usage {
    cat <<_EOF_
Usage: $0 [options] ...

Options:
-d, --DEBUG           Echo all curl commands after they are executed
-e, --endpoint        Specify OCCI endpoint
-g, --gui             Use GUI mode (default)
-h, --help            Display this message and exit
-t, --text            Use text mode
-V, --version         Display version and exit
_EOF_
}

function version {
    echo "BASH OCCI Client, version "$OCCI_CLIENT_VERSION
}

if ! options=$(getopt -u -o dehV -l DEBUG,endpoint,help,version -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    exit 1
fi

set -- $options

while [ $# -gt 0 ]
do
    case $1 in
    -d|--DEBUG) DEBUG=true ;;
    -e|--endpoint) OCCI_ENDPOINT=$3 ;;
    -g|--gui) GUI=true ;;
    -h|--help) usage;exit 0 ;; 
    -t|--text) GUI=false ;;
    -V|--version) version;exit 0 ;;
    (--) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
    esac
    shift
done

##############################################################################
# Check if required tools are available

# test if bash is at least version 4
if [[ `bash --version` =~ GNU\ bash,\ [vV]ersion\ [0-3] ]]; then 
    echo "I require at least Bash version 4"
    exit 1
fi

# test if curl is installed
hash curl 2>&- || { echo >&2 "I require the curl binary but it's not installed.  Aborting."; exit 1; }

# test if dialog is installed
if $GUI; then
    hash dialog 2>&- || { echo >&2 "I require the dialog binary for GUI functionality, but it's not installed. Falling back to text mode.."; $GUI=false; }
fi

##############################################################################
# Define reqular expressions for OCCI rendering
# see OCCI HTTP Rendering at http://www.ogf.org/documents/GFD.185.pdf

# regular expression for parsing category strings
CATEGORY_REGEX='Category: *([^;]*); *scheme="([^"]*)"; *class="([^"]*)"; *(title="([^"]*)";)? *(rel="([^"]*)";)? *(location="([^"]*)";)? *(attributes="([^"]*)";)? *(actions="([^"]*)";)?'
X_OCCI_ATTRIBUTE_REGEX='X-OCCI-Attribute: *([^=]*)=(.*)'
X_OCCI_LOCATION_REGEX=''
LINK_REGEX='Link: *<([^>]*)>; *(rel="([^"]*);) *(self="([^"]*);)? *(category="([^"]*); *([^;]*))?'

##############################################################################
# Global variables

# global category registry
declare -A categories

# global list of currently selected entity URIs
declare -a entities

##############################################################################
# OCCI Client functionality

function config {
    select_occi_endpoint
    select_content_type
    select_accept
}

function select_occi_endpoint {
    # Ask for OCCI Endpoint to use
    endpoints=($(dialog --backtitle "Bash OCCI Client" \
                        --form "Specify Endpoints:" 22 76 16 \
        "OCCI Endpoint URI:" 1 1 $OCCI_ENDPOINT 1 19 255 0 \
         2>&1 1>&3))
    exit_code=$?
    OCCI_ENDPOINT=${endpoints[0]}
    return $exit_code
}

function select_content_type {
    # Ask for Content-Type to use for requests
    choice=($(dialog --backtitle "Bash OCCI Client" \
                 --menu "Select Content-Type for requests:" 22 76 16 \
         1 "text/plain" \
         2 "text/occi" \
         3 "application/json" \
         2>&1 1>&3))
    exit_code=$?
    case $choice in
        1)
            CONTENT_TYPE='text/plain'
            ;;
        2)
            CONTENT_TYPE='text/occi'
            ;;
        3)
            CONTENT_TYPE='application/json'
            ;;
    esac
    return $exit_code
}

function select_accept {
    # Ask for Accept MIME-Type to use for requests
    choice=($(dialog --backtitle "Bash OCCI Client" \
                     --menu "Select Accept MIME-Type for requests:" 22 76 16 \
           1 "text/plain" \
           2 "text/occi" \
           3 "application/json" \
           2>&1 1>&3))
    exit_code=$?
    case $choice in
        1)
            ACCEPT='text/plain'
            ;;
        2)
            ACCEPT='text/occi'
            ;;
        3)
            ACCEPT='application/json'
            ;;
    esac
    return $exit_code
}

function get_categories {
    curl_categories=$(curl -v -X GET "$OCCI_ENDPOINT-/" 2>&1)
    if $DEBUG; then
        if $GUI;then
            dialog --backtitle "Bash OCCI Client" \
                   --scrollbar \
                   --msgbox "$curl_categories" 22 76
        else
            echo $curl_categories
        fi
    fi
    while read -r line; do
       [[ $line =~ $CATEGORY_REGEX ]]
       term=${BASH_REMATCH[1]}
       scheme=${BASH_REMATCH[2]}
       class=${BASH_REMATCH[3]}
       title=${BASH_REMATCH[5]}
       rel=${BASH_REMATCH[7]}
       location=${BASH_REMATCH[9]}
       attributes=${BASH_REMATCH[11]}
       actions=${BASH_REMATCH[13]}
       
       declare -A category
       category=( [term]=$term [scheme]=$scheme [class]=$class [title]=$title [rel]=$rel [location]=$location )
       if [ -n "$term" ]
       then
           categories[$term]=${category[@]}
       fi
    done <<< "$curl_categories"
    }

function get_entities {
    curl_entities=$(curl -v -X GET --header "Accept: text/uri-list" -w "\n" "$OCCI_ENDPOINT" 2>&1)
    dialog_entities=""
    if $DEBUG; then
    dialog --backtitle "Bash OCCI Client" \
       --scrollbar \
       --msgbox "$curl_entities" 22 76
    fi
    declare -i i=1
    while read -r line; do
        if [[ $line == http* ]]; then 
            entities+=($line)
            dialog_entities+="$i $line "
            i+=1
        fi
    done <<< "$curl_entities"

    choice=($(dialog --backtitle "Bash OCCI Client" \
                     --menu "Select entity to show details:" 22 76 16 \
                     $dialog_entities \
                     2>&1 1>&3))

    if [[ -n $choice ]]; then
       show_entity_details ${entities[$choice]}
    fi  
}

function show_entity_details {
    curl_entity=$(curl -v -X GET --header "Accept: $ACCEPT" -w "\n" $1 2>&1)
    if $DEBUG; then
        dialog --backtitle "Bash OCCI Client" \
               --scrollbar \
               --msgbox "$curl_entity" 22 76
    fi

    declare -a entity_categories
    declare -A entity_attributes
    declare -a entity_links

    while read -r line; do
        # parse if category string
        [[ $line =~ $CATEGORY_REGEX ]]
        if [[ -n ${BASH_REMATCH[0]} ]]; then 
            entity_categories+=(${categories[${BASH_REMATCH[1]}]})
        fi
        # parse if link
        [[ $line =~ $LINK_REGEX ]]
        if [[ -n ${BASH_REMATCH[0]} ]]; then echo ${BASH_REMATCH[0]};fi
        # parse if X-OCCI-Attribute
        [[ $line =~ $X_OCCI_ATTRIBUTE_REGEX ]]
        if [[ -n ${BASH_REMATCH[0]} ]]; then 
            entity_attributes[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
            [[ $entity_rendering_length -lt ${#BASH_REMATCH[2]} ]] && entity_rendering_length=${#BASH_REMATCH[2]}
        fi
        # parse if X_OCCI_Location
        [[ $line =~ $X_OCCI_LOCATION_REGEX ]]
    done <<< "$curl_entity"

    for key in "${!entity_attributes[@]}"; do
        entity_rendering+=$(printf "%${entity_rendering_length}s: %s" "$key" "${entity_attributes[$key]}")"\n"
    done

    dialog --backtitle "Bash OCCI Client" \
           --scrollbar \
           --msgbox "$entity_rendering" 22 76
}

function main_menu {
    # initialize list of categories
    get_categories
    while true; do
        choice=($(dialog --backtitle "Bash OCCI Client" \
                         --cancel-label "Exit" \
                         --menu "Select command to run:" 22 76 16 \
                  A "Configure OCCI Client" \
                  B "GET    - categories"  \
                  C "GET    - entities" \
                  D "GET    - entity" \
                  E "POST   - create mixin" \
                  F "POST   - create/update entity" \
                  G "POST   - trigger action" \
                  H "POST   - add mixin to resource" \
                  I "PUT    - full update of a Mixin Collection" \
                  J "PUT    - full update of a resource instance" \
                  K "DELETE - entity" \
                  L "DELETE - user defined mixin" \
                  M "DELETE - " \
               2>&1 1>&3))
        exit_code=$?
        if [[ $exit_code != 0 ]]; then return $exit_code; fi
        case $choice in
            A)
                config ;;
            B)
                get_categories ;;
            C)
                get_entities ;;
        esac
    done
}

##############################################################################
# OCCI Client User Interface

exec 3>&1
main_menu
exec 3>&-
