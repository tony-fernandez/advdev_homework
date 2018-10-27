#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
JENKINS=${GUID}-jenkins
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

#Switch to jenkins project to make sure app is created in correct project.
echo "Changing to ${JENKINS} project..." 
oc project ${JENKINS}

# Create the new jenkins app
echo "Creating jenkins app..."
oc new-app jenkins-persistent \
	--param ENABLE_OAUTH=true \
	--param MEMORY_LIMIT=2Gi \
	--param VOLUME_CAPACITY=4Gi \
	-n ${JENKINS}

# adding resource limits
echo "Pausing rollout..."
oc rollout pause dc jenkins \
	-n ${JENKINS}

echo "Setting resources..."
oc set resources dc jenkins \
	--limits=memory=2Gi,cpu=2 \
	--requests=memory=1Gi,cpu=1 \
	-n ${JENKINS}
	
oc rollout resume dc jenkins \
	-n ${JENKINS}
oc rollout status dc/jenkins \
	--watch \
	-n ${JENKINS}

echo "Building slave...."
oc new-build \
	--name=jenkins-slave-maven-appdev \
	--dockerfile="$(< ./Infrastructure/docker/Dockerfile)" \
	-n ${JENKINS}
   
oc logs -f bc/jenkins-slave-maven-appdev

while : ; do
    oc get pod -n ${JENKINS} | grep 'slave' | grep "Completed"
    if [ $? == "0" ]
      then
        break
      else
        echo "Waiting for Jenkins slave"
        sleep 10
    fi
done

echo "Configuring slave"
# configure kubernetes PodTemplate plugin.
oc new-app -f ./Infrastructure/templates/jenkins-config.yaml \
	--param GUID=${GUID} \
	-n ${JENKINS}
echo "Slave configuration completed"

echo "Creating mlbparks-pipeline configuration"

echo "apiVersion: v1
kind: BuildConfig
metadata:
  name: mlbparks-pipeline
spec:
  source:
    git:
      uri: ${REPO}
  strategy:
    jenkinsPipelineStrategy:
      jenkinsfilePath: MLBParks/Jenkinsfile" | oc create -f - -n ${JENKINS}

echo "Creating nationalparks-pipeline configuration"

echo "kind: BuildConfig
apiVersion: v1
metadata:
  name: nationalparks-pipeline
spec:
  source:
    git:
      uri: ${REPO}
  strategy:
    jenkinsPipelineStrategy:
      jenkinsfilePath: Nationalparks/Jenkinsfile"  | oc create -f - -n ${JENKINS}

echo "Creating parksmap-pipeline configuration"

echo "kind: BuildConfig
apiVersion: v1
metadata:
  name: parksmap-pipeline
spec:
  source:
    git:
      uri: ${REPO}
  strategy:
    jenkinsPipelineStrategy:
      jenkinsfilePath: ParksMap/Jenkinsfile"  | oc create -f - -n ${JENKINS}

oc set env bc/mlbparks-pipeline GUID=${GUID} REPO=${REPO} CLUSTER=${CLUSTER} -n ${JENKINS}
oc set env bc/nationalparks-pipeline GUID=${GUID} REPO=${REPO} CLUSTER=${CLUSTER} -n ${JENKINS}
oc set env bc/parksmap-pipeline GUID=${GUID} REPO=${REPO} CLUSTER=${CLUSTER} -n ${JENKINS}

echo "Jenkins setup complete."