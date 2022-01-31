#!/bin/bash
#set -xe

echo
echo " Running /entrypoint.sh (bootstrap-worker.sh) as user: `whoami`"
echo

echo "export ALLUXIO_HOME=/opt/alluxio" >> /etc/profile
echo "export PATH=\$PATH:\$ALLUXIO_HOME/bin" >> /etc/profile
. /etc/profile 

# If a new Alluxio install tarball was specified, install it
if [ "$ALLUXIO_TARBALL" != "" ]; then
        if [ ! -f /tmp/alluxio-install/$ALLUXIO_TARBALL ]; then
                echo " ERROR: Cannot install Alluxio tarball - file not found: $ALLUXIO_TARBALL" | tee -a /opt/alluxio/logs/worker.log
        else
                echo " ### Installing Alluxio tarball: $ALLUXIO_TARBALL" | tee -a /opt/alluxio/logs/worker.log

                ORIG_PWD=$(pwd) && cd /

                # Remove the soft link
                rm -f /opt/alluxio

                # Save the old release and install the new release
                orig_dir_name=$(ls /opt | grep alluxio-enterprise)
                if [ "$orig_dir_name" != "" ]; then
                        #mv /opt/$orig_dir_name /opt/${orig_dir_name}.orig
			rm -rf /opt/$orig_dir_name

                        # Untar the new release to /opt/
                        tar zxf /tmp/alluxio-install/$ALLUXIO_TARBALL -C /opt/

                        # Recreate the soft link
                        #new_dir_name=$(echo $ALLUXIO_TARBALL | sed 's/-bin.tar.gz//')
                        new_dir_name=$(ls /opt | grep alluxio-enterprise | grep -v $orig_dir_name)
                        ln -s /opt/$new_dir_name /opt/alluxio
                fi
		cd $ORIG_PWD
        fi
fi

# Copy Alluxio config files
cp /tmp/alluxio-install/license.json /opt/alluxio/
cp /tmp/alluxio-install/conf/* /opt/alluxio/conf/

# Set owner and access of release
chown -R root:root /opt/alluxio-enterprise-*
chmod go+rw /opt/alluxio-enterprise-*/logs/user

# Create a test alluxio user
echo "alluxio-users:x:1001:alluxio-users" >> /etc/group
echo "user1:x:1001:1001:Alluxio User 1,,,:/tmp:/bin/bash" >> /etc/passwd
echo "user2:x:1002:1001:Alluxio User 2,,,:/tmp:/bin/bash" >> /etc/passwd

# Format the worker node ramdisk
$ALLUXIO_HOME/bin/alluxio formatWorker

# Start the worker node daemons
nohup $ALLUXIO_HOME/bin/launch-process worker NoMount &
$ALLUXIO_HOME/bin/alluxio-start.sh job_worker
$ALLUXIO_HOME/bin/alluxio-start.sh proxy

tail -f $ALLUXIO_HOME/logs/worker.log
