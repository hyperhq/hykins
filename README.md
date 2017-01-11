Hykins User Guide
=======================================================

Hykins is a ***serverless*** Jenkins distro optimized for containers. Currently, Hykins supports [Hyper.sh](https://hyper.sh) as infrastructure provider, with more to be added easily.

# Quickstart

## Setup
First, you need to setup your account on [Hyper.sh](https://hyper.sh):

- [Create an account](https://console.hyper.sh/register)
- [Provide your billing information and complete your account](https://console.hyper.sh/billing/credit)
- [Generate a credential](https://docs.hyper.sh/GettingStarted/generate_api_credential.html)
- [Install and configure `hyper` CLI on your laptop](https://docs.hyper.sh/GettingStarted/install.html)

## Deploy Hykins container
There is a prebaked Docker image for [Hykins](https://hub.docker.com/r/hyperhq/hykins/) available in Docker Hub. You can simply pull the image to your Hyper.sh account:

``` bash
$ hyper pull hyperhq/hykins
```

> **What's in the image?**
> `hyperhq/hykins` is based on `jenkins:latest`, with the following items installed:
> - `hyper` command line tools
> - `hyper-slaves-plugin` for Jenkins
> - Recommended plugins by Jenkins community

> You can find the Dockerfile [here](https://github.com/hyperhq/hykins/blob/master/Dockerfile).

To deploy Hykins in Hyper.sh:
```
$ hyper run --name hykins -d -P \
  --size=m1 \
  -e ADMIN_USERNAME=xxxxx \
  -e ADMIN_PASSWORD=xxxxx \
  -e ACCESS_KEY=xxxxx \
  -e SECRET_KEY=xxxxx \
  hyperhq/hykins
```

> Notes:
> - By default, Hykins is launched in `development` mode(the Setup Wizard will not appear). See [below](https://github.com/hyperhq/hykins#production-setup) to see how to run Hykins in production mode
> - In `development` mode, the recommended container size is `m1` (1GB)
> - `ADMIN_USERNAME`/ `ADMIN_PASSWORD` is for the Hykins admin account (default: `admin`/`nimda`)
> - `ACCESS_KEY`/ `SECRET_KEY` is the API credential of Hyper.sh

Containers in Hyper.sh come without public IP address by default. To enable Internet access, you need to request one and attach to the container:
```
$ FIP=`hyper fip allocate 1`
$ hyper fip attach $FIP hykins
```

# Production setup

## Launch in production mode
To run Hykins in production mode, use the following command:

```
$ hyper run --name hykins -d -P --size=m2 -e PRODUCTION=true \
  -v hykins-data:/var/jenkins_home \
  -e ACCESS_KEY=xxxxx -e SECRET_KEY=xxxx hyperhq/hykins
$ FIP=`hyper fip allocate 1`
$ hyper fip attach $FIP hykins
```
> Notes:
> - The recommended container size is `m2`(`2GB` memory)

## Unlock Jenkins
In Production Mode, you need to unlock Jenkins to be able to access:
- Open the web portal in your browser `http://${FIP}:8080`
- Setup Wizard` will prompt to ask for initial admin password`
- run `hyper exec -it hykins cat /var/jenkins_home/secrets/initialAdminPassword`

------------------------------------------------------------------------------

# Try A Sample Job

![](https://raw.githubusercontent.com/hyperhq/hykins/master/images/run-jenkins-job-in-hyper-slave.png)

## create helloworld job
```
//Step 1: create "Freestyle project" helloworld

//Step 2: check "Run the build inside Hyper.sh container"
   - Docker Image: jenkinsci/slave
   - Container Size: S4
```

![](https://raw.githubusercontent.com/hyperhq/hykins/master/images/job-general-config.png)

Other tested base images are:
 - [oracle/openjdk:8](https://hub.docker.com/r/oracle/openjdk/)
 - [openjdk:8-jdk](https://hub.docker.com/_/openjdk/)
 - [hyperhq/jenkins-slave-centos](https://hub.docker.com/r/hyperhq/jenkins-slave-centos/)
 - [hyperhq/jenkins-slave-golang:1.7-centos](https://hub.docker.com/r/hyperhq/jenkins-slave-golang/tags/)
 - [hyperhq/jenkins-slave-golang:1.7-ubuntu](https://hub.docker.com/r/hyperhq/jenkins-slave-golang/tags/)

```
//Step 3: Add build step "Execute shell"
  - Command:
```

![](https://raw.githubusercontent.com/hyperhq/hykins/master/images/build-step.png)

Here is the shell script:
```
set +x
echo ------------------------------------------------
cat /etc/os-release
echo ------------------------------------------------
cat /proc/cpuinfo | grep -E '(processor|model name|cpu cores)'
echo ------------------------------------------------
cat /proc/meminfo | grep ^Mem
echo ------------------------------------------------
```

## trigger build
Trigger build manually in this demo.
![](https://raw.githubusercontent.com/hyperhq/hykins/master/images/manually-build.png)

## view result

### console output
![](https://raw.githubusercontent.com/hyperhq/hykins/master/images/output-console.png)

### Slave container info
![](https://raw.githubusercontent.com/hyperhq/hykins/master/images/hyper-slave-container-info.png)

### Slave container log
![](https://raw.githubusercontent.com/hyperhq/hykins/master/images/hyper-slave-container-log.png)



# Update

## 2016/11/17
- update jenkins from 2.7.4 to 2.19.3
- update hyper-slaves-plugin to 0.1.5(rely on docker-slaves-plugin)
