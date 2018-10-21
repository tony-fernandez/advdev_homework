#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

MLB_PARKS_DEV=echo "MLB Parks (Dev)"
NATIONAL_PARKS_DEV=echo "National Parks (Dev)"
PARKS_MAP=echo "ParksMap (Dev)"
DB_HOST=mongodb
DB_PORT=27017
DB_USERNAME=mongodb
DB_PASSWORD=mongodb
DB_NAME=parks

GUID=$1
PARKS_DEV=${GUID}-parks-dev
echo "Setting up Parks Development Environment in project ${PARKS_DEV}"
# Switch to dev
oc project ${PARKS_DEV}

# Grant the correct permissions to the Jenkins service account
oc policy add-role-to-user view --serviceaccount=default -n ${PARKS_DEV}
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n ${PARKS_DEV}
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${PARKS_DEV}
# Create a MongoDB database
echo "Setting up mongo database"
oc new-app --template=mongodb-persistent \
	--param=MONGODB_USER=${DB_USERNAME} \
	--param=MONGODB_PASSWORD=${DB_PASSWORD} \
	--param=MONGODB_DATABASE=${DB_NAME} -n ${PARKS_DEV}
# Create binary build configurations for the pipelines to use for each microservice
oc new-build --binary=true --name="mlbparks" jboss-eap70-openshift:1.7 -n ${PARKS_DEV}
oc new-build --binary=true --name="nationalparks" redhat-openjdk18-openshift:1.2 -n ${PARKS_DEV}
oc new-build --binary=true --name="parksmap" redhat-openjdk18-openshift:1.2 -n ${PARKS_DEV}
# Create ConfigMaps for configuration of the application
echo "Creating mlbparks-dev-config config map"
oc create configmap mlbparks-dev-config \
	--from-literal=APPNAME=${MLB_PARKS_DEV} \
    --from-literal=DB_HOST=${DB_HOST}
    --from-literal=DB_PORT=${DB_PORT}
    --from-literal=DB_USERNAME=${DB_USERNAME}
    --from-literal=DB_PASSWORD=${DB_PASSWORD}
    --from-literal=DB_NAME=${DB_NAME}
echo "Creating nationalparks-dev-config config map"    
oc create configmap nationalparks-dev-config \
	--from-literal=APPNAME=${NATIONAL_PARKS_DEV} \
	--from-literal=DB_HOST=${DB_HOST}
    --from-literal=DB_PORT=${DB_PORT}
    --from-literal=DB_USERNAME=${DB_USERNAME}
    --from-literal=DB_PASSWORD=${DB_PASSWORD}
    --from-literal=DB_NAME=${DB_NAME}
echo "Creating parksmap-dev-config config map"    
oc create configmap parksmap-dev-config \
	--from-literal=APPNAME=${PARKS_MAP} \
	--from-literal=DB_HOST=${DB_HOST}
    --from-literal=DB_PORT=${DB_PORT}
    --from-literal=DB_USERNAME=${DB_USERNAME}
    --from-literal=DB_PASSWORD=${DB_PASSWORD}
    --from-literal=DB_NAME=${DB_NAME}
# Set up placeholder deployment configurations for the three microservices
oc new-app ${PARKS_DEV}/mlbparks:0.0-0 --name=mlbparks --allow-missing-imagestream-tags=true -n ${PARKS_DEV}
oc new-app ${PARKS_DEV}/nationalparks:0.0-0 --name=nationalparks --allow-missing-imagestream-tags=true -n ${PARKS_DEV}
oc new-app ${PARKS_DEV}/parksmap:0.0-0 --name=parksmap --allow-missing-imagestream-tags=true -n ${PARKS_DEV}

oc set triggers dc/mlbparks --remove-all -n ${PARKS_DEV}
oc set triggers dc/nationalparks --remove-all -n ${PARKS_DEV}
oc set triggers dc/parksmap --remove-all -n ${PARKS_DEV}

# Configure the deployment configurations using the ConfigMaps
oc set env dc/mlbparks --from=configmap/mlbparks-dev-config -n ${PARKS_DEV}
oc set env dc/nationalparks --from=configmap/nationalparks-dev-config -n ${PARKS_DEV}
oc set env dc/parksmap --from=configmap/parksmap-dev-config -n ${PARKS_DEV}

oc expose dc mlbparks --port 8080 -n ${PARKS_DEV}
oc expose dc nationalparks --port 8080 -n ${PARKS_DEV}
oc expose dc parksmap --port 8080 -n ${PARKS_DEV}

# set deployment hooks to call /ws/data/load/ and populate the database for the back end services
oc set deployment-hook dc/mlbparks  -n ${PARKS_DEV} --post -c mlbparks --failure-policy=abort -- curl http://$(oc get route mlbparks -n ${PARKS_DEV} -o jsonpath='{ .spec.host }')/ws/data/load/
oc set deployment-hook dc/nationalparks  -n ${PARKS_DEV} --post -c nationalparks --failure-policy=abort -- curl http://$(oc get route nationalparks -n ${PARKS_DEV} -o jsonpath='{ .spec.host }')/ws/data/load/
oc set deployment-hook dc/parksmap  -n ${PARKS_DEV} --post -c parksmap --failure-policy=abort -- curl http://$(oc get route parksmap -n ${PARKS_DEV} -o jsonpath='{ .spec.host }')/ws/data/load/

# Set up liveness and readiness probes
oc set probe dc/mlbparks -n ${PARKS_DEV} --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok
oc set probe dc/mlbparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${PARKS_DEV}
oc set probe dc/nationalparks -n ${PARKS_DEV} --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok
oc set probe dc/nationalparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${PARKS_DEV}
oc set probe dc/parksmap -n ${PARKS_DEV} --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok
oc set probe dc/parksmap --readiness --failure-threshold 5 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${PARKS_DEV}

# Expose and label the services properly (parksmap-backend)
oc expose svc mlbparks -n ${PARKS_DEV} --labels="type=parksmap-backend"
oc expose svc nationalparks -n ${PARKS_DEV} --labels="type=parksmap-backend"
oc expose svc parksmap -n ${PARKS_DEV}
echo "${PARKS_DEV} completed successfully"