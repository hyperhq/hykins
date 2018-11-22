#!groovy

import jenkins.model.*
import hudson.security.*

println "--> set disableStrictVerification to 'true'"
jenkins.slaves.DefaultJnlpSlaveReceiver.disableStrictVerification=true
