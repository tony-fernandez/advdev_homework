#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

MLB_PARKS_BLUE='MLB Parks (Blue)'
NATIONAL_PARKS_BLUE='National Parks (Blue)'
PARKS_MAP_BLUE='ParksMap (Blue)'
MLB_PARKS_GREEN='MLB Parks (Green)'
NATIONAL_PARKS_GREEN='National Parks (Green)'
PARKS_MAP_GREEN='ParksMap (Green)'
DB_HOST=mongodb
DB_PORT=27017
DB_USERNAME=mongodb
DB_PASSWORD=mongodb
DB_NAME=parks


GUID=$1
PARKS_PROD=${GUID}-parks-prod
PARKS_DEV=${GUID}-parks-dev
echo "Setting up Parks Production Environment in project ${PARKS_PROD}"

# switch to prod project
echo "Switching to ${PARKS_PROD} project"
oc project ${PARKS_PROD}

# grant the correct permissions to the Jenkins service account
echo "Granting jenkins permissions for ${PARKS_PROD} project"
oc policy add-role-to-user view --serviceaccount=default -n ${PARKS_PROD}
oc policy add-role-to-group system:image-puller system:serviceaccounts:${PARKS_PROD} -n ${PARKS_DEV}
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n ${PARKS_PROD}
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${PARKS_PROD}

# set up a MongoDB database
echo "Setting up mongodb for ${PARKS_PROD} project"
oc create -f ../templates/mongodb-headless-svc.yml -n ${PARKS_PROD}
oc create -f ../templates/mongodb-svc.yml -n ${PARKS_PROD}
oc create -f ../templates/mongodb-stateful.yml -n ${PARKS_PROD}

#configmaps
echo "Setting config maps for ${PARKS_PROD} project"
oc create mlbparks-blue-config \
	--from-literal=APPNAME=${MLB_PARKS_BLUE} \
    --from-literal=DB_HOST=${DB_HOST}
    --from-literal=DB_PORT=${DB_PORT}
    --from-literal=DB_USERNAME=${DB_USERNAME}
    --from-literal=DB_PASSWORD=${DB_PASSWORD}
    --from-literal=DB_NAME=${DB_NAME}
oc create nationalparks-blue-config \
	--from-literal=APPNAME=${NATIONAL_PARKS_BLUE} \
    --from-literal=DB_HOST=${DB_HOST}
    --from-literal=DB_PORT=${DB_PORT}
    --from-literal=DB_USERNAME=${DB_USERNAME}
    --from-literal=DB_PASSWORD=${DB_PASSWORD}
    --from-literal=DB_NAME=${DB_NAME}
oc create parksmap-blue-config \
	--from-literal=APPNAME=${PARKS_MAP_BLUE} \
    --from-literal=DB_HOST=${DB_HOST}
    --from-literal=DB_PORT=${DB_PORT}
    --from-literal=DB_USERNAME=${DB_USERNAME}
    --from-literal=DB_PASSWORD=${DB_PASSWORD}
    --from-literal=DB_NAME=${DB_NAME}
oc create mlbparks-green-config \
	--from-literal=APPNAME=${MLB_PARKS_GREEN} \
    --from-literal=DB_HOST=${DB_HOST}
    --from-literal=DB_PORT=${DB_PORT}
    --from-literal=DB_USERNAME=${DB_USERNAME}
    --from-literal=DB_PASSWORD=${DB_PASSWORD}
    --from-literal=DB_NAME=${DB_NAME}
oc create nationalparks-green-config \
	--from-literal=APPNAME=${NATIONAL_PARKS_GREEN} \
    --from-literal=DB_HOST=${DB_HOST}
    --from-literal=DB_PORT=${DB_PORT}
    --from-literal=DB_USERNAME=${DB_USERNAME}
    --from-literal=DB_PASSWORD=${DB_PASSWORD}
    --from-literal=DB_NAME=${DB_NAME}
oc create parksmap-green-config \
	--from-literal=APPNAME=${PARKS_MAP_GREEN} \
    --from-literal=DB_HOST=${DB_HOST}
    --from-literal=DB_PORT=${DB_PORT}
    --from-literal=DB_USERNAME=${DB_USERNAME}
    --from-literal=DB_PASSWORD=${DB_PASSWORD}
    --from-literal=DB_NAME=${DB_NAME}
    
#blue
echo "Blue app for ${PARKS_PROD} project"
oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=mlbparks-blue --allow-missing-imagestream-tags=true -n ${PARKS_PROD}
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=nationalparks-blue --allow-missing-imagestream-tags=true -n ${PARKS_PROD}
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=parksmap-blue --allow-missing-imagestream-tags=true -n ${PARKS_PROD}

oc set triggers dc/mlbparks-blue --remove-all -n ${PARKS_PROD}
oc set triggers dc/nationalparks-blue --remove-all -n ${PARKS_PROD}
oc set triggers dc/parksmap-blue --remove-all -n ${PARKS_PROD}

oc set env dc/mlbparks-blue --from=configmap/mlbparks-blue-config -n ${PARKS_PROD}
oc set env dc/nationalparks-blue --from=configmap/nationalparks-blue-config -n ${PARKS_PROD}
oc set env dc/parksmap-blue --from=configmap/parksmap-blue-config -n ${PARKS_PROD}

#green
echo "Green app for ${PARKS_PROD} project"
oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=mlbparks-green --allow-missing-imagestream-tags=true -n ${PARKS_PROD}
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=nationalparks-green --allow-missing-imagestream-tags=true -n ${PARKS_PROD}
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=parksmap-green --allow-missing-imagestream-tags=true -n ${PARKS_PROD}

oc set triggers dc/mlbparks-green --remove-all -n ${PARKS_PROD}
oc set triggers dc/nationalparks-green --remove-all -n ${PARKS_PROD}
oc set triggers dc/parksmap-green --remove-all -n ${PARKS_PROD}

oc set env dc/mlbparks-green --from=configmap/mlbparks-green-config -n ${PARKS_PROD}
oc set env dc/nationalparks-green --from=configmap/nationalparks-green-config -n ${PARKS_PROD}
oc set env dc/parksmap-green --from=configmap/parksmap-green-config -n ${PARKS_PROD}

#expose
echo "Exposing dc for ${PARKS_PROD} project"
oc expose dc mlbparks-green --port 8080 -n ${PARKS_PROD}
oc expose dc nationalparks-green --port 8080 -n ${PARKS_PROD}
oc expose dc parksmap-green --port 8080 -n ${PARKS_PROD}

oc expose dc mlbparks-blue --port 8080 -n ${PARKS_PROD}
oc expose dc nationalparks-blue --port 8080 -n ${PARKS_PROD}
oc expose dc parksmap-blue --port 8080 -n ${PARKS_PROD}

#set green live
echo "Setting green for ${PARKS_PROD} project"
oc expose svc mlbparks-green --name mlbparks -n ${PARKS_PROD} --labels="type=parksmap-backend"
oc expose svc nationalparks-green --name nationalparks -n ${PARKS_PROD} --labels="type=parksmap-backend"
oc expose svc parksmap-green --name parksmap -n ${PARKS_PROD}

oc set deployment-hook dc/mlbparks-green  -n ${PARKS_PROD} --post -c mlbparks-green --failure-policy=ignore -- curl http://mlbparks-green.${PARKS_PROD}.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/nationalparks-green  -n ${PARKS_PROD} --post -c nationalparks-green --failure-policy=ignore -- curl http://nationalparks-green${PARKS_PROD}.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/parksmap-green  -n ${PARKS_PROD} --post -c parksmap-green --failure-policy=ignore -- curl http://mlbparks-green.${PARKS_PROD}.svc.cluster.local:8080/ws/data/load/

oc set deployment-hook dc/mlbparks-blue  -n ${PARKS_PROD} --post -c mlbparks-blue --failure-policy=ignore -- curl http://mlbparks-blue.${PARKS_PROD}.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/nationalparks-blue  -n ${PARKS_PROD} --post -c nationalparks-blue --failure-policy=ignore -- curl http://nationalparks-blue.${PARKS_PROD}.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/parksmap-blue  -n ${PARKS_PROD} --post -c parksmap-blue --failure-policy=ignore -- curl http://mlbparks-blue.${PARKS_PROD}.svc.cluster.local:8080/ws/data/load/

# set liveness and readiness probes
oc set probe dc/parksmap-blue -n ${PARKS_PROD} --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok
oc set probe dc/parksmap-blue --readiness --failure-threshold 5 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${PARKS_PROD}
oc set probe dc/mlbparks-blue -n ${PARKS_PROD} --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok
oc set probe dc/mlbparks-blue --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${PARKS_PROD}
oc set probe dc/nationalparks-blue -n ${PARKS_PROD} --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok
oc set probe dc/nationalparks-blue --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${PARKS_PROD}
oc set probe dc/parksmap-green -n ${PARKS_PROD} --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok
oc set probe dc/parksmap-green --readiness --failure-threshold 5 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${PARKS_PROD}
oc set probe dc/mlbparks-green -n ${PARKS_PROD} --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok
oc set probe dc/mlbparks-green --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${PARKS_PROD}
oc set probe dc/nationalparks-green -n ${PARKS_PROD} --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok
oc set probe dc/nationalparks-green --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${PARKS_PROD}

