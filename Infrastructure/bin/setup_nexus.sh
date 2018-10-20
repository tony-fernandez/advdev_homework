#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
NEXUS=$GUID-nexus
echo "Setting up Nexus in project ${NEXUS}"

# Change to the correct project
oc project ${NEXUS}

oc new-app sonatype/nexus3:latest
oc expose svc nexus3
oc rollout pause dc nexus3


oc patch dc nexus3 --patch='{ "spec": { "strategy": { "type": "Recreate" }}}'
oc set resources dc nexus3 --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m

# Create persistent volume mount
echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nexus-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi" | oc create -f -

oc set volume dc/nexus3 --add --overwrite --name=nexus3-volume-1 --mount-path=/nexus-data/ --type persistentVolumeClaim --claim-name=nexus-pvc

oc set probe dc/nexus3 --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok
oc set probe dc/nexus3 --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/repository/maven-public/
oc rollout resume dc nexus3

http_status=""
while : ; do  
  echo "Checking if Nexus is up."
  http_status=$(curl -I http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${NEXUS})/repository/maven-public/ -o /dev/null -w '%{http_code}\n' -s)
  echo "Http call returned code: ${http_status}"	
  [[ "$http_status" != "200" ]] || break
  echo "Sleeping 20 seconds...."    
  sleep 20
done

curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
chmod +x setup_nexus3.sh
./setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}')
rm setup_nexus3.sh

oc expose dc nexus3 --port=5000 --name=nexus-registry
oc create route edge nexus-registry --service=nexus-registry --port=5000

oc get routes -n ${NEXUS}

oc annotate route nexus3 console.alpha.openshift.io/overview-app-route=true
oc annotate route nexus-registry console.alpha.openshift.io/overview-app-route=false

echo "${NEXUS} completed successfully"