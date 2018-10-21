#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
SONAR=$GUID-sonarqube
echo "Setting up Sonarqube in project ${SONAR}"

# Switch to Sonarqube project.
echo "Switching to ${SONAR} project"
oc project ${SONAR}

# Setup postgress db
echo "Setting up postgress database..."
oc new-app \
	--template=postgresql-persistent \
	--param POSTGRESQL_USER=sonar \
	--param POSTGRESQL_PASSWORD=sonar \
	--param POSTGRESQL_DATABASE=sonar \
	--param VOLUME_CAPACITY=4Gi \
	--labels=app=sonarqube_db \
	-n ${SONAR}

# Deploy SonarQube
echo "Creating new sonaqube app..."
oc new-app \
	--docker-image=wkulhanek/sonarqube:6.7.4 \
	--env=SONARQUBE_JDBC_USERNAME=sonar \
	--env=SONARQUBE_JDBC_PASSWORD=sonar \
	--env=SONARQUBE_JDBC_URL=jdbc:postgresql://postgresql/sonar \
	--labels=app=sonarqube \
	-n ${SONAR}
	
oc rollout pause dc sonarqube -n ${SONAR}
oc expose service sonarqube -n ${SONAR}

# Create persistent volume claim and set it to sonarqube
echo "Creating persistent volume claim..."
echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sonarqube-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi" | oc create -f - -n ${SONAR}

oc set volume dc/sonarqube \
	--add --overwrite \
	--name=sonarqube-volume-1 \
	--mount-path=/opt/sonarqube/data/ \
	--type persistentVolumeClaim \
	--claim-name=sonarqube-pvc \
	-n ${SONAR}
	
# Set resources
echo "Setting resources..."
oc set resources dc/sonarqube \
	--limits=memory=3Gi,cpu=2 \
	--requests=memory=2Gi,cpu=1 \
	-n ${SONAR}

oc patch dc sonarqube \
	--patch='{ "spec": { "strategy": { "type": "Recreate" }}}' \
	-n ${SONAR}

# Add liveliness and readiness probes
echo "Adding liveliness and readinees probes..."
oc set probe dc/sonarqube \
	--liveness \
	--failure-threshold 3 \
	--initial-delay-seconds 40 \
	-- echo ok \
	-n ${SONAR}
	
oc set probe dc/sonarqube \
	--readiness \
	--failure-threshold 3 \
	--initial-delay-seconds 20 \
	--get-url=http://:9000/about \
	-n ${SONAR}
oc rollout resume dc sonarqube -n ${SONAR}
oc rollout status dc/sonarqube --watch -n ${SONAR}