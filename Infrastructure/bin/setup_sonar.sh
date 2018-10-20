#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
SONAR_PROJECT_NAME=$GUID-sonarqube
echo "Setting up Sonarqube in project ${SONAR_PROJECT_NAME}"

# Switch to Sonarqube project.
echo "Switching to ${SONAR_PROJECT_NAME} project"
oc project ${SONAR_PROJECT_NAME}

# Setup postgress db
echo "Setting up postgress database..."
oc new-app --template=postgresql-persistent --param POSTGRESQL_USER=sonar --param POSTGRESQL_PASSWORD=sonar --param POSTGRESQL_DATABASE=sonar --param VOLUME_CAPACITY=4Gi --labels=app=sonarqube_db 

# Deploy SonarQube
echo "Creating new sonaqube app..."
oc new-app --docker-image=wkulhanek/sonarqube:6.7.4 --env=SONARQUBE_JDBC_USERNAME=sonar --env=SONARQUBE_JDBC_PASSWORD=sonar --env=SONARQUBE_JDBC_URL=jdbc:postgresql://postgresql/sonar --labels=app=sonarqube
oc rollout pause dc sonarqube
oc expose service sonarqube

# Create persistent volume claim and set it to sonarqube
echo "Creating persistent volume claim..."
oc create -f ../templates/sonarqube-pvc.yaml
oc set volume dc/sonarqube --add --overwrite --name=sonarqube-volume-1 --mount-path=/opt/sonarqube/data/ --type persistentVolumeClaim --claim-name=sonarqube-pvc

# Set resources
echo "Setting resources..."
oc set resources dc/sonarqube --limits=memory=3Gi,cpu=2 --requests=memory=2Gi,cpu=1
oc patch dc sonarqube --patch='{ "spec": { "strategy": { "type": "Recreate" }}}'

# Add liveliness and readiness probes
echo "Adding liveliness and readinees probes..."
oc set probe dc/sonarqube --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/sonarqube --readiness --failure-threshold 3 --initial-delay-seconds 20 --get-url=http://:9000/about
oc rollout resume dc sonarqube
oc rollout status dc/sonarqube --watch -n ${SONAR_PROJECT_NAME}