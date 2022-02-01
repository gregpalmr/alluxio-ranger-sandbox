#!/bin/bash
#set -xe

echo
echo " Running /entrypoint.sh (bootstrap-master.sh) as user: `whoami`"
echo

echo "export ALLUXIO_HOME=/opt/alluxio" >> /etc/profile
echo "export PATH=\$PATH:\$ALLUXIO_HOME/bin" >> /etc/profile
sed -i '/PS1/d' /etc/profile
echo "export PS1='\u@\h $ '" >> /etc/profile
. /etc/profile

# If a new Alluxio install tarball was specified, install it
if [ "$ALLUXIO_TARBALL" != "" ]; then

	if [ ! -f /tmp/alluxio-install/$ALLUXIO_TARBALL ]; then
		echo " ERROR: Cannot install Alluxio tarball - file not found: /tmp/alluxio-install/$ALLUXIO_TARBALL" | tee -a /opt/alluxio/logs/master.log
	else
		echo " ### Installing Alluxio tarball: /tmp/alluxio-install/$ALLUXIO_TARBALL" | tee -a /opt/alluxio/logs/master.log

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

			echo " ### CONTENTS of /opt/"
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
grep alluxio-users /etc/group
if [ "$?" != 0 ]; then
     echo "alluxio-users:x:1001:alluxio-users" >> /etc/group
fi
grep user1 /etc/passwd
if [ "$?" != 0 ]; then
     echo "user1:x:1001:1001:Alluxio User 1,,,:/tmp:/bin/bash" >> /etc/passwd
     echo "user2:x:1002:1001:Alluxio User 2,,,:/tmp:/bin/bash" >> /etc/passwd
fi

# Create a "/user" directory and "/tmp" directory in the under-filesystem (UFS)
if [ ! -f /data/alluxio/user ]; then
     echo "John Smith,jsmith@email.com,555-1212" > /tmp/customers.csv
     echo "Janis Joplin,jjoplin@email.com,555-1212" >> /tmp/customers.csv
     echo "Frank Wright,fwright@email.com,555-1212" > /tmp/customers2.csv
     echo "Cindy Penderson,cpenderson@email.com,555-1212" >> /tmp/customers2.csv
     mkdir -p /data/alluxio/user
     mkdir -p /data/alluxio/user/user1
     mkdir -p /data/alluxio/user/user2
     mkdir -p /data/alluxio/tmp
     mkdir -p /data/alluxio/sensitive_data1/dataset1
     mkdir -p /data/alluxio/sensitive_data2/dataset1
     cp /tmp/customers.csv  /data/alluxio/sensitive_data1/dataset1/data_file_000
     cp /tmp/customers2.csv /data/alluxio/sensitive_data2/dataset1/data_file_000
fi

# Enable the "sticky" bit on the user dir and tmp dir
chmod 1777  /data/alluxio/user 
chmod 1777  /data/alluxio/tmp 
chmod -R 700  /data/alluxio/sensitive_data1
chmod -R 700  /data/alluxio/sensitive_data2
chown user1 /data/alluxio/user/user1
chmod  700  /data/alluxio/user/user1
chown user2 /data/alluxio/user/user2
chmod  700  /data/alluxio/user/user2

# Format the master node journal
$ALLUXIO_HOME/bin/alluxio formatJournal

# Start the master node daemons
$ALLUXIO_HOME/bin/alluxio-start.sh master
$ALLUXIO_HOME/bin/alluxio-start.sh job_master
$ALLUXIO_HOME/bin/alluxio-start.sh proxy

tail -f $ALLUXIO_HOME/logs/master.log
