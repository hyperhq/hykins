#!/bin/bash

LTS_VERSION="2.49"

function show_usage() {
  cat <<EOF

usage: ./util.sh <ACTION> [VERSION]

<ACTION>:
  build    - build image
  push     - push image to docker hub
  docker   - run jenkins-server in docker
  hyper    - run jenkins-server in Hyper.sh

[VERSION]:
  lts             - jenkins             -> hyperhq/hykins:<LTS_VERSION>, latest
  latest          - jenkinsci/jenkins   -> hyperhq/hykins:dev-<ver>, dev-latest
  <specified_ver> - jenkinsci/jenkins   -> hyperhq/hykins:dev-<ver>

EOF
  exit 1
}

function fn_build() {
  docker build --pull \
    --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} \
    --tag hyperhq/hykins:${TAG} .
}

function fn_push() {

  echo "--------------------------------------------------"
  echo "starting push [hyperhq/hykins:${TAG}]"
  docker push hyperhq/hykins:${TAG}

  if [ "${LATEST_TAG}" != "" ];then
    echo "--------------------------------------------------"
    echo "starting push [hyperhq/hykins:latest]"
    docker tag hyperhq/hykins:${TAG} hyperhq/hykins:${LATEST_TAG}
    docker push hyperhq/hykins:${LATEST_TAG}
  fi
}

function fn_run_in_docker() {
  echo ">delete old container"
  docker rm -v -f jenkins-server-dev >/dev/null 2>&1
  echo ">start new container in docker"
  docker run --name jenkins-server-dev \
    -d -P \
    hyperhq/hykins
}

function fn_run_in_hyper() {
  echo ">delete old container"
  hyper rm -v -f jenkins-server-dev >/dev/null 2>&1
  echo ">pull image hyperhq/hykins"
  hyper pull hyperhq/hykins
  echo ">start new container in hyper"
  hyper run --name jenkins-server-dev \
    -d -P \
    hyperhq/hykins
  cat <<EOF

---------------------------------------
#add fip to hyper container
\$ FIP=\$(hyper fip allocate 1)
\$ hyper fip attach \$FIP jenkins-server
---------------------------------------
EOF
}



###########################################################
# main
###########################################################
#set -e
set +x

ACTION=$1
VERSION=$2

if [ $# -eq 0 ];then
  show_usage
fi

case "${VERSION}" in
  "lts"|"")
   JENKINS_VERSION=${LTS_VERSION}
   TAG="${JENKINS_VERSION}"
   LATEST_TAG="latest"
   JENKINS_REPO="jenkins"
  ;;
 "latest")
  JENKINS_VERSION=`curl -sq https://api.github.com/repos/jenkinsci/jenkins/tags | grep '"name":' | grep -o '[0-9]\.[0-9]*'  | uniq | sort --version-sort | tail -1`
  TAG="dev-${JENKINS_VERSION}"
  LATEST_TAG="dev-latest"
  JENKINS_REPO="jenkinsci/jenkins"
 ;;
 *)
  JENKINS_VERSION=${VERSION}
  TAG="dev-${JENKINS_VERSION}"
  LATEST_TAG=""
  JENKINS_REPO="jenkinsci/jenkins"
 ;;
esac

sed "s/%JENKINS_REPO%/${JENKINS_REPO}/g" Dockerfile.template > Dockerfile
sed -i "s/%JENKINS_VERSION%/${JENKINS_VERSION}/g" Dockerfile

cat <<EOF

VERSION          : ${VERSION}
JENKINS_VERSION  : ${JENKINS_VERSION}
TAG              : ${TAG}
LATEST_TAG       : ${LATEST_TAG}
JENKINS_REPO     : ${JENKINS_REPO}

EOF

case "${ACTION}" in
 "build")
    fn_build
 ;;
 "push")
    fn_build
    fn_push
  ;;
  "docker")
    fn_run_in_docker
  ;;
  "hyper")
    fn_run_in_hyper
  ;;
  *)
  show_usage
  ;;
esac
