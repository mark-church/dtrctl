getOrgs() {
    #Won't pick up orgs unless they have a repo underneath them
  curl -s --user \
    "$SOURCE_DTR_ADMIN":"$SOURCE_DTR_PASSWORD" --insecure \
    https://"$SOURCE_DTR_DOMAIN"/api/v0/repositories?limit=$SOURCE_NO_OF_REPOS | \
      jq '.repositories[] | { (.namespaceType):(.namespace)  }' | grep -v '[{}]' | grep -v admin | sort -u > orgs
}

createOrgs() {
  sed -e '/"organization":/s/^\s*"\(.*\)":\s*"\(.*\)"/{"name": "\2", "isOrg": true}/' \
          orgs > dest_orgs

  cat dest_orgs | sort -u | while IFS= read -r i;  
    do
      curl --insecure --user "$DEST_DTR_ADMIN":"$DEST_DTR_PASSWORD" -X POST --header "Content-Type: application/json" \
         --header "Accept: application/json" -d "$i" https://"$DEST_DTR_DOMAIN"/enzi/v0/accounts
    done

}

getCreateOrgRepos() {

    mkdir dtrOrgs

    cat orgs | sed 's/\<organization\>//g' | sed 's/[": ]//g' > orgList

    cat orgList | sort -u | while IFS= read -r i;
        do
            curl -s --user "$SOURCE_DTR_ADMIN":"$SOURCE_DTR_PASSWORD" --insecure \
            https://"$SOURCE_DTR_DOMAIN"/api/v0/repositories/$i | \
            jq '.repositories[] | {name: .name, shortDescription: .shortDescription, longDescription: "", visibility: .visibility}' \
            > ./dtrOrgs/$i


            cat ./dtrOrgs/$i | jq -c '.' | while IFS= read -r j;
            do
                curl --insecure --user "$DEST_DTR_ADMIN":"$DEST_DTR_PASSWORD" -X POST --header "Content-Type: application/json" \
                --header "Accept: application/json" -d "$j" https://"$DEST_DTR_DOMAIN"/api/v0/repositories/${i}
            done
        done
}


getPutTeams() {
    mkdir teams
    cat orgList | sort -u | while IFS= read -r i;
        do
            echo $i
            curl -s --user "$SOURCE_DTR_ADMIN":"$SOURCE_DTR_PASSWORD" --insecure \
            https://"$SOURCE_DTR_DOMAIN"/enzi/v0/accounts/$i/teams | jq -c '.teams[] | {name: .name, description: .description}' > ./teams/$i
        done

    ls teams | tr '\n' '\n' | while IFS= read -r i;
    do
        cat ./teams/$i | while IFS= read -r j;
        do
            curl --insecure --user "$DEST_DTR_ADMIN":"$DEST_DTR_PASSWORD" -X POST --header "Content-Type: application/json" \
                --header "Accept: application/json" -d "$j" https://"$DEST_DTR_DOMAIN"/enzi/v0/accounts/${i}/teams
        done
    done

}

echo "Save orgs to file"
getOrgs


echo "Format and create orgs"
createOrgs

echo "Get and create org repos"
createOrgRepos



