# dtrctl

A tool that can do different kinds of operations to a Docker Trusted Registry. Some of these tasks include:

- Pulling a DTR's org, repo, and team structure locally to inspect
- Syncing org, repo, team, and repo access rights from a source DTR to a destination DTR
- Syncing images from a source DTR to a destination DTR
- Printing out a map of a DTR's team to repo memberships

### Usage
```
./dtrctl.sh --help

Usage: dtrctl -c [confguration file] COMMAND
Pronounced: dee-tee-arr-cuttle

Options

-c, --config           Set configuration file that contians env variable assignments for src and dest DTRs
-o, --migrate-org      Migrate orgs, repos, teams, and access rights from src to dest DTR
-i, --migrate-image    Migrate all images from src to dest DTR
-p, --print-access     Print mapping of access rights between teams and repos
-s, --skip-sync        Skip sync with source DTR
--help
```

### Configuration file format

```
## PARAMETERS to reach the SRC DTR
SRC_DTR_URL=<dtr1-url>
SRC_DTR_USER=<user>
SRC_DTR_PASSWORD=<password>
SRC_NO_OF_REPOS=100

## PARAMETERS to reach the DESTINATION DTR
DEST_DTR_URL=<dtr2-url>
DEST_DTR_USER=<user>
DEST_DTR_PASSWORD=<password>
```

## Examples

### Pulling the metadata locally
```
$ ./dtrctl.sh -c conf.txt
$ tree
.
├── conf
├── docker-datacenter
│   ├── repoConfig
│   ├── sdsfdf
│   │   ├── members
│   │   └── repoAccess
│   └── teamConfig
├── org1
│   ├── repoConfig
│   ├── team1
│   │   ├── members
│   │   └── repoAccess
│   ├── team2
│   │   ├── members
│   │   └── repoAccess
│   ├── team3
│   │   ├── members
│   │   └── repoAccess
│   └── teamConfig
├── org2
│   ├── repoConfig
│   ├── team1
...
```

### Sync org metadata from a source DTR to a destination DTR

```
$ ./dtrctl.sh -c conf --sync-org
```

### Sync org metadata and images from a source DTR to a destination DTR

```
$ ./dtrctl.sh -c conf --sync-org --sync-images
```
