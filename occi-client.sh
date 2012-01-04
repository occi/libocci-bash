#!/bin/bash

# test if bash is at least version 4
if [[ `bash --version` =~ GNU\ bash,\ [vV]ersion\ [0-3] ]]; then 
    echo "I require at least Bash version 4"
    exit 1
fi

# test if curl is installed
hash curl 2>&- || { echo >&2 "I require the curl binary but it's not installed.  Aborting."; exit 1; }

# test if dialog is installed
hash dialog 2>&- || { echo >&2 "I require the dialog binary but it's not installed.  Aborting."; exit 1; }

# regular expression for parsing category strings
CATEGORY_REGEX='Category: *([^;]*); *scheme="([^"]*)"; *class="([^"]*)"; *(title="([^"]*)";)? *(rel="([^"]*)";)? *(location="([^"]*)";)? *(attributes="([^"]*)";)? *(actions="([^"]*)";)?'

# global category registry
declare -A categories

# global list of entity URIs
declare -a entities

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

}

#function create_network {
#}

function crud_network {
  echo '################ Creating network'
  case $CONTENT_TYPE in
  'text/occi')
    NETWORK_LOCATION=`curl -vs -X POST --header "Content-Type: $CONTENT_TYPE" --header "Accept: $ACCEPT" --header "Category: $NET_CATEGORY" --header "X-OCCI-Attribute: $NET_ATTRIBUTE" $NET_LOCATION`
    ;;
  'text/plain')
    BODY="Category: $NET_CATEGORY
X-OCCI-Attribute: $NET_ATTRIBUTE"
    NETWORK_LOCATION=`curl -vs -X POST --form "occi=$BODY" --header "Accept: $ACCEPT" --header "Category: $NET_CATEGORY" $NET_LOCATION`
    ;;
  esac
  if [ "$NETWORK_LOCATION" = "" ]; then exit;fi 
  echo '################  Network created successful'
  echo $NETWORK_LOCATION
  read -p "Press any key to continue..."
  echo '################ Getting all network URIs'
  curl -v -X GET $URI/network/
  echo ""
  read -p "Press any key to continue..."
  echo '################ Getting information on previously created network'
  curl -v -X GET $NETWORK_LOCATION
  echo ""
  read -p "Press any key to continue..."
  echo '################ Delete previously created network'
  echo ${NETWORK_LOCATION:17}
  HTTP_CODE=`curl -s -w "%{http_code}" -X DELETE ${NETWORK_LOCATION:17}`
  if [ "$HTTP_CODE" = 200 ]; then
    echo "################ Successfully deleted network"
  else
    echo "################ Deleting network failed."
  fi
  echo ""
  read -p "Press any key to exit test."
}

function crud_storage {
  echo '################ Creating storage'
  case $CONTENT_TYPE in
  'text/occi')
    STORAGE_LOCATION=`curl -v -X POST  --form "file=@$IMAGE_PATH" --header "Accept: $ACCEPT" --header "Category: $STOR_CATEGORY" --header "X-OCCI-Attribute: $STOR_ATTRIBUTE" $STOR_LOCATION`
    ;;
  'text/plain')
    BODY="Category: $STOR_CATEGORY
X-OCCI-Attribute: $STOR_ATTRIBUTE"
    STORAGE_LOCATION=`curl -v -X POST --form "occi=$BODY" --form "file=@$IMAGE_PATH" --header "Accept: $ACCEPT" --header "Category: $STOR_CATEGORY" $STOR_LOCATION`
    ;;
  esac
  if [ "$STORAGE_LOCATION" = "" ]; then 
    echo '################  Storage creation failed, exiting.'
    exit
  else
    echo '################  Storage created successful'
  fi
  echo $STORAGE_LOCATION
  read -p "Press any key to continue..."
  echo '################ Getting all storage URIs'
  curl -v -X GET $URI/storage/
  echo ""
  read -p "Press any key to continue..."
  echo '################ Getting information on previously created storage'
  curl -v -X GET $STORAGE_LOCATION
  echo ""
  read -p "Press any key to continue..."
  echo '################ Delete previously created storage'
  echo ${STORAGE_LOCATION:17}
  HTTP_CODE=`curl -s -w "%{http_code}" -X DELETE ${STORAGE_LOCATION:17}`
  if [ "$HTTP_CODE" = 200 ]; then
    echo "################ Successfully deleted storage"
  else
    echo "################ Deleting storage failed."
  fi
  echo ""
  read -p "Press any key to exit test."
}

function crud_compute {
  echo '################ Creating compute'
  case $CONTENT_TYPE in
  'text/occi')
    echo '################ Creating network'
    NETWORK_LOCATION=`curl -vs -X POST --header "Content-Type: $CONTENT_TYPE" --header "Accept: $ACCEPT" --header "Category: $NET_CATEGORY" --header "X-OCCI-Attribute: $NET_ATTRIBUTE" $NET_LOCATION`
    read -p "Press any key to continue..."
    echo '################ Creating storage'
    STORAGE_LOCATION=`curl -v -X POST  --form "file=@$IMAGE_PATH" --header --header "Accept: $ACCEPT" --header "Category: $STOR_CATEGORY" --header "X-OCCI-Attribute: $STOR_ATTRIBUTE" $STOR_LOCATION`
    read -p "Press any key to continue..."
    echo '################ Creating compute'
    COM_LINK="<${NETWORK_LOCATION#*$URI}>"';rel="http://schemas.ogf.org/occi/infrastructure#network";category="http://schemas.ogf.org/occi/core#link";,'
    COM_LINK+="<${STORAGE_LOCATION#*$URI}>"';rel="http://schemas.ogf.org/occi/infrastructure#storage";category="http://schemas.ogf.org/occi/core#link";'
    COMPUTE_LOCATION=`curl -vs -X POST --header "Content-Type: $CONTENT_TYPE" --header "Accept: $ACCEPT" --header "Link: $COM_LINK" --header "Category: $COM_CATEGORY" --header "X-OCCI-Attribute: $COM_ATTRIBUTE" $COM_LOCATION`
    ;;
  'text/plain')
    BODY="Category: $COMPUTE_CATEGORY
X-OCCI-Attribute: $COMPUTE_ATTRIBUTE
Link: $COM_LINK"
    COMPUTE_LOCATION=`curl -vs -X POST --form "occi=$BODY" --header "Accept: $ACCEPT" --header "Category: $COMPUTE_CATEGORY" $COM_LOCATION`
    ;;
  esac
  if [ "$COMPUTE_LOCATION" = "" ]; then exit;fi 
  echo '################  Compute created successful'
  echo $COMPUTE_LOCATION
  read -p "Press any key to continue..."
  echo '################ Getting all compute URIs'
  curl -v -X GET $URI/compute/
  echo ""
  read -p "Press any key to continue..."
  echo '################ Getting information on previously created compute'
  curl -v -X GET $COMPUTE_LOCATION
  echo ""
  read -p "Press any key to continue..."
  echo '################ Delete previously created compute'
  echo ${COMPUTE_LOCATION:17}
  HTTP_CODE=`curl -s -w "%{http_code}" -X DELETE ${COMPUTE_LOCATION:17}`
  if [ "$HTTP_CODE" = 200 ]; then
    echo "################ Successfully deleted compute"
  else
    echo "################ Deleting compute failed."
  fi
  echo ""
  HTTP_CODE=`curl -s -w "%{http_code}" -X DELETE ${NETWORK_LOCATION:17}`
  if [ "$HTTP_CODE" = 200 ]; then
    echo "################ Successfully deleted network"
  else
    echo "################ Deleting compute network."
  fi
  echo ""
  read -p "Press any key to exit test."
}

function crud_compute_cdmi {
  echo '################ Creating compute with CDMI'
  case $CONTENT_TYPE in
  'text/occi')
    echo '################ Creating network'
    NETWORK_LOCATION=`curl -vs -X POST --header "Content-Type: $CONTENT_TYPE" --header "Accept: $ACCEPT" --header "Category: $NET_CATEGORY" --header "X-OCCI-Attribute: $NET_ATTRIBUTE" $NET_LOCATION`
    read -p "Press any key to continue..."
    echo '################ Creating compute'
    COM_LINK="<${NETWORK_LOCATION#*$URI}>"';rel="http://schemas.ogf.org/occi/core#link";category="http://schemas.ogf.org/occi/infrastructure#networkinterface";occi.networkinterface.mac="00:11:22:33:44:55";occi.networkinterface.interface="eth0";'
    COM_LINK+=",<$CDMI_OBJECT_URI>"';rel="http://schemas.ogf.org/occi/core#link";category="http://schemas.ogf.org/occi/infrastructure#storagelink";'"occi.storagelink.deviceid=\"$CDMI_CONTAINER_ID\";"
    COMPUTE_LOCATION=`curl -vs -X POST --header "Content-Type: $CONTENT_TYPE" --header "Accept: $ACCEPT" --header "Link: $COM_LINK" --header "Category: $COM_CATEGORY" --header "X-OCCI-Attribute: $COM_ATTRIBUTE" $COM_LOCATION`
    ;;
  'text/plain')
	  echo '################ Creating network'
		NET_BODY="Category: $NET_CATEGORY
X-OCCI-Attribute: $NET_ATTRIBUTE"
		NETWORK_LOCATION=`curl -vs -X POST --form "occi=$NET_BODY" --header "Content-Type: $CONTENT_TYPE" --header "Accept: $ACCEPT" --header "Category: $NET_CATEGORY" $NET_LOCATION`
		read -p "Press any key to continue..."
		echo '################ Creating compute'
		COM_LINK="<${NETWORK_LOCATION#*$URI}>"';rel="http://schemas.ogf.org/occi/core#link";category="http://schemas.ogf.org/occi/infrastructure#networkinterface";occi.networkinterface.mac="00:11:22:33:44:55";occi.networkinterface.interface="eth0";'
		COM_LINK+=",<$CDMI_OBJECT_URI>"';rel="http://schemas.ogf.org/occi/core#link";category="http://schemas.ogf.org/occi/infrastructure#storagelink";'"occi.storagelink.deviceid=\"$CDMI_CONTAINER_ID\";"
    COM_BODY="Category: $COM_CATEGORY
X-OCCI-Attribute: $COM_ATTRIBUTE
Link: $COM_LINK"
    COMPUTE_LOCATION=`curl -vs -X POST --form "occi=$COM_BODY" --header "Accept: $ACCEPT" --header "Category: $COM_CATEGORY" $COM_LOCATION`
    ;;
  esac
  if [ "$COMPUTE_LOCATION" = "" ]; then exit;fi
  echo '################  Compute created successful'
  echo $COMPUTE_LOCATION
  read -p "Press any key to continue..."
  echo '################ Getting all compute URIs'
  curl -v -X GET $URI/compute/
  echo ""
  read -p "Press any key to continue..."
  echo '################ Getting information on previously created compute'
  curl -v -X GET $COMPUTE_LOCATION
  echo ""
  read -p "Press any key to continue..."
  echo '################ Delete previously created compute'
  echo ${COMPUTE_LOCATION:17}
  HTTP_CODE=`curl -s -w "%{http_code}" -X DELETE ${COMPUTE_LOCATION:17}`
  if [ "$HTTP_CODE" = 200 ]; then
    echo "################ Successfully deleted compute"
  else
    echo "################ Deleting compute failed."
  fi
  echo ""
  HTTP_CODE=`curl -s -w "%{http_code}" -X DELETE ${NETWORK_LOCATION:17}`
  if [ "$HTTP_CODE" = 200 ]; then
    echo "################ Successfully deleted network"
  else
    echo "################ Deleting compute network."
  fi
  echo ""
  read -p "Press any key to exit test."
}

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
