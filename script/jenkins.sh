#! /bin/bash -e

: "${JENKINS_WAR:="/usr/share/jenkins/jenkins.war"}"
: "${JENKINS_HOME:="/var/jenkins_home"}"
touch "${COPY_REFERENCE_FILE_LOG}" || { echo "Can not write to ${COPY_REFERENCE_FILE_LOG}. Wrong volume permissions?"; exit 1; }
echo "--- Copying files at $(date)" >> "$COPY_REFERENCE_FILE_LOG"
find /usr/share/jenkins/ref/ \( -type f -o -type l \) -exec bash -c '. /usr/local/bin/jenkins-support; for arg; do copy_reference_file "$arg"; done' _ {} +


###############################
# generate .hyper/config
mkdir -p ${JENKINS_HOME}/.hyper/
HYPER_CFG=${JENKINS_HOME}/.hyper/config.json
if [ "${DOCKER_HUB_USERNAME}" == "" -a "${DOCKER_HUB_PASSWORD}" == "" -a "${DOCKER_HUB_EMAIL}" == "" ];then
  cat > ${HYPER_CFG} <<EOF
{
	"auths": {},
	"clouds": {
		"tcp://us-west-1.hyper.sh:443": {
			"accesskey": "${ACCESS_KEY}",
			"secretkey": "${SECRET_KEY}"
		}
	}
}
EOF
else
  DOCKER_HUB_AUTH=$(echo -n "${DOCKER_HUB_USERNAME}:${DOCKER_HUB_PASSWORD}" | base64)
  cat > ${HYPER_CFG} <<EOF
{
	"auths": {
		"https://index.docker.io/v1/": {
			"auth": "${DOCKER_HUB_AUTH}",
			"email": "${DOCKER_HUB_EMAIL}"
		}
	},
	"clouds": {
		"tcp://us-west-1.hyper.sh:443": {
			"accesskey": "${ACCESS_KEY}",
			"secretkey": "${SECRET_KEY}"
		}
	}
}
EOF
fi
cat ${HYPER_CFG} \
| sed 's/"secretkey":.*/"secretkey": "**********"/g' \
| sed 's/"auth":.*/"auth": "**********"/g'

#ensure dir ($JENKINS_HOME maybe a empty dir)
mkdir -p $JENKINS_HOME/secrets $JENKINS_HOME/init.groovy.d
mkdir -p ${JENKINS_HOME}/bin

#ensure hyper cli and config dir
if [ ! -f ${JENKINS_HOME}/bin/hyper ];then
  cp /usr/local/bin/hyper ${JENKINS_HOME}/bin/hyper
fi

#prepare run mode(unlock jenkins automatically)
if [ "${PRODUCTION}" == "true" ];then
  echo "==============================="
  echo "Run jenkins in production mode"
  echo "==============================="
  # Configure Global Security -> [check] Enable Slave → Master Access Control
  echo -n false > $JENKINS_HOME/secrets/slave-to-master-security-kill-switch
  # ensure basic-security.groovy not exist
  if [ -f /var/lib/jenkins/init.groovy.d/basic-security.groovy ];then
    echo "found '/var/lib/jenkins/init.groovy.d/basic-security.groovy', backup it"
    mv /var/lib/jenkins/init.groovy.d/basic-security.groovy $JENKINS_HOME/init.groovy.d/basic-security.groovy.bak
  fi
  if [ -f $JENKINS_HOME/init.groovy.d/basic-security.groovy ];then
    echo "found '$JENKINS_HOME/init.groovy.d/basic-security.groovy', rename it!"
    mv $JENKINS_HOME/init.groovy.d/basic-security.groovy $JENKINS_HOME/init.groovy.d/basic-security.groovy.bak
  fi
else
  echo "==============================="
  echo "run jenkins in development mode"
  echo "-------------------------------"
  # Configure Global Security -> [check] Enable Slave → Master Access Control
  echo -n true > $JENKINS_HOME/secrets/slave-to-master-security-kill-switch
  # skip setup wizard
  echo "(skip setup wizard)"
  if [ -f $JENKINS_HOME/init.groovy.d/basic-security.groovy ];then
      echo "jenkins initialize admin account already, rename 'basic-security.groovy' and skip!"
      mv $JENKINS_HOME/init.groovy.d/basic-security.groovy $JENKINS_HOME/init.groovy.d/basic-security.groovy.bak
      rm -rf /var/lib/jenkins/init.groovy.d/basic-security.groovy >/dev/null 2>&1
  elif [ -f $JENKINS_HOME/init.groovy.d/basic-security.groovy.bak ];then
      echo "jenkins initialize admin account already, skip!"
      rm -rf /var/lib/jenkins/init.groovy.d/basic-security.groovy >/dev/null 2>&1
  elif [ -f /var/lib/jenkins/init.groovy.d/basic-security.groovy ];then
      echo "initialize admin account..."
      mv /var/lib/jenkins/init.groovy.d/basic-security.groovy $JENKINS_HOME/init.groovy.d/basic-security.groovy
      mv /var/lib/jenkins/jenkins.install.UpgradeWizard.state $JENKINS_HOME/jenkins.install.UpgradeWizard.state
      if [ "${ADMIN_PASSWORD}" == "" ];then
        ADMIN_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32;echo)
        echo "Generate admin password: ${ADMIN_PASSWORD}"
      fi
      sed -i "s/%ADMIN_USERNAME%/${ADMIN_USERNAME}/g" $JENKINS_HOME/init.groovy.d/basic-security.groovy
      sed -i "s/%ADMIN_PASSWORD%/${ADMIN_PASSWORD}/g" $JENKINS_HOME/init.groovy.d/basic-security.groovy
  else
    cat <<EOF

[WARN] Missing one of the following files:
---------------------------------------------------------
- /var/lib/jenkins/init.groovy.d/basic-security.groovy
- ${JENKINS_HOME}/init.groovy.d/basic-security.groovy
- ${JENKINS_HOME}/init.groovy.d/basic-security.groovy.bak
---------------------------------------------------------

EOF
  fi
  export JAVA_OPTS="-Dhudson.Main.development=true -Djenkins.install.runSetupWizard=false"
  echo "==============================="
fi


#copy setup-jenkins-script.groovy
if [ -f /var/lib/jenkins/init.groovy.d/setup-jenkins-script.groovy ];then
  echo "override setup-jenkins-script.groovy"
  cp /var/lib/jenkins/init.groovy.d/setup-jenkins-script.groovy $JENKINS_HOME/init.groovy.d/
fi
###############################


# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then

  # read JAVA_OPTS and JENKINS_OPTS into arrays to avoid need for eval (and associated vulnerabilities)
  java_opts_array=()
  while IFS= read -r -d '' item; do
    java_opts_array+=( "$item" )
  done < <([[ $JAVA_OPTS ]] && xargs printf '%s\0' <<<"$JAVA_OPTS")

  if [[ "$DEBUG" ]] ; then
    java_opts_array+=( \
      '-Xdebug' \
      '-Xrunjdwp:server=y,transport=dt_socket,address=5005,suspend=y' \
    )
  fi

  jenkins_opts_array=( )
  while IFS= read -r -d '' item; do
    jenkins_opts_array+=( "$item" )
  done < <([[ $JENKINS_OPTS ]] && xargs printf '%s\0' <<<"$JENKINS_OPTS")

  exec java -Duser.home="$JENKINS_HOME" "${java_opts_array[@]}" -jar ${JENKINS_WAR} "${jenkins_opts_array[@]}" "$@"
fi

# As argument is not jenkins, assume user want to run his own process, for example a `bash` shell to explore this image
exec "$@"
