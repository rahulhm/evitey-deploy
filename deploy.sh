#!/usr/bin/env bash

set -e

TOP=`dirname "$0"`
WORKDIR=$PWD
FE_SRC=$PWD/frontend
BE_SRC=$PWD/backend

FE_BRANCH="master"
BE_BRANCH="master"

FE_REPO_PATH="git@github.com:Evitey/dashboard-app.git"
BE_REPO_PATH="git@github.com:Evitey/webApp.git"

FE_DOCKERFILE="ngbuild.Dockerfile"

# cloneRepo <REPO URL> <BRANCH / TAG> <DIRECTORY>
cloneRepo(){
    if [ ! -d "$3" ]; then
        git clone -b "$2" "$1" "$3"
    else
        echo "using exising : $3"
    fi
}

clean(){
    sudo rm -rf $FE_SRC $BE_SRC
}

buildFE(){
  sudo docker build -t crewconnect_fe -f $FE_DOCKERFILE $FE_SRC
}

buildBE(){
    cd $BE_SRC/applications/TaskManagement
    make -C $BE_SRC taskman-docker
}

stackUp(){
    sudo docker-compose -f backend/deployment/docker-compose-evitey.yaml up -d db
    echo "waiting for MySQL...";sleep 30
    sudo docker-compose -f backend/deployment/docker-compose-evitey.yaml run --rm  taskman /app/TaskManagement  -reset -seed -migrate -dry
    sudo docker-compose -f backend/deployment/docker-compose-evitey.yaml up -d taskman
    sudo docker-compose -f backend/deployment/docker-compose-evitey.yaml up -d lb

    # Run nginx_conf.sh script
    sudo /home/evitey-test-01/deploy_cc/nginx_conf.sh
}

stackRun(){
    sudo docker-compose -f backend/deployment/docker-compose-evitey.yaml up -d db
    echo "waiting for MySQL...";sleep 30
    sudo docker-compose -f backend/deployment/docker-compose-evitey.yaml up -d taskman
    sudo docker-compose -f backend/deployment/docker-compose-evitey.yaml up -d lb
}


stackDown() {
    sudo docker-compose -f backend/deployment/docker-compose-evitey.yaml down
}
main(){
    cloneRepo $FE_REPO_PATH $FE_BRANCH $FE_SRC
    cloneRepo $BE_REPO_PATH $BE_BRANCH $BE_SRC

    cp $FE_DOCKERFILE $FE_SRC
    cp -r $BE_SRC/nginx $FE_SRC/
    buildFE
    buildBE
}


case $1 in

clean)
    clean
;;
danger_up)
    stackUp
;;
danger_down)
    stackDown
;;
run)
    stackRun
;;
*)
    main
;;

esac
