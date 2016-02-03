#! /bin/bash

# Copyright 2016 Bryan J. Hong
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# This script generates a general Docker "framework" based on the public Docker Ubuntu LTS image. The
# goal is to create a standardized foundation for building Docker containers to speed up the development
# process. For more detail, see README.md

#### BEGIN VARIABLES

# Base name of the Docker container
APP_NAME=mycontainer

# Remote Docker registry username (Docker Hub)
# Example of a private registry: docker-registry.example.com:5000
REPO_NAME="dockerhub_username"

# Your email address
EMAIL_ADDRESS=user@example.com

# Major version of Ubuntu to build the container with
UBUNTU_MAJOR_VERSION=14

#### END VARIABLES

#### BEGIN VARS HEREDOC
if [[ ! -f vars ]]; then
cat << EOF > vars
#!/bin/bash

#### BEGIN APP SPECIFIC VARIABLES

APP_NAME=${APP_NAME}
REPO_NAME="${REPO_NAME}"

#### END APP SPECIFIC VARIABLES
EOF
cat << 'EOF' >> vars
#### BEGIN GENERIC VARIABLES
  
# Get an SHA sum of all files involved in building the image so the image can be tagged
# this will provide assurance that any image with the same tag was built the same way. 
SHASUM=`find . -type f \
        -not -path "*/.git/*" \
        -not -path "*.gitignore*" \
        -not -path "*builds*" \
        -not -path "*run.sh*" \
        -exec shasum {} + | awk '{print $1}' | sort | shasum | cut -c1-4`
  
TAG="`date +%Y%m%d`-${SHASUM}"

#### END GENERIC VARIABLES
EOF
fi
#### END VARS HEREDOC

#### BEGIN BUILD.SH HEREDOC
if [[ ! -f build.sh ]]; then
cat << 'EOF' > build.sh
#!/bin/bash

source vars

docker build -t "${REPO_NAME}/${APP_NAME}:${TAG}" .

# If the build was successful (0 exit code)...
if [ $? -eq 0 ]; then
  echo
  echo "Build of ${REPO_NAME}/${APP_NAME}:${TAG} completed OK"
  echo

  # log build details to builds file
  echo "`date` => ${REPO_NAME}/${APP_NAME}:${TAG}" >> builds

# The build exited with an error.
else
  echo "Build failed!"
  exit 1

fi
EOF
fi
#### END BUILD.SH HEREDOC

#### BEGIN DOCKERFILE HEREDOC
if [[ ! -f Dockerfile ]]; then
cat << EOF > Dockerfile
FROM ubuntu:${UBUNTU_MAJOR_VERSION}.04

MAINTAINER ${EMAIL_ADDRESS}
EOF
cat << 'EOF' >> Dockerfile

ENV DEBIAN_FRONTEND noninteractive

# Update APT repository and install Supervisor
RUN apt-get -q update \
 && apt-get -y install supervisor

# Install Startup script
COPY assets/startup.sh /opt/startup.sh

# Execute Startup script when container starts
ENTRYPOINT [ "/opt/startup.sh" ]
EOF
fi
#### END DOCKERFILE HEREDOC

#### BEGIN RUN.SH HEREDOC
if [[ ! -f run.sh ]]; then
cat << 'EOF' > run.sh
#!/bin/bash

source vars

#If there is a locally built image present, prefer that over the
#one in the registry, we're going to assume you're working on changes
#to the image.

if [[ ! -f builds ]]; then
  LATESTIMAGE=${REPO_NAME}/${APP_NAME}:latest
else
  LATESTIMAGE=`tail -1 builds | awk '{print $8}'`
fi
echo
echo "Starting $APP_NAME..."
echo
echo -n "Container ID: "
docker run \
--detach=true \
--log-driver=syslog \
--name="${APP_NAME}" \
--restart=always \
${LATESTIMAGE}
# Other useful options
# -p DOCKERHOST_PORT:CONTAINER_PORT \
# -e "ENVIRONMENT_VARIABLE_NAME=VALUE" \
# -v /DOCKERHOST/PATH:/CONTAINER/PATH \
EOF
fi
#### END RUN.SH HEREDOC

#### BEGIN PUSH.SH HEREDOC
if [[ ! -f push.sh ]]; then
cat << 'EOF' > push.sh
#!/bin/bash

source vars

#This will take the latest locally built image and push it to the repository as
#configured in vars and tag it as latest.

if [[ ! -f builds ]]; then
  echo
  echo "It appears that the Docker image hasn't been built yet, run build.sh first"
  echo
  exit 1
fi

LATESTIMAGE=`tail -1 builds | awk '{print $8}'`

# Flatten is here as an option and not the default because with the export/import
# process we lose Dockerfile attributes like PORT and VOLUMES. Flattening helps if
# we are concerned about hitting the AUFS 42 layer limit or creating an image that
# other containers source FROM

DockerExport () {
  docker export ${APP_NAME} | docker import - ${REPO_NAME}/${APP_NAME}:latest
}

DockerPush () {
  docker push ${REPO_NAME}/${APP_NAME}:latest
}

case "$1" in
  flatten)
    docker inspect ${APP_NAME} > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      echo "The ${APP_NAME} container doesn't appear to exist, exiting"
      exit 1
    fi
    RUNNING=`docker inspect ${APP_NAME} | python -c 'import sys, json; print json.load(sys.stdin)[0]["State"]["Running"]'`
    if [[ "${RUNNING}" = "True" ]]; then
      echo "Stopping ${APP_NAME} container for export"
      docker stop ${APP_NAME}
      DockerExport
      DockerPush
    else
      DockerExport
      DockerPush
    fi
    ;;
  *)
    docker tag -f ${LATESTIMAGE} ${REPO_NAME}/${APP_NAME}:latest
    DockerPush
esac
EOF
fi
#### END PUSH.SH HEREDOC

#### BEGIN SHELL.SH HEREDOC
if [[ ! -f shell.sh ]]; then
cat << 'EOF' > shell.sh
#!/bin/bash

source vars

docker inspect ${APP_NAME} > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
  echo "The ${APP_NAME} container doesn't appear to exist, exiting"
fi

CONTAINER_ID=`docker inspect ${APP_NAME} | python -c 'import sys, json; print json.load(sys.stdin)[0]["Id"]'`

docker exec -it ${CONTAINER_ID} /bin/bash
EOF
fi
#### END SHELL.SH HEREDOC

#### BEGIN STARTUP.SH HEREDOC
mkdir -p assets
if [[ ! -f assets/startup.sh ]]; then
cat << 'EOF' > assets/startup.sh
#! /bin/bash

# Start Supervisor
/usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
EOF
fi
#### END STARTUP.SH HEREDOC

#### BEGIN README.MD HEREDOC
if [[ ! -f README.md ]]; then
cat << EOF > README.md
#${APP_NAME} in Docker
EOF
cat << 'EOF' >> README.md

[//]: # (A brief description of the container here)

##Requirements / Dependencies

* Docker 1.6 or higher, we are using the Docker syslog driver in this container and this feature made its debut in 1.6
* ```vars``` needs to be populated with the appropriate variables.

##Commands and variables

* ```vars```: Variables for the application and registry/repository username/location are stored here
* ```build.sh```: Build the Docker image locally for testing
* ```run.sh```: Starts the Docker container, it the image hasn't been built locally, it is fetched from the repository set in vars
* ```push.sh```: Pushes the latest locally built image to the repository set in vars
* ```shell.sh```: get a shell within the container

##Usage

[//]: # (Provide details of what this container does and how it should be deployed and managed)

###Configure the container

1. Configure application specific variables in ```vars```

###Build the image

1. Run ```./build.sh```

###Start the container

1. Run ```./run.sh```

###Pushing your image to the registry

If you're happy with your container and ready to share with others, push your image up to a [Docker registry](https://docs.docker.com/docker-hub/) and backup or save changes you've made so the image can be easily changed or rebuilt in the future.

1. Authenticate to the Docker Registry ```docker login```
2. Run ```./push.sh```
3. Log into your Docker hub account and add a description, etc.

> NOTE: If your image will be used FROM other containers you might want to use ```./push.sh flatten``` to consolidate the AUFS layers into a single layer. Keep in mind, you may lose Dockerfile attributes when your image is flattened.
EOF
fi
#### END README.MD HEREDOC

#### BEGIN .GITIGNORE HEREDOC
if [[ ! -f .gitignore ]]; then
cat << 'EOF' > .gitignore
builds
EOF
fi
#### END .GITIGNORE HEREDOC

chmod 755 build.sh push.sh run.sh shell.sh assets/startup.sh
