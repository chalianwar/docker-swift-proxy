#!/bin/bash

#
# Make the rings if they don't exist already
#

# These can be set with docker run -e VARIABLE=X at runtime
SWIFT_PART_POWER=${SWIFT_PART_POWER:-7}
SWIFT_PART_HOURS=${SWIFT_PART_HOURS:-1}
SWIFT_REPLICAS=${SWIFT_REPLICAS:-1}
SWIFT_PWORKERS=${SWIFT_PWORKERS:-8}
SWIFT_OBJECT_NODES=${SWIFT_OBJECT_NODES:-172.17.0.3:6010;172.17.0.4:6010}

if [ -e /srv/account.builder ]; then
	echo "Ring files already exist in /srv, copying them to /etc/swift..."
	cp /srv/*.builder /etc/swift/
	cp /srv/*.gz /etc/swift/
fi

# This comes from a volume, so need to chown it here, not sure of a better way
# to get it owned by Swift.
chown -R swift:swift /srv

cd /etc/swift

# 2^& = 128 we are assuming just one drive
# 1 replica only

echo "Ring files, creating them..."


swift-ring-builder object.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}
swift-ring-builder container.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}
swift-ring-builder account.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}


for SWIFT_OBJECT_NODE  in $(echo $SWIFT_OBJECT_NODES | tr ";" "\n"); do

	# Calculate port
	SWIFT_OBJECT_DEVICE=`sed "s/.*://g" <<< $SWIFT_OBJECT_NODE`
        SWFIT_OBJECT_PORT=`sed "s/.*:\(.*\):.*/\1/" <<< $SWIFT_OBJECT_NODE`
        SWIFT_OBJECT_NODE=`sed "s/:.*//g" <<< $SWIFT_OBJECT_NODE`

	# add files
	swift-ring-builder object.builder add r1z1-${SWIFT_OBJECT_NODE}:$SWFIT_OBJECT_PORT/$SWIFT_OBJECT_DEVICE 1
	swift-ring-builder container.builder add r1z1-${SWIFT_OBJECT_NODE}:$(($SWFIT_OBJECT_PORT + 1))/$SWIFT_OBJECT_DEVICE 1
	swift-ring-builder account.builder add r1z1-${SWIFT_OBJECT_NODE}:$(($SWFIT_OBJECT_PORT + 2))/$SWIFT_OBJECT_DEVICE 1
done

swift-ring-builder object.builder rebalance
swift-ring-builder container.builder rebalance
swift-ring-builder account.builder rebalance

echo ${SWIFT_OBJECT_NODE}:$(($SWFIT_OBJECT_PORT + 2)) > temp.txt

# Back these up for later use
echo "Copying ring files to /srv to save them if it's a docker volume..."
cp *.gz /srv
cp *.builder /srv

sshpass -p "kevin" scp -r -o StrictHostKeyChecking=no  *.gz root@192.168.0.171:~/files

# If you are going to put an ssl terminator in front of the proxy, then I believe
# the storage_url_scheme should be set to https. So if this var isn't empty, set
# the default storage url to https.
if [ ! -z "${SWIFT_STORAGE_URL_SCHEME}" ]; then
	echo "Setting default_storage_scheme to https in proxy-server.conf..."
	sed -i -e "s/storage_url_scheme = default/storage_url_scheme = https/g" /etc/swift/proxy-server.conf
	grep "storage_url_scheme" /etc/swift/proxy-server.conf
fi

if [ ! -z "${SWIFT_SET_PASSWORDS}" ]; then
	echo "Setting passwords in /etc/swift/proxy-server.conf"
	PASS=`pwgen 12 1`
	sed -i -e "s/user_admin_admin = admin .admin .reseller_admin/user_admin_admin = $PASS .admin .reseller_admin/g" /etc/swift/proxy-server.conf
	sed -i -e "s/user_test_tester = testing .admin/user_test_tester = $PASS .admin/g" /etc/swift/proxy-server.conf
	sed -i -e "s/user_test2_tester2 = testing2 .admin/user_test2_tester2 = $PASS .admin/g" /etc/swift/proxy-server.conf
	sed -i -e "s/user_test_tester3 = testing3/user_test_tester3 = $PASS/g" /etc/swift/proxy-server.conf
	grep "user_test" /etc/swift/proxy-server.conf
fi

# Set the number of proxy workers and object workers on fly
sed -i "s/workers.*/workers = $SWIFT_PWORKERS/g" /etc/swift/proxy-server.conf

# Start supervisord
echo "Starting supervisord..."
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

#
# Tail the log file for "docker log $CONTAINER_ID"
#

# sleep waiting for rsyslog to come up under supervisord
sleep 3

echo "Starting to tail /var/log/syslog...(hit ctrl-c if you are starting the container in a bash shell)"

tail -n 0 -f /var/log/syslog
