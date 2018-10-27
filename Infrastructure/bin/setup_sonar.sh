#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Sonarqube in project $GUID-sonarqube"

# Code to set up the SonarQube project.
# Ideally just calls a template
# oc new-app -f ../templates/sonarqube.yaml --param .....

# To be Implemented by Student
################################################################

# Ensure that we are creating the objects in the correct project
oc project ${GUID}-sonarqube

# Call template to provision nexus objects

##TODO: Add more parameters

oc new-app -f Infrastructure/templates/sonarqube.yaml -p GUID=${GUID} -n ${GUID}-sonarqube \
	-p SONARQUBE_CPU_LIMITS=2000m -p DB_CPU_LIMITS=1000m \
	-p SONARQUBE_MEM_REQUESTS=3Gi -p SONARQUBE_MEM_LIMITS=3Gi

while : ; do
  echo "Checking if Sonarqube is Ready..."
  oc get pod -n ${GUID}-sonarqube|grep -v deploy|grep -v postgresql|grep "1/1"
  [[ "$?" == "1" ]] || break
  echo "...no. Sleeping 10 seconds."
  sleep 10
done

echo "************************"
echo "SonarQube setup complete"
echo "************************"

exit 0