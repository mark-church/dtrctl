#!/bin/bash

#############################################################

## PARAMETERS to reach the SOURCE DTR
SOURCE_DTR_DOMAIN=dtr.church.dckr.org
SOURCE_DTR_ADMIN=admin
SOURCE_DTR_PASSWORD=docker123
SOURCE_NO_OF_REPOS=100

## PARAMETERS to reach the DESTINATION DTR
DEST_DTR_DOMAIN=dtr.church.dckr.org
DEST_DTR_ADMIN=admin
DEST_DTR_PASSWORD=docker123

#############################################################

main() {
    mkdir orgs
    getOrgs
    getPutRepos
}

getOrgs() {
    curl -s --user \
    "$SOURCE_DTR_ADMIN":"$SOURCE_DTR_PASSWORD" --insecure \
    https://"$SOURCE_DTR_DOMAIN"/enzi/v0/accounts?limit=$SOURCE_NO_OF_REPOS | \
    jq -c '.accounts[] | select(.isOrg==true) | {name: .name, fullName: .fullName, isOrg: .isOrg}' \
    > orgConfig

    cat orgConfig | jq -r '.name' > orgList

    cat orgList | while IFS= read -r i;
    do
        mkdir ./orgs/$i
    done
}

createOrgs() {
    cat orgConfig | while IFS= read -r i;
    do
        curl --insecure --user "$DEST_DTR_ADMIN":"$DEST_DTR_PASSWORD" -X POST --header "Content-Type: application/json" \
         --header "Accept: application/json" -d "$i" https://"$DEST_DTR_DOMAIN"/enzi/v0/accounts 
    done
}

getPutRepos() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        curl -s --user "$SOURCE_DTR_ADMIN":"$SOURCE_DTR_PASSWORD" --insecure \
        https://"$SOURCE_DTR_DOMAIN"/api/v0/repositories/$i | \
        jq '.repositories[] | {name: .name, shortDescription: .shortDescription, longDescription: "", visibility: .visibility}' \
        > ./orgs/$i/repoConfig


        cat ./orgs/$i/repoConfig | jq -c '.' | while IFS= read -r j;
        do
            curl --insecure --user "$DEST_DTR_ADMIN":"$DEST_DTR_PASSWORD" -X POST --header "Content-Type: application/json" \
            --header "Accept: application/json" -d "$j" https://"$DEST_DTR_DOMAIN"/api/v0/repositories/${i}
        done
    done
}

getPutTeams() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        curl -s --user "$SOURCE_DTR_ADMIN":"$SOURCE_DTR_PASSWORD" --insecure \
        https://"$SOURCE_DTR_DOMAIN"/enzi/v0/accounts/$i/teams | jq -c '.teams[] | {name: .name, description: .description}' > ./orgs/$i/teamConfig

        cat ./orgs/$i/teamConfig | while IFS= read -r j;
        do
            mkdir ./orgs/$i/$(echo $j | jq -r '.name')
            curl --insecure --user "$DEST_DTR_ADMIN":"$DEST_DTR_PASSWORD" -X POST --header "Content-Type: application/json" \
                --header "Accept: application/json" -d "$j" https://"$DEST_DTR_DOMAIN"/enzi/v0/accounts/${i}/teams

        done
    done
}


getTeamMembers() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./orgs/$i/teamConfig | jq -r '.name' | while IFS= read -r j;
        do
            curl -s --user "$SOURCE_DTR_ADMIN":"$SOURCE_DTR_PASSWORD" --insecure \
            https://"$SOURCE_DTR_DOMAIN"/enzi/v0/accounts/${i}/teams/${j}/members | jq -c '.members[] | {name: .member.name, isAdmin: .isAdmin, isPublic: .isPublic}' \
            > ./orgs/$i/$j/members
        done
    done
}

putTeamMembers() {
    #Responds with 200 even though team members already exist (I guess this is because of PUT)
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./orgs/$i/teamConfig | jq -r '.name' | while IFS= read -r j;
        do
            cat ./orgs/$i/$j | jq -c '{isAdmin: .isAdmin, isPublic: .isPublic}' | while IFS= read -r k;
            do
                teamMemberName=$(cat ./orgs/$i/$j | jq -c -r .name)
                curl -v --insecure --user "$DEST_DTR_ADMIN":"$DEST_DTR_PASSWORD" -X PUT --header "Content-Type: application/json" \
                    --header "Accept: application/json" -d "$k" https://"$DEST_DTR_DOMAIN"/enzi/v0/accounts/${i}/teams/${j}/members/${teamMemberName}
            done
        done
    done
}

getTeamRepoAccess() {
    cat orgList | sort -u | while IFS= read -r i;
    do
        cat ./orgs/$i/teamConfig | jq -r '.name' | while IFS= read -r j;
        do
            curl -s --user "$SOURCE_DTR_ADMIN":"$SOURCE_DTR_PASSWORD" --insecure \
            https://"$SOURCE_DTR_DOMAIN"/api/v0/accounts/${i}/teams/${j}/repositoryAccess | jq -c '.repositoryAccessList[]' > ./orgs/$i/$j/repoAccess
        done
    done
}


putTeamRepoAccess() {}

printTeamRepoAccess() {
    echo "Printing Team and Repo Access"
    cat orgList | sort -u | while IFS= read -r i;
    do
        echo "$i"
        echo "-------------------------"
        cat ./orgs/$i/teamConfig | jq -r '.name' | while IFS= read -r j;
        do
            echo "  $j Members"
            cat ./orgs/$i/$j/members | while IFS= read -r member;
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
            cat ./orgs/$i/$j/repoAccess | while IFS= read -r access;
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



curl -s --user "$SOURCE_DTR_ADMIN":"$SOURCE_DTR_PASSWORD" --insecure \
            https://"$SOURCE_DTR_DOMAIN"/api/v0/accounts/org3/teams/team1/repositoryAccess

curl -v --insecure --user "$DEST_DTR_ADMIN":"$DEST_DTR_PASSWORD" -X PUT --header "Content-Type: application/json" \
                    --header "Accept: application/json" -d '{"accessLevel":"read-only"}' https://"$DEST_DTR_DOMAIN"/api/v0/repositories/org1/fox/teamAccess/team1






