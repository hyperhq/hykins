#!groovy

import jenkins.model.*
import hudson.security.*

//Get the JENKINS_URL env
def env = System.getenv()
def jenkins_url = env['JENKINS_URL']
println "JENKINS_URL: " + jenkins_url

def jlc = JenkinsLocationConfiguration.get()
if (jenkins_url){
  println "JENKINS_URL specified"
} else {
  def hostname = InetAddress.localHost.canonicalHostName
  def ip = InetAddress.getByName(hostname).address.collect { it & 0xFF }.join('.')
  jenkins_url = "http://"+ip+":8080/"
  println "No JENKINS_URL, use internal ip :" + ip
}

jlc.setUrl(jenkins_url)
jlc.save()

println "JENKINS_URL updated to " + jenkins_url
