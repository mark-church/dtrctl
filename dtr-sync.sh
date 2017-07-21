getOrgs() {
    curl -s --user \
    "$SOURCE_DTR_ADMIN":"$SOURCE_DTR_PASSWORD" --insecure \
    https://"$SOURCE_DTR_DOMAIN"/enzi/v0/accounts?limit=$SOURCE_NO_OF_REPOS | \
    jq -c '.accounts[] | select(.isOrg==true) | {name: .name, fullName: .fullName, isOrg: .isOrg}' \
    >> orgConfig

    cat orgConfig | jq -r '.name' >> orgList

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
            > ./orgs/$i/$j"-members"
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
            https://"$SOURCE_DTR_DOMAIN"/api/v0/accounts/${i}/teams/${j}/repositoryAccess | jq . > ./orgs/$i/$j"-repoAccess"
        done
    done
}

curl -s --user "$SOURCE_DTR_ADMIN":"$SOURCE_DTR_PASSWORD" --insecure \
            https://"$SOURCE_DTR_DOMAIN"/api/v0/accounts/org3/teams/team1/repositoryAccess

curl -v --insecure --user "$DEST_DTR_ADMIN":"$DEST_DTR_PASSWORD" -X PUT --header "Content-Type: application/json" \
                    --header "Accept: application/json" -d '{"accessLevel":"read-only"}' https://"$DEST_DTR_DOMAIN"/api/v0/repositories/org1/fox/teamAccess/team1


startup() {
    mkdir orgs
}
echo "Save orgs to file"
getOrgs


echo "Format and create orgs"
createOrgs

echo "Get and create org repos"
createOrgRepos






