#!groovy

import jenkins.model.*
import hudson.security.*

//Get the JENKINS_URL env
def env = System.getenv()
def jenkins_url = env['JENKINS_URL']
println "JENKINS_URL: " + jenkins_url

def jlc = JenkinsLocationConfiguration.get()
if (jenkins_url){
  println "set 'Jenkins URL' via JENKINS_URL"
} else {
  def found = false
  def hostname = ""
  def ip = ""
  try {
    hostname = InetAddress.localHost.canonicalHostName
    ip = InetAddress.getByName(hostname).address.collect { it & 0xFF }.join('.')
  } catch(Exception ex) {
    println("Can not get ip via hostname, now get ip from network interface");
    def interfaces = NetworkInterface.getNetworkInterfaces()
    while (interfaces.hasMoreElements() && !found) {
      def addresses = interfaces.nextElement().getInetAddresses()
      while (addresses.hasMoreElements() && !found) {
        InetAddress address = addresses.nextElement();
        if (!address.isLoopbackAddress() && address.getHostName().indexOf(".hypernetes")>0){
          ip = address.getHostAddress()
          hostname = address.getHostName()
          found = true
        }
      }
    }
  }
  println ip + " => " + hostname
  jenkins_url = "http://"+ip+":8080/"
  println "No JENKINS_URL, use internal ip :" + ip

}

jlc.setUrl(jenkins_url)
jlc.save()

println "JENKINS_URL updated to " + jenkins_url
