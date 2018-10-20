#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

# Code to set up the Nexus. It will need to
# * Create Nexus
# * Set the right options for the Nexus Deployment Config
# * Load Nexus with the right repos
# * Configure Nexus as a docker registry
# Hint: Make sure to wait until Nexus if fully up and running
#       before configuring nexus with repositories.
#       You could use the following code:
# while : ; do
#   echo "Checking if Nexus is Ready..."
#   oc get pod -n ${GUID}-nexus|grep '\-2\-'|grep -v deploy|grep "1/1"
#   [[ "$?" == "1" ]] || break
#   echo "...no. Sleeping 10 seconds."
#   sleep 10
# done

# Ideally just calls a template
# oc new-app -f ../templates/nexus.yaml --param .....

# To be Implemented by Student

# Change to the correct project
oc project ${GUID}-nexus

oc new-app sonatype/nexus3:latest
oc expose svc nexus3
oc rollout pause dc nexus3
oc patch dc nexus3 --patch='{ "spec": { "strategy": { "type": "Recreate" }}}'
oc set resources dc nexus3 --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m

# Create persistent volume mount
oc create -f ../templates/nexus-pvc.yaml


oc set volume dc/nexus3 --add --overwrite --name=nexus3-volume-1 --mount-path=/nexus-data/ --type persistentVolumeClaim --claim-name=nexus-pvc

oc set probe dc/nexus3 --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok
oc set probe dc/nexus3 --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/repository/maven-public/
oc rollout resume dc nexus3

http_status=""
while : ; do  
  echo "Checking if Nexus is up."
  #http_status=$(curl -I http://nexus3-tf-nexus.127.0.0.1.nip.io/repository/maven-public/ -o /dev/null -w '%{http_code}\n' -s)
  #http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus) 
  http_status=$(curl -I http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus)/repository/maven-public/ -o /dev/null -w '%{http_code}\n' -s)
  echo "Http call returned code: ${http_status}"	
  [[ "$http_status" != "200" ]] || break
  echo "...no. Sleeping 10 seconds."    
  sleep 10
done

curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
chmod +x setup_nexus3.sh
./setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}')
rm setup_nexus3.sh

