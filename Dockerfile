#REF: https://github.com/jenkinsci/docker
FROM jenkins:2.202

USER root

##################################
##       install hypercli       ##
##################################
RUN wget https://hyper-install.s3.amazonaws.com/hyper-linux-x86_64.tar.gz -O /tmp/hyper-linux-x86_64.tar.gz \
  && cd /usr/local/bin/ && tar -xzvf /tmp/hyper-linux-x86_64.tar.gz && chmod +x /usr/local/bin/hyper \
  && mkdir ${JENKINS_HOME}/bin; cp /usr/local/bin/hyper ${JENKINS_HOME}/bin/hyper \
  && rm -rf /tmp/hyper-linux-x86_64.tar.gz
RUN ln -s ${JENKINS_HOME}/.hyper /.hyper && ln -s ${JENKINS_HOME}/.hyper /root/.hyper

################################
##   install jenkins plugin   ##
################################
# install hyper plugin
RUN /usr/local/bin/install-plugins.sh  hyper-commons:0.1.5 hyper-slaves:0.1.7

# install recommended plugin
RUN /usr/local/bin/install-plugins.sh  cloudbees-folder timestamper workflow-aggregator subversion ldap \
                    antisamy-markup-formatter ws-cleanup github-organization-folder ssh-slaves email-ext\
                    build-timeout ant pipeline-stage-view matrix-auth mailer \
                    credentials-binding gradle git pam-auth

################################
##     jenkins setting        ##
################################
ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_VERSION 2.202
WORKDIR $JENKINS_HOME
VOLUME $JENKINS_HOME
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]
# 8080 ：main web interface
# 50000：will be used by attached slave agents
EXPOSE 8080
EXPOSE 50000

################################
##     skip setup wizard      ##
################################
ENV PRODUCTION ${PRODUCTION:-false}
ENV ADMIN_USERNAME ${ADMIN_USERNAME:-admin}
ENV ADMIN_PASSWORD ${ADMIN_PASSWORD:-nimda}
#ENV ADMIN_PASSWORD ${ADMIN_PASSWORD:-} #if default is empty, random password will be generated

## prepare scipt
RUN mkdir -p /var/lib/jenkins/init.groovy.d
COPY groovy/disableSetupWizard/basic-security.groovy /var/lib/jenkins/init.groovy.d/basic-security.groovy
COPY groovy/initJenkinsURL/setup-jenkins-script.groovy /var/lib/jenkins/init.groovy.d/setup-jenkins-script.groovy
RUN echo $JENKINS_VERSION > /var/lib/jenkins/jenkins.install.UpgradeWizard.state

# replace the original jenkins.sh
COPY script/jenkins.sh /usr/local/bin/jenkins.sh

################################
##     Initialize Account     ##
################################
ENV ACCESS_KEY ${ACCESS_KEY:-}
ENV SECRET_KEY ${SECRET_KEY:-}
ENV DOCKER_HUB_USERNAME ${DOCKER_HUB_USERNAME:-}
ENV DOCKER_HUB_PASSWORD ${DOCKER_HUB_PASSWORD:-}
ENV DOCKER_HUB_EMAIL ${DOCKER_HUB_EMAIL:-}

################################
##     specify Jenkins URL    ##
################################
# use JENKINS_URL to persist Jenkins URL(maybe a fixed domain), otherwise it will be updated to Internal IP of Jenkins Server automatically.
ENV JENKINS_URL ${JENKINS_URL:-}

###########################################
##   install additional jenkins plugin   ##
###########################################
# install GitHub pull request builder plugin
RUN /usr/local/bin/install-plugins.sh ghprb

###########################################
##   install add trampoline              ##
###########################################exercise
##The source code is https://github.com/jenkinsci/hyper-slaves-plugin/tree/master/trampoline
#COPY script/trampoline /var/jenkins_home/war/WEB-INF/trampoline
echo ${JENKINS_HOME}
