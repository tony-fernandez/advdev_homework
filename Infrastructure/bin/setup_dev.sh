#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

DB_HOST=mongodb
DB_PORT=27017
DB_USERNAME=mongodb
DB_PASSWORD=mongodb
DB_NAME=parks

MLBPARKS_DEV_CONFIG=mlbparks-dev-config
NATIONALPARKS_DEV_CONFIG=nationalparks-dev-config
PARKSMAP_DEV_CONFIG=parksmap-dev-config

GUID=$1
PARKS_DEV=${GUID}-parks-dev
echo "Setting up Parks Development Environment in project ${PARKS_DEV}"
# Switch to dev
oc project ${PARKS_DEV}

# Grant the correct permissions to the Jenkins service account
oc policy add-role-to-user view \
	--serviceaccount=default -n ${PARKS_DEV}
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n ${PARKS_DEV}
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${PARKS_DEV}
# Create a MongoDB database
echo "Setting up mongo database"
oc create -f ./Infrastructure/templates/mongo-service.yml -n ${PARKS_DEV}
oc create -f ./Infrastructure/templates/mongo-statefulset.yml -n ${PARKS_DEV}


#oc new-app --template=mongodb-persistent \
#	--param=MONGODB_USER=${DB_USERNAME} \
#	--param=MONGODB_PASSWORD=${DB_PASSWORD} \
#	--param=MONGODB_DATABASE=${DB_NAME} \
#	-n ${PARKS_DEV}

# Create binary build configurations for the pipelines to use for each microservice
oc new-build \
	--binary=true \
	--name="mlbparks" jboss-eap70-openshift:1.7 \
	-n ${PARKS_DEV}
oc new-build \
	--binary=true \
	--name="nationalparks" redhat-openjdk18-openshift:1.2 \
	-n ${PARKS_DEV}
oc new-build \
	--binary=true \
	--name="parksmap" redhat-openjdk18-openshift:1.2 \
	-n ${PARKS_DEV}
# Create ConfigMaps for configuration of the application
echo "Creating mlbparks-dev-config config map"
oc create configmap ${MLBPARKS_DEV_CONFIG} \
	--from-env-file=./Infrastructure/templates/mlbparks-dev.env \
	-n ${PARKS_DEV}

oc get configmaps ${MLBPARKS_DEV_CONFIG} -o yaml -n ${PARKS_DEV}

echo "Creating nationalparks-dev-config config map"
oc create configmap ${NATIONALPARKS_DEV_CONFIG} \
	--from-env-file=./Infrastructure/templates/nationalparks-dev.env \
	-n ${PARKS_DEV}

oc get configmaps ${NATIONALPARKS_DEV_CONFIG} -o yaml -n ${PARKS_DEV}

echo "Creating parksmap-dev-config config map"
oc create configmap ${PARKSMAP_DEV_CONFIG} \
	--from-env-file=./Infrastructure/templates/parksmap-dev.env \
	-n ${PARKS_DEV}

oc get configmaps ${PARKSMAP_DEV_CONFIG} -o yaml -n ${PARKS_DEV}

# Set up placeholder deployment configurations for the three microservices
oc new-app ${PARKS_DEV}/mlbparks:0.0-0 \
	--name=mlbparks \
	--allow-missing-imagestream-tags=true \
	-n ${PARKS_DEV}
oc new-app ${PARKS_DEV}/nationalparks:0.0-0 \
	--name=nationalparks \
	--allow-missing-imagestream-tags=true \
	-n ${PARKS_DEV}
oc new-app ${PARKS_DEV}/parksmap:0.0-0 \
	--name=parksmap \
	--allow-missing-imagestream-tags=true \
	-n ${PARKS_DEV}

oc set triggers dc/mlbparks --remove-all -n ${PARKS_DEV}
oc set triggers dc/nationalparks --remove-all -n ${PARKS_DEV}
oc set triggers dc/parksmap --remove-all -n ${PARKS_DEV}

# Configure the deployment configurations using the ConfigMaps
oc set env dc/mlbparks \
	--from=configmap/${MLBPARKS_DEV_CONFIG} \
	-n ${PARKS_DEV}
oc set env dc/nationalparks \
	--from=configmap/${NATIONALPARKS_DEV_CONFIG} \
	-n ${PARKS_DEV}
oc set env dc/parksmap \
	--from=configmap/${PARKSMAP_DEV_CONFIG} \
	-n ${PARKS_DEV}

oc expose dc mlbparks --port 8080 -n ${PARKS_DEV}
oc expose dc nationalparks --port 8080 -n ${PARKS_DEV}
oc expose dc parksmap --port 8080 -n ${PARKS_DEV}

# Expose and label the services properly
oc expose svc mlbparks \
	--labels="type=parksmap-backend" \
	-n ${PARKS_DEV}
oc expose svc nationalparks \
	--labels="type=parksmap-backend" \
	-n ${PARKS_DEV}
oc expose svc parksmap -n ${PARKS_DEV}

# Set up liveness and readiness probes
oc set probe dc/mlbparks \
	--liveness \
	--failure-threshold 5 \
	--initial-delay-seconds 30 \
	-- echo ok \
	-n ${PARKS_DEV}
oc set probe dc/mlbparks \
	--readiness \
	--failure-threshold 3 \
	--initial-delay-seconds 60 \
	--get-url=http://:8080/ws/healthz/ \
	-n ${PARKS_DEV}
oc set probe dc/nationalparks \
	--liveness \
	--failure-threshold 5 \
	--initial-delay-seconds 30 \
	-- echo ok \
	-n ${PARKS_DEV}
oc set probe dc/nationalparks \
	--readiness \
	--failure-threshold 3 \
	--initial-delay-seconds 60 \
	--get-url=http://:8080/ws/healthz/ \
	-n ${PARKS_DEV}
oc set probe dc/parksmap \
	--liveness \
	--failure-threshold 5 \
	--initial-delay-seconds 30 \
	-- echo ok \
	-n ${PARKS_DEV}
oc set probe dc/parksmap \
	--readiness \
	--failure-threshold 5 \
	--initial-delay-seconds 60 \
	--get-url=http://:8080/ws/healthz/ \
	-n ${PARKS_DEV}

# set deployment hooks to call /ws/data/load/ and populate the database for the back end services
oc set deployment-hook dc/mlbparks -n ${PARKS_DEV} --post -c mlbparks --failure-policy=abort -- curl http://$(oc get route mlbparks -o jsonpath='{ .spec.host }' -n ${PARKS_DEV})/ws/data/load/ 
oc set deployment-hook dc/nationalparks -n ${PARKS_DEV} --post -c nationalparks --failure-policy=abort -- curl http://$(oc get route nationalparks -o jsonpath='{ .spec.host }' -n ${PARKS_DEV})/ws/data/load/ 
oc set deployment-hook dc/parksmap -n ${PARKS_DEV} --post -c parksmap --failure-policy=abort -- curl http://$(oc get route parksmap -o jsonpath='{ .spec.host }' -n ${PARKS_DEV})/ws/data/load/ 

oc get dc mlbparks -o yaml -n ${PARKS_DEV}
oc get dc nationalparks -o yaml -n ${PARKS_DEV}
oc get dc parksmap -o yaml -n ${PARKS_DEV}

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