# RegulonDB-APP

# Description
RegulonDB 12 Integration source code

# Minimal System Requirements
- 8GB RAM
- 60GB Storage
- Docker

# Install

When this repo is cloned the submodules will be pulled, in case of this not occurs please use the following commands in project's terminal:

```cmd
git submodule init
git submodule update --recursive
```

In order to start the containers use:

```cmd
docker compose build --no-cache
docker compose start
```

Use the following command to stop containers
```cmd
docker compose stop
```

Or you can use the following command to stop and remove containers
```cmd
docker compose down --rmi all -v
```

# Maintenance

When an updated is obtained by a pull, use the _git submodule update --recursive_ to update submodules (just when a new release is pushed).
