# dtrctl

A tool that can do different kinds of operations to a Docker Trusted Registry. Some of these tasks include:

- Pulling a DTR's org, repo, and team structure locally to inspect
- Syncing org, repo, team, and repo access rights from a source DTR to a destination DTR
- Syncing images from a source DTR to a destination DTR
- Printing out a map of a DTR's team to repo memberships

### Usage
```
./dtrctl.sh --help

Usage: dtrctl COMMAND(s)
Pronounced: dtr-control

Options


-s, --source-metadata  Pull org, repo, team, and team access metadata from source DTR and store locally
-p, --push-metadata    Push org, repo, team, and team access metadata from local source to dest DTR
-i, --image-sync       Pull images from source DTR and push to dest DTR
-a, --print-access     Print mapping of access rights between teams and repos
--help                 Print usage
```

### Configuration file format

```
## PARAMETERS to reach the SRC DTR
SRC_DTR_URL=
SRC_DTR_USER=
SRC_DTR_PASSWORD=
SRC_NO_OF_REPOS=1000 #Default value

## PARAMETERS to reach the DESTINATION DTR
DEST_DTR_URL=
DEST_DTR_USER=
DEST_DTR_PASSWORD=
```

Requirements

## Examples

### Pulling the metadata locally

The `-s` flag will sync the source DTR metadata locally. The metadata will be placed in the container at `/dtrsync` which can be mounted locally.


```
docker run --rm -it \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /etc/docker:/etc/docker \
-v ~/dtrsync:/dtrsync \
--env-file conf.env \
chrch/dtrctl -s 
```

The following volumes are required so that Docker can function inside the contianer.
```
-v /var/run/docker.sock:/var/run/docker.sock \
-v /etc/docker:/etc/docker
```

The following volumes are configureable and specify the output location of the DTR metadata and also the location of the configuration env variables.

```
-v ~/dtrsync:/dtrsync \
--env-file conf.env \
```

Once the metadata is pulled locally its structure will look like this:

```
$ tree ~/dtrsync/
├── docker-datacenter
│   ├── repoConfig
│   └── teamConfig
├── org1
│   ├── repoConfig
│   ├── t1
│   │   ├── members
│   │   └── repoAccess
│   ├── t2
│   │   ├── members
│   │   └── repoAccess
│   └── teamConfig
├── org2
│   ├── repoConfig
│   └── teamConfig
├── org3
│   ├── repoConfig
│   ├── t3
│   │   ├── members
│   │   └── repoAccess
│   └── teamConfig
├── orgConfig
└── orgList
...
```

### Push org/team/repo metadata to dest DTR

```
docker run --rm -it \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /etc/docker:/etc/docker \
-v ~/dtrsync:/dtrsync \
--env-file conf.env \
chrch/dtrctl -p
```

### Sync org metadata and images from a source DTR to a destination DTR

```
docker run --rm -it \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /etc/docker:/etc/docker \
-v ~/dtrsync:/dtrsync \
--env-file conf.env \
chrch/dtrctl -i
```


### Develop dtrctl locally
```
$ git clone https://github.com/mark-church/dtrctl.git

$ cd ~/dtrctl

$ docker run --rm -it \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /etc/docker:/etc/docker \
-v ~/dtrsync:/dtrsync \
--env-file conf.env \
-v ~/dtrctl:/dtrctl \
chrch/dtrctl
```


