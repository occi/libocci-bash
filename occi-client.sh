#!/bin/bash

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
# Check if required tools are available

# test if bash is at least version 4
if [[ `bash --version` =~ GNU\ bash,\ [vV]ersion\ [0-3] ]]; then 
    echo "I require at least Bash version 4"
    exit 1
fi

# test if curl is installed
hash curl 2>&- || { echo >&2 "I require the curl binary but it's not installed.  Aborting."; exit 1; }

# test if dialog is installed
hash dialog 2>&- || { echo >&2 "I require the dialog binary but it's not installed.  Aborting."; exit 1; }

##############################################################################
# Define reqular expressions for OCCI rendering
# see OCCI HTTP Rendering at http://www.ogf.org/documents/GFD.185.pdf

# regular expression for parsing category strings
CATEGORY_REGEX='Category: *([^;]*); *scheme="([^"]*)"; *class="([^"]*)"; *(title="([^"]*)";)? *(rel="([^"]*)";)? *(location="([^"]*)";)? *(attributes="([^"]*)";)? *(actions="([^"]*)";)?'
X_OCCI_ATTRIBUTE_REGEX=''
X_OCCI_LOCATION_REGEX=''
LINK_REGEX='Link: *'

##############################################################################
# Global variables

# global category registry
declare -A categories

# global list of currently selected entity URIs
declare -a entities

##############################################################################
# OCCI Client User Interface

# Ask for OCCI Endpoint to use
exec 3>&1
endpoints=($(dialog --backtitle "Bash OCCI Client" \
                    --form "Specify Endpoints:" 22 76 16 \
         "OCCI Endpoint URI:" 1 1 "http://localhost:3300/" 1 19 255 0 \
         "CDMI Endpoint URI:" 2 1 "http://localhost:2364/" 2 19 255 0 \
         2>&1 1>&3))
exec 3>&-

OCCI_ENDPOINT="${endpoints[0]}"
CDMI_ENDPOINT="${endpoints[1]}"

# Ask for Content-Type to use for requests
exec 3>&1
choice=($(dialog --backtitle "Bash OCCI Client" \
                 --menu "Select Content-Type for requests:" 22 76 16 \
         1 "text/plain" \
         2 "text/occi" \
         3 "application/json" \
         2>&1 1>&3))
exec 3>&-

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

# Ask for Accept MIME-Type to use for requests
exec 3>&1
choice=($(dialog --backtitle "Bash OCCI Client" \
            --menu "Select Accept MIME-Type for requests:" 22 76 16 \
       1 "text/plain" \
       2 "text/occi" \
       3 "application/json" \
       2>&1 1>&3))
exec 3>&-

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

# initialize list of categories
get_categories

exec 3>&1
choices=($(dialog --backtitle "Bash OCCI Client" \
                  --menu "Select command to run:" 22 76 16 \
          1 "Refresh categories"  \
                    2 "Get entities" \
       2>&1 1>&3))
exec 3>&-

for choice in $choices
do
    case $choice in
        1)
            get_categories
            ;;
        2)
            get_entities
            ;;
        3)
            crud_compute
            ;;
        4)
            crud_compute_cdmi
            ;;
        5)
            crud_template
            ;;
        6)
            crud_compute_from_template
            ;;
    esac
done

##############################################################################
# OCCI Client functionality

function get_categories {
    curl_categories=$(curl -v -X GET "$OCCI_ENDPOINT-/" 2>&1)
    dialog --backtitle "Bash OCCI Client" \
           --scrollbar \
           --msgbox "$curl_categories" 22 76
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
    dialog --backtitle "Bash OCCI Client" \
       --scrollbar \
       --msgbox "$curl_entities" 22 76
        declare -i i=0
    while read -r line; do
        if [[ $line == http* ]]; then 
                        entities+=($line)
                        dialog_entities+="$i \"$line\" "
                        i+=1
                fi
    done <<< "$curl_entities"

        exec 3>&1
        choice=($(dialog --backtitle "Bash OCCI Client" \
           --menu "Select entity to show details:" 22 76 16 \
                     $dialog_entities \
               2>&1 1>&3))
    exec 3>&-

    curl_entity=$(curl -v -X GET --header "Accept: $ACCEPT" -w "\n" "${entities[$choice]}" 2>&1)
    dialog --backtitle "Bash OCCI Client" \
       --scrollbar \
       --msgbox "$curl_entity" 22 76

    while read -r line; do
        # parse if category string
        [[ $line =~ $CATEGORY_REGEX ]]
        # parse if 
    done <<< "$curl_entity"
}
