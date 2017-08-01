#!/bin/bash

#############################################################

## PARAMETERS to reach the SRC DTR
SRC_DTR_URL=dtr2.church.dckr.org
SRC_DTR_USER=admin
SRC_DTR_PASSWORD=docker123
SRC_NO_OF_REPOS=100

## PARAMETERS to reach the DESTINATION DTR
DEST_DTR_URL=dtr2.church.dckr.org
DEST_DTR_USER=admin
DEST_DTR_PASSWORD=docker123

#############################################################


main() {
    getOrgs
    getRepos
    getTeams
    getTeamMembers
    getTeamRepoAccess

    if [ "$MIGRATE_ORG" ]; then
        putOrgs
        putTeams
        putTeamMembers
        putTeamRepoAccess
    fi

    if [ "$MIGRATE_IMAGES" ]; then
        migrateImages
    fi 

    if [ "$PRINT_ACCESS" ]; then
        printAccessMap
    fi


}





########################### 
#             GET         #
###########################

getOrgs() {
    curl -s --user \
    "$SRC_DTR_USER":"$SRC_DTR_PASSWORD" --insecure \
    https://"$SRC_DTR_URL"/enzi/v0/accounts?limit=$SRC_NO_OF_REPOS | \
    jq -c '.accounts[] | select(.isOrg==true) | {name: .name, fullName: .fullName, isOrg: .isOrg}' \
    > orgConfig

    cat orgConfig | jq -r '.name' > orgList

    cat orgList | while IFS= read -r i;
    do
        mkdir ./$i
    done
}

getRepos() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        curl -s --user "$SRC_DTR_USER":"$SRC_DTR_PASSWORD" --insecure \
        https://"$SRC_DTR_URL"/api/v0/repositories/$i | \
        jq '.repositories[] | {name: .name, shortDescription: .shortDescription, longDescription: "", visibility: .visibility}' \
        > ./$i/repoConfig
    done
}


getTeams() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        curl -s --user "$SRC_DTR_USER":"$SRC_DTR_PASSWORD" --insecure \
        https://"$SRC_DTR_URL"/enzi/v0/accounts/$i/teams | jq -c '.teams[] | {name: .name, description: .description}' > ./$i/teamConfig

        cat ./$i/teamConfig | while IFS= read -r j;
        do
            mkdir ./$i/$(echo $j | jq -r '.name')
        done
    done
}

getTeamMembers() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./$i/teamConfig | jq -r '.name' | while IFS= read -r j;
        do
            curl -s --user "$SRC_DTR_USER":"$SRC_DTR_PASSWORD" --insecure \
            https://"$SRC_DTR_URL"/enzi/v0/accounts/${i}/teams/${j}/members | jq -c '.members[] | {name: .member.name, isAdmin: .isAdmin, isPublic: .isPublic}' \
            > ./$i/$j/members
        done
    done
}


getTeamRepoAccess() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./$i/teamConfig | jq -r '.name' | while IFS= read -r j;
        do
            curl -s --user "$SRC_DTR_USER":"$SRC_DTR_PASSWORD" --insecure \
            https://"$SRC_DTR_URL"/api/v0/accounts/${i}/teams/${j}/repositoryAccess | jq -c '.repositoryAccessList[]' > ./$i/$j/repoAccess
        done
    done
}



########################### 
#             PUT         #
###########################

putOrgs() {
    cat orgConfig | while IFS= read -r i;
    do
        curl --insecure --user "$DEST_DTR_USER":"$DEST_DTR_PASSWORD" -X POST --header "Content-Type: application/json" \
         --header "Accept: application/json" -d "$i" https://"$DEST_DTR_URL"/enzi/v0/accounts 
    done
}




putRepos() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./$i/repoConfig | jq -c '.' | while IFS= read -r j;
        do
            curl --insecure --user "$DEST_DTR_USER":"$DEST_DTR_PASSWORD" -X POST --header "Content-Type: application/json" \
            --header "Accept: application/json" -d "$j" https://"$DEST_DTR_URL"/api/v0/repositories/${i}
        done
    done
}



putTeams() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        curl -s --user "$SRC_DTR_USER":"$SRC_DTR_PASSWORD" --insecure \
        https://"$SRC_DTR_URL"/enzi/v0/accounts/$i/teams | jq -c '.teams[] | {name: .name, description: .description}' > ./$i/teamConfig

        cat ./$i/teamConfig | while IFS= read -r j;
        do
            curl --insecure --user "$DEST_DTR_USER":"$DEST_DTR_PASSWORD" -X POST --header "Content-Type: application/json" \
                --header "Accept: application/json" -d "$j" https://"$DEST_DTR_URL"/enzi/v0/accounts/${i}/teams
        done
    done

}




putTeamMembers() {
    #Responds with 200 even though team members already exist (I guess this is because of PUT)
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./$i/teamConfig | jq -r '.name' | while IFS= read -r j;
        do
            cat ./$i/$j | jq -c '{isAdmin: .isAdmin, isPublic: .isPublic}' | while IFS= read -r k;
            do
                teamMemberName=$(cat ./$i/$j | jq -c -r .name)
                curl -v --insecure --user "$DEST_DTR_USER":"$DEST_DTR_PASSWORD" -X PUT --header "Content-Type: application/json" \
                    --header "Accept: application/json" -d "$k" https://"$DEST_DTR_URL"/enzi/v0/accounts/${i}/teams/${j}/members/${teamMemberName}
            done
        done
    done
}

putTeamRepoAccess() {
    echo "putTeamRepoAccess"
}

########################### 
#        PUSH IMAGES      #
###########################

migrateImages() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./$i/repoConfig | jq -c -r '.name' | while IFS= read -r j;
        do
            TAGS=$(curl -s --user "$SRC_DTR_USER":"$SRC_DTR_PASSWORD" --insecure \
            https://"$SRC_DTR_URL"/api/v0/repositories/${i}/${j}/tags | jq -c -r '.[].name')
            
            echo "$TAGS" | jq -c -r '.' | while IFS= read -r k;
            do
                docker pull "$SRC_DTR_URL/$i/$j:$k"
                docker tag "$SRC_DTR_URL/$i/$j:$k" "$DEST_DTR_URL/$i/$j:$k"
                docker push "$DEST_DTR_URL/$i/$j:$k"
            done
            
            #Clean up images after each repo
            #docker image prune -af
        done
        #Clean up images after each Org
        docker image prune -af
    done
}




printAccessMap() {
    echo "Printing Team and Repo Access"
    cat orgList | sort -u | while IFS= read -r i;
    do
        echo "$i"
        echo "-------------------------"
        cat ./$i/teamConfig | jq -r '.name' | while IFS= read -r j;
        do
            echo "  $j Members"
            cat ./$i/$j/members | while IFS= read -r member;
            do
                if [ $(echo $member | jq '.isAdmin') == 'true' ]
                then
                    access="Admin"
                else
                    access="Member"
                fi

                echo "     " $(echo $member | jq -r .name) "-"  "$access"
            done


            echo "  $j Repository Access"
            cat ./$i/$j/repoAccess | while IFS= read -r access;
            do
                repoName=$(echo $access | jq -r '.repository.name')
                accessLevel=$(echo $access | jq -r '.accessLevel')
                echo "     $i/$repoName - $accessLevel"
            done
            echo ""
        done
        echo ""
    done
}


help() {
    echo "help"
}



## Parse arguments
while [[ $# -gt 0 ]]
do
    case "$1" in
        -o|--migrate-org)
        MIGRATE_ORG=1
        shift 1
        ;;

        -i|--migrate-images)
        MIGRATE_IMAGES=1
        shift 1
        ;;

        -a|--print-access-map)
        PRINT_ACCESS=1
        shift 1
        ;;

        -c|--config)
        CONFIG_PATH="$2"
        source "$CONFIG_PATH"
        shift 2
        ;;

        --src-dtr)
        SRC_DTR_URL="$2"
   #     if [[ $SRC_DTR_URL == "" ]]; then break; fi
        shift 2
        ;;

        --src-dtr)
        SRC_DTR_URL="$2"
   #     if [[ $SRC_DTR_URL == "" ]]; then break; fi
        shift 2
        ;;

        --dest-dtr)
        DEST_DTR_URL="$2"
  #      if [[ $DEST_DTR_URL == "" ]]; then break; fi
        shift 2
        ;;

        --help)
        help
        break
        ;;

        *)  
        echo "Unknown argument: $1"
        help
        break
        ;;

    esac
done

#Entrypoint for program
main






