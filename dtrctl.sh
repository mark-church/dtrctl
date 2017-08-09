#!/bin/bash

main() {
    authenticate

    if [ ! "$SKIP_SYNC" ]; then
        getOrgs
        getRepos
        getTeams
        getTeamMembers
        getTeamRepoAccess
    fi

    if [ "$SYNC_ORG" ]; then
        putOrgs
        putRepos
        putTeams
        putTeamMembers
        putTeamRepoAccess
    fi

    if [ "$SYNC_IMAGES" ]; then
        migrateImages
    fi 

    if [ "$PRINT_ACCESS" ]; then
        printAccessMap
    fi
}

authenticate() {
    docker login "$SRC_DTR_URL" -u "$SRC_DTR_USER" -p "$SRC_DTR_PASSWORD"
    SRC_DTR_TOKEN=$(cat ~/.docker/config.json | jq -r ".auths[\"$SRC_DTR_URL\"].identitytoken")

    docker login "$DEST_DTR_URL" -u "$DEST_DTR_USER" -p "$DEST_DTR_PASSWORD"
    DEST_DTR_TOKEN=$(cat ~/.docker/config.json | jq -r ".auths[\"$DEST_DTR_URL\"].identitytoken")
}



########################### 
#             GET         #
###########################

getOrgs() {
    curl -s --insecure \
    https://"$SRC_DTR_URL"/enzi/v0/accounts?refresh_token="$SRC_DTR_TOKEN" | \
    jq -c '.accounts[] | select(.isOrg==true) | {name: .name, fullName: .fullName, isOrg: .isOrg}' \
    > orgConfig

    cat orgConfig | jq -r '.name' > orgList

    cat orgList | while IFS= read -r i;
    do
        if [ ! -d ./$i ]; then
            mkdir ./$i
        fi
    done
}

getRepos() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        curl -s --insecure \
        https://"$SRC_DTR_URL"/api/v0/repositories/$i?refresh_token="$SRC_DTR_TOKEN" | \
        jq '.repositories[] | {name: .name, shortDescription: .shortDescription, longDescription: "", visibility: .visibility}' \
        > ./$i/repoConfig
    done
}


getTeams() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        curl -s --insecure \
        https://"$SRC_DTR_URL"/enzi/v0/accounts/$i/teams?refresh_token="$SRC_DTR_TOKEN" | jq -c '.teams[] | {name: .name, description: .description}' > ./$i/teamConfig

        cat ./$i/teamConfig | while IFS= read -r j;
        do     
            if [ ! -d ./$i/$(echo $j | jq -r '.name') ]; then
                mkdir ./$i/$(echo $j | jq -r '.name')
            fi
        done
    done
}

getTeamMembers() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./$i/teamConfig | jq -r '.name' | while IFS= read -r j;
        do
            curl -s --insecure \
            https://"$SRC_DTR_URL"/enzi/v0/accounts/${i}/teams/${j}/members?refresh_token="$SRC_DTR_TOKEN" | jq -c '.members[] | {name: .member.name, isAdmin: .isAdmin, isPublic: .isPublic}' \
            > ./$i/$j/members
        done
    done
}


getTeamRepoAccess() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./$i/teamConfig | jq -r '.name' | while IFS= read -r j;
        do
            curl -s --insecure \
            https://"$SRC_DTR_URL"/api/v0/accounts/${i}/teams/${j}/repositoryAccess?refresh_token="$SRC_DTR_TOKEN" | jq -c '.repositoryAccessList[]' > ./$i/$j/repoAccess
        done
    done
}



########################### 
#             PUT         #
###########################

putOrgs() {
    cat orgConfig | while IFS= read -r i;
    do
        curl --insecure -X POST --header "Content-Type: application/json" \
         --header "Accept: application/json" -d "$i" https://"$DEST_DTR_URL"/enzi/v0/accounts?refresh_token="$DEST_DTR_TOKEN" 
    done
}




putRepos() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./$i/repoConfig | jq -c '.' | while IFS= read -r j;
        do
            curl --insecure -X POST --header "Content-Type: application/json" \
            --header "Accept: application/json" -d "$j" https://"$DEST_DTR_URL"/api/v0/repositories/${i}?refresh_token="$DEST_DTR_TOKEN"
        done
    done
}



putTeams() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        curl -s --insecure \
        https://"$SRC_DTR_URL"/enzi/v0/accounts/$i/teams?refresh_token="$SRC_DTR_TOKEN" | jq -c '.teams[] | {name: .name, description: .description}' > ./$i/teamConfig

        cat ./$i/teamConfig | while IFS= read -r j;
        do
            curl --insecure -X POST --header "Content-Type: application/json" \
                --header "Accept: application/json" -d "$j" https://"$DEST_DTR_URL"/enzi/v0/accounts/${i}/teams?refresh_token="$DEST_DTR_TOKEN"
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
                curl --insecure -X PUT --header "Content-Type: application/json" \
                    --header "Accept: application/json" -d "$k" https://"$DEST_DTR_URL"/enzi/v0/accounts/${i}/teams/${j}/members/${teamMemberName}?refresh_token="$DEST_DTR_TOKEN"
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
    docker login "$SRC_DTR_URL" --username "$SRC_DTR_USER" --password "$SRC_DTR_PASSWORD";
    docker login "$DEST_DTR_URL" --username "$SRC_DTR_USER" --password "$SRC_DTR_PASSWORD";
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./$i/repoConfig | jq -c -r '.name' | while IFS= read -r j;
        do
            TAGS=$(curl -s --insecure \
            https://"$SRC_DTR_URL"/api/v0/repositories/${i}/${j}/tags | jq -c -r '.[].name')
            
            for k in $TAGS;  
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


usage() {
    echo ""
    echo "Usage: dtrctl -c [confguration file] COMMAND"
    echo "Pronounced: dee-tee-arr-cuttle"
    echo ""
    echo "Options"
    echo ""
    echo "-c, --config           Set configuration file that contians env variable assignments for src and dest DTRs"
    echo "-o, --sync-org      Migrate orgs, repos, teams, and access rights from src to dest DTR"
    echo "-i, --sync-image    Migrate all images from src to dest DTR"
    echo "-p, --print-access     Print mapping of access rights between teams and repos"
    echo "-s, --skip-sync        Skip sync with source DTR"
    echo "--help                 Print usage"
    echo ""
}



## Parse arguments
while [[ $# -gt 0 ]]
do
    case "$1" in
        -o|--sync-org)
        SYNC_ORG=1
        shift 1
        ;;

        -i|--sync-images)
        SYNC_IMAGES=1
        shift 1
        ;;

        -p|--print-access)
        PRINT_ACCESS=1
        shift 1
        ;;

        -c|--config)
        CONFIG_PATH="$2"
        source "$CONFIG_PATH"
        shift 2
        ;;

        -s|--skip-sync)
        SKIP_SYNC=1
        shift 1
        ;;

        -h|--help)
        usage
        exit 1
        ;;

        *)  
        echo "Unknown argument: $1"
        usage
        exit 1
        ;;

    esac
done

#Entrypoint for program
main






