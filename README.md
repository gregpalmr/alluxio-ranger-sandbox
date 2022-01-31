# alluxio-ranger-sandbox

Run Alluxio Enterprise Edition with Apache Ranger for Authorizations

This repo contains docker compose artifacts that launch a small Alluxio cluster that also runs Apache Hadoop and Apache Ranger.  

## Usage:

### Step 1. Install docker and docker-compose

#### MAC:

See: https://docs.docker.com/desktop/mac/install/

#### LINUX:

Install the docker package

     sudo yum -y install docker

Increase the ulimit in /etc/sysconfig/docker

     sudo sed -i 's/nofile=32768:65536/nofile=1024000:1024000/' /etc/sysconfig/docker

     sudo service docker start

Add your user to the docker group

     sudo usermod -a -G docker ec2-user

Logout and back in to get new group membershiop

     exit

     ssh ...

Install the docker-compose package

     DOCKER_COMPOSE_VERSION="1.23.2"

     sudo  curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose

     sudo chmod +x /usr/local/bin/docker-compose

### Step 2. Clone this repo:

     git clone https://github.com/gregpalmr/alluxio-ranger-sandbox

     cd alluxio-ranger-sandbox

### Step 3. Copy your Alluxio Enterprise license file

If you don't already have an Alluxio Enterprise license file, contact your Alluxio salesperson at sales@alluxio.com.  Copy your license file to the alluxio staging directory:

     cp ~/Downloads/alluxio-enterprise-license.json config/alluxio/alluxio/

### Step 4. (Optional) Install your own Alluxio release

If you want to test your own Alluxio release, instead of using the release bundled with the docker image, follow these steps:

a. Copy your Alluxio tarball file (.tar.gz) to a directory accessible by the docker-compose utility.

b. Modify the docker-compose.yml file, to "mount" that file as a volume. The target mount point must be in "/tmp/alluxio-install/". For example:

     volumes:
       - ~/Downloads/alluxio-enterprise-2.7.0-SNAPSHOT-bin.tar.gz:/tmp/alluxio-install/alluxio-enterprise-2.7.0-SNAPSHOT-bin.tar.gz 

c. Add an environment variable identifying the tarball file name. For example:

     environment:
       ALLUXIO_TARBALL: alluxio-enterprise-2.7.0-SNAPSHOT-bin.tar.gz 

NOTE: You must do this for the alluxio-master service and the alluxio-worker service.

### Step 5. Start the docker network and docker containers

First, create a network:

     docker network create alluxio-ranger-sandbox-env

Then, use the docker compose script to start the Ranger and Alluxio containers.

     docker-compose up -d 

You can see the log output of the Alluxio containers using these commands:

     docker logs -f alluxio-master

     docker logs -f alluxio-worker

You can see the log output of the Ranger containers suing these commands:

     docker logs -f ranger-admin

     docker logs -f ranger-es

When finished working with the containers, you can stop them with the commands:

     docker-compose down

If you are done testing and do not intend to spin up the docker images again, remove the network and disk volumes with the commands:

     docker volume rm ranger_db_data ranger_es_data ranger_keystore alluxio-ranger-sandbox_ufs_storage

     docker network rm alluxio-ranger-sandbox_custom

### Step 6. Restrict access to the Alluxio file system

When a Ranger policy is not available for a specific path, Alluxio will fall back to its own POSIX style permissions to determine if a user has access permissions on a directory or file. Therefore, it is recommended that all users except for the privileged root user be denied access to all the directories except for the /tmp directory and their own home directory (if they have one). To enforce this, run the following Alluxio cli commands:

     docker exec -it alluxio-master bash

     alluxio fs chmod 077 /
     alluxio fs chmod 077 /user
     alluxio fs chmod 077 /...

Include any sub-directories that should be managed by Ranger policies.

Open a BASH shell session the Alluxio master node and attempt to access the /user directory as a non-root user. A permission denied message like this will be displayed:

     docker exec -it alluxio-master bash

     sudo su - user1

     id
     uid=1001(user1) gid=1001(alluxio-users)

     alluxio fs ls /user/
     Permission denied by authorization plugin: alluxio.exception.AccessControlException: Permission denied: user=user1, access=r--, path=/user: failed at user, inode owner=root, inode group=root, inode mode=rwx------

### Step 7. Define an "allow" policy in Ranger

#### a. Sign in to the Ranger Web UI

Point your browser to the Ranger Web UI at https://localhost:6182

Sign in with the username and password:

     Username: admin

     Password: rangeradmin1

#### b. Create a new service by clicking on the "Service Manager" link and then clicking on the "Create Service" button. 

In the "Service Details" section, define the HDFS service type with the following settings:

     Service Name: alluxio-datacenter1-test

     Display Name: alluxio-datacenter1-test

     Acive Status: Enabled

In the "Config Properties" section, define the following values:

     Username: admin

     Password: rangeradmin1

     Namenode URL: alluxio://alluxio-master:19998

     Authorization Enabled: Yes

    Common Name for Certificate: Alluxio-Ranger

The "Common Name for Certificate" is set to the "CN=" value that was used in the Alluxio/Ranger signed certificates (CN=Alluxio-Ranger, OU=Alluxio, L=San Mateo, ST=CA, C=US). 

Click the "Add" button to add this new service definition.

Verify that the service was created by clicking on the "Plugins" link at the top of the page. You should see an entry for "alluxio@alluxio-master-hdfs" because the Alluxio master was configured to integrate with Ranger with the Alluxio Ranger (HDFS type) Plugin.







#### c. Test access to the Alluxio filesystem

Open a command shell into the Alluxio master container.

     docker exec -it alluxio-master bash

Verify that the root user cannot access the Alluxio virtual filesystem using the "alluxio fs" command. This test environment is configured to have Alluxio use HDFS as the "under filesystem" or UFS. Therefore, using the "alluxio fs" command, you should be able to see the directories in the HDFS UFS. Like this:

     alluxio fs ls /
          drwxr-xr-x  root    supergroup   0  PERSISTED 10-30-2021 16:11:22:337  DIR /user
          drwxrwxr-x  root    supergroup   0  PERSISTED 10-30-2021 16:11:55:662  DIR /tmp
          drwxr-xr-x  root    supergroup   0  PERSISTED 10-30-2021 16:11:09:971  DIR /rmstate

#### d. Define a new Ranger policy for the Alluxio service

Click on the Ranger icon on the top of the page. Then, in the "Service Manager" section, click on the "alluxio" service link. This will display the policies for the "alluxio" service. Click on the "Add New Policy" button to display the "Create Policy" page.

In the "Policy Details" section, enter:

     Name for the Policy: block-root-access

     Resource Path to apply the policy: /

     Description: Block root directory access in the Alluxio filesystem

In the "Deny Conditions" section, enter:

     Select User: {USER}

     Permissions: Execute, Read, Write

The "{USER}" specification means that all users will be applied to this deny condition.

Save the new policy by clicking on the "Add" button.

#### e. Test the new "Deny" policy in Alluxio

Open a command shell into the Alluxio master container.

     docker exec -it alluxio-master bash

Verify that the root user cannot access the Alluxio virtual filesystem's root directory. You should not be able to see the underlying HDFS directories, but should see a "permission denied" message like this:

     alluxio fs ls /
          Permission denied by authorization plugin: Permission denied: user=root, access=READ, inode="/"

#### f. Check the Ranger audit log

Back on the Ranger Admin Web UI, click on the "Audit" link at the top of the page. Then click on the "Access" tab and you will see an event documenting the policy enforcement.

### Step 7. Define an exception to the "Deny" policy in Ranger 

#### a. Define a new group and two new users in Ranger

In the Ranger Web UI, click on the "Settings" link at the top of the page and then click on "Users/Groups/Roles" link.  Then, click on the "Groups" tab and click on the "Add New Group" button.

In the "Group Detail" section, enter the following:

     Group Name: alluxio-users

     Group Description: Alluxio Users

Then click the "Save" button to add the new group.

In the Ranger Web UI, click on the "Settings" link at the top of the page and then click on "Users/Groups/Roles" link.  Then, click on the "Add New User" button.

In the "User Detail" section, enter the following:

     User Name: user1

     New Password: changeme123

     First Name: Alluxio

     Select Role: User

     Select Group: users

Then click the "Save" button to add the new user.

Add a second user by clicking on the "Add New User" button.

In the "User Detail" section, enter the following:

     User Name: user2

     New Password: changeme123

     First Name: Alluxio

     Select Role: User

     Select Group: users

Then click the "Save" button to add the second  user.

#### b. Modify the "block-root-access" policy in Ranger

Click on the "Access Manager" link at the top of the page and then click on "Resource Based Policies" link.

Click on the "alluxio" service policies to display a list of existing policies (includeing the "block-root-access" policy created in step 5). Then click the edit action icon for the "block-root-access" policy.

In the "Deny Conditions" section, add a reference to the new group "alluxio-users" in the "Exlude from Deny Conditions". enter the following:

     Select Group: alluxio-users

     Permissions: Execute, Read, Write

Then, click the "Save" button to save the modified policy.

#### c. Test the new "Exclude from Deny" policy in Alluxio

First, change the permissions in the HDFS under filesystem:

     docker exec namenode bash -c "hdfs dfs -chmod 777 /tmp ; hdfs dfs -chmod 777 /user"
  
Then, open a command shell into the Alluxio master container.

     docker exec -it allusio-master bash

Become the first alluxio user:

     su - user1

Verify that the user can access the /user directory in the Alluxio filesystem. Because user1 is in the alluxio-users group, you should be able to see the root directory contents, from the HDFS under filesystem.

     alluxio fs ls /
          drwxrwxrwx  root  supergroup  1  PERSISTED 11-12-2021 00:12:46:332  DIR /user
          drwxrwxrwx  root  supergroup  0  PERSISTED 11-12-2021 00:13:34:335  DIR /tmp
          drwxr-xr-x  root  supergroup  0  PERSISTED 11-12-2021 00:12:46:517  DIR /rmstate

     exit

Become the second alluxio user:

     su - user2

Verify that the user can access the /user directory in the Alluxio filesystem. Because user2 is also in the alluxio-users group, you should be able to see the root directory contents, from the HDFS under filesystem.

     alluxio fs ls /
          drwxrwxrwx  root  supergroup  1  PERSISTED 11-12-2021 00:12:46:332  DIR /user
          drwxrwxrwx  root  supergroup  0  PERSISTED 11-12-2021 00:13:34:335  DIR /tmp
          drwxr-xr-x  root  supergroup  0  PERSISTED 11-12-2021 00:12:46:517  DIR /rmstate

     exit

#### d. Check the Alluxio master logs

To verify that Alluxio is reading the access policies from Apache Ranger, you can view the log file for the Alluxio master container like this:

     docker logs -f alluxio-master

Then access HDFS via Alluxio as shown in step 6.c above. You will see entries in the Alluxio master node container that show "xaaudit" events:

     2021-11-01 14:42:36,532 INFO  BaseAuditHandler - Audit Status Log: name=hdfs.async.batch.log4j, interval=05:23.849 minutes, events=2, succcessCount=2, totalEvents=18, totalSuccessCount=18

     2021-11-01 14:42:36,532 INFO  xaaudit - {"repoType":1,"repo":"hdfs","reqUser":"user1","evtTime":"2021-11-01 14:42:34.683","access":"READ","resource":"/user","resType":"path","action":"read","result":1,"agent":"hdfs","policy":-1,"reason":"/user","enforcer":"hadoop-acl","agentHost":"alluxio-master","logType":"RangerAudit","id":"f2e39748-0185-44eb-a018-e18e503e70b1-0","seq_num":1,"event_count":1,"event_dur_ms":0,"tags":[],"additional_info":", \"accessTypes\":[read]","cluster_name":""}

     2021-11-01 14:42:36,533 INFO  xaaudit - {"repoType":1,"repo":"hdfs","reqUser":"user1","evtTime":"2021-11-01 14:42:34.684","access":"EXECUTE","resource":"/user","resType":"path","action":"execute","result":1,"agent":"hdfs","policy":-1,"reason":"/user","enforcer":"hadoop-acl","agentHost":"alluxio-master","logType":"RangerAudit","id":"80bbe1fd-0655-4dbc-bacc-09fb993a5085-0","seq_num":1,"event_count":1,"event_dur_ms":0,"tags":[],"additional_info":", \"accessTypes\":[execute]","cluster_name":""}

     2021-11-01 14:42:54,518 INFO  BaseAuditHandler - Audit Status Log: name=hdfs.async.batch, finalDestination=hdfs.async.batch.log4j, interval=01:02.978 minutes, events=5, succcessCount=2, totalEvents=51, totalSuccessCount=20

---

Please direct questions and comments to greg.palmer@alluxio.com

NOTE: The Ranger and Hadoop containers are based on work done by kadensungbinchoa:

See https://medium.com/swlh/hands-on-apache-ranger-docker-poc-with-hadoop-hdfs-hive-presto-814344a03a17

