#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

# Code to set up the parks development project.

# To be Implemented by Student

MONGODB_USER=mongodb
MONGODB_PASSWORD=mongodb
MONGODB_DATABASE=parks

# Ensure we are on the correct project
oc project ${GUID}-parks-dev

# Add role to jenkins service account in order to modify objects
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-dev

# Setup mongoDB for parks backends
oc new-app --template=mongodb-persistent --param=MONGODB_USER=${MONGODB_USER} \
	--param=MONGODB_PASSWORD=${MONGODB_PASSWORD} \
	--param=MONGODB_DATABASE=${MONGODB_DATABASE} \
	-n ${GUID}-parks-dev

# Setup deployments for applications

# MLBParks #
APP=mlbparks
APPNAME="MLB Parks (Dev)"
PROJECT=${GUID}-parks-dev
BASEIMAGE=jboss-eap70-openshift:1.7

oc new-build --binary=true --name="${APP}" ${BASEIMAGE} -n ${PROJECT}
oc new-app ${PROJECT}/${APP}:0.0-0 --name=${APP} --allow-missing-imagestream-tags=true -n ${PROJECT}
oc set triggers dc/${APP} --remove-all -n ${PROJECT}
oc set resources dc/${APP} --limits=cpu=500m,memory=1Gi --requests=cpu=250m,memory=512Mi -n ${PROJECT}
oc set env dc/${APP} DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=${MONGODB_USER} DB_PASSWORD=${MONGODB_PASSWORD} DB_NAME=${MONGODB_DATABASE} -n ${PROJECT}
oc create configmap ${APP}-config --from-literal=APPNAME="${APPNAME}" -n ${PROJECT}
oc set env --from=configmap/${APP}-config dc/${APP} -n ${PROJECT}
oc set probe dc/${APP} -n ${PROJECT} --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/${APP} -n ${PROJECT} --readiness --failure-threshold 3 --initial-delay-seconds 30 --get-url=http://:8080/ws/healthz/
oc expose dc ${APP} --port 8080 -n ${PROJECT}
sleep 5
oc set deployment-hook dc/${APP} -n ${PROJECT} --post --failure-policy=abort -- sh -c "sleep 10 && curl -i -X GET http://$(oc get service ${APP} -o jsonpath='{ .spec.clusterIP }' -n ${PROJECT}):8080/ws/data/load/" 
oc label svc ${APP} type=parksmap-backend app=${APP} --overwrite -n ${PROJECT}
# MLBParks setup complete #

# NationalParks #
APP=nationalparks
APPNAME="National Parks (Dev)"
PROJECT=${GUID}-parks-dev
BASEIMAGE=redhat-openjdk18-openshift:1.2

oc new-build --binary=true --name="${APP}" ${BASEIMAGE} -n ${PROJECT}
oc new-app ${PROJECT}/${APP}:0.0-0 --name=${APP} --allow-missing-imagestream-tags=true -n ${PROJECT}
oc set triggers dc/${APP} --remove-all -n ${PROJECT}
oc set resources dc/${APP} --limits=cpu=500m,memory=1Gi --requests=cpu=250m,memory=512Mi -n ${PROJECT}
oc set env dc/${APP} DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=${MONGODB_USER} DB_PASSWORD=${MONGODB_PASSWORD} DB_NAME=${MONGODB_DATABASE} -n ${PROJECT}
oc create configmap ${APP}-config --from-literal=APPNAME="${APPNAME}" -n ${PROJECT}
oc set env --from=configmap/${APP}-config dc/${APP} -n ${PROJECT}
oc set probe dc/${APP} -n ${PROJECT} --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/${APP} -n ${PROJECT} --readiness --failure-threshold 3 --initial-delay-seconds 30 --get-url=http://:8080/ws/healthz/
oc expose dc ${APP} --port 8080 -n ${PROJECT}
sleep 5
oc set deployment-hook dc/${APP} -n ${PROJECT} --post --failure-policy=abort -- sh -c "sleep 10 && curl -i -X GET http://$(oc get service ${APP} -o jsonpath='{ .spec.clusterIP }' -n ${PROJECT}):8080/ws/data/load/" 
oc label svc ${APP} type=parksmap-backend app=${APP} --overwrite -n ${PROJECT}

# NationalParks setup complete#

# ParksMap #
APP=parksmap
APPNAME="ParksMap (Dev)"
PROJECT=${GUID}-parks-dev
BASEIMAGE=redhat-openjdk18-openshift:1.2

oc policy add-role-to-user view --serviceaccount=default -n ${PROJECT}

oc new-build --binary=true --name="${APP}" ${BASEIMAGE} -n ${PROJECT}
oc new-app ${PROJECT}/${APP}:0.0-0 --name=${APP} --allow-missing-imagestream-tags=true -n ${PROJECT}
oc set triggers dc/${APP} --remove-all -n ${PROJECT}
oc set resources dc/${APP} --limits=cpu=500m,memory=1Gi --requests=cpu=250m,memory=512Mi -n ${PROJECT}
oc create configmap ${APP}-config --from-literal=APPNAME="${APPNAME}" -n ${PROJECT}
oc set env --from=configmap/${APP}-config dc/${APP} -n ${PROJECT}
oc set probe dc/${APP} -n ${PROJECT} --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/${APP} -n ${PROJECT} --readiness --failure-threshold 3 --initial-delay-seconds 30 --get-url=http://:8080/ws/healthz/
oc expose dc ${APP} --port 8080 -n ${PROJECT}
oc expose service ${APP} -n ${PROJECT}
# ParksMap setup complete#


while : ; do
  echo "Checking if MongoDB_DEV is Ready..."
  oc get pod -n ${GUID}-parks-dev|grep mongodb|grep -v deploy|grep -v build|grep "1/1"
  [[ "$?" == "1" ]] || break
  echo "...no. Sleeping 10 seconds."
  sleep 10
done

echo "****************************************"
echo "Development Environment setup complete"
echo "****************************************"

exit 0