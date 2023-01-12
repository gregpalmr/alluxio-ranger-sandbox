# alluxio-ranger-sandbox

Run Alluxio Enterprise Edition with Apache Ranger for Authorizations using Docker containers

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

     cp ~/Downloads/alluxio-enterprise-license.json config/alluxio/

### Step 4. (Optional) Install your own Alluxio release

If you want to test your own Alluxio release, instead of using the release bundled with the docker image, follow these steps:

a. Copy your Alluxio tarball file (.tar.gz) to a directory accessible by the docker-compose utility.

b. Modify the docker-compose.yml file, and add a new entry to the "volumes:" section for the alluxio-master and alluxio-worker services. The purpose is to "mount" your tarball file as a volume and the target mount point must be in "/tmp/alluxio-install/". For example:

     volumes:
       - ~/Downloads/alluxio-enterprise-2.7.0-SNAPSHOT-bin.tar.gz:/tmp/alluxio-install/alluxio-enterprise-2.7.0-SNAPSHOT-bin.tar.gz 

c. Add a new environment variable to the alluxio-master and alluxio-worker services, identifying the tarball file name. For example:

     environment:
       ALLUXIO_TARBALL: alluxio-enterprise-2.7.0-SNAPSHOT-bin.tar.gz 

NOTE: You must do this for the alluxio-master service and the alluxio-worker service.

### Step 5. Start the docker network and docker containers

Use the docker compose script to start the Ranger and Alluxio containers.

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

     docker volume rm \
            alluxio-ranger-sandbox_db_data \
            alluxio-ranger-sandbox_es_data \
            alluxio-ranger-sandbox_keystore \
            alluxio-ranger-sandbox_ufs_storage

     docker network rm alluxio-ranger-sandbox_custom

### Step 6. Restrict access to the Alluxio file system

When a Ranger policy is not available for a specific path, Alluxio will fall back to its own POSIX style permissions to determine if a user has access permissions on a directory or file. Therefore, it is recommended that all users except for the privileged root user be denied access to all the directories except for the /tmp directory and their own home directory (if they have one). To enforce this, run the following Alluxio cli commands:

     docker exec -it alluxio-master bash --login

     alluxio fs chmod 777 /
     alluxio fs chmod 777 /user
     alluxio fs chmod 777 /tmp
     alluxio fs chmod 700 /sensitive_data1
     alluxio fs chmod 700 /sensitive_data2

Use the "chmod 700 ..." command on any other sub-directries that should be managed by Ranger policies.

### Step 7. Create an Alluxio Ranger Service

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

     Namenode URL: hdfs://localhost:8080  (This is not used by the Alluxio Ranger plugin)

     Authorization Enabled: Yes

    Common Name for Certificate: Alluxio-Ranger

The "Common Name for Certificate" is set to the "CN=" value that was used in the Alluxio/Ranger signed certificates (CN=Alluxio-Ranger, OU=Alluxio, L=San Mateo, ST=CA, C=US). 

Click the "Add" button to add this new service definition.

Verify that the service was created by clicking on the "Plugins" link at the top of the page. You should see an entry for "alluxio@alluxio-master-hdfs" because the Alluxio master was configured to integrate with Ranger with the Alluxio Ranger (HDFS type) Plugin.

### Step 8. Define an "Allow" policy in Ranger 

#### a. Define a new group and two new users in Ranger

In a production Ranger environment, users and groups would most likely be defined in an enterprise directory service like AD or LDAP. In this sanbox, users and groups are statically defined. In the Ranger Web UI, click on the "Settings" link at the top of the page and then click on "Users/Groups/Roles" link.  Then, click on the "Groups" tab and click on the "Add New Group" button.

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

     Select Group: alluxio-users

Then click the "Save" button to add the new user.

Add a second user by clicking on the "Add New User" button.

In the "User Detail" section, enter the following:

     User Name: user2

     New Password: changeme123

     First Name: Alluxio

     Select Role: User

     Select Group: alluxio-users

Then click the "Save" button to add the second  user.

#### b. Define a new Ranger "Allow" policy for the Alluxio service

Click on the Ranger icon on the top of the page. Then, in the "Service Manager" section, click on the "alluxio-datacenter1-test" service link. This will display the policies for the Alluxio service. Click on the "Add New Policy" button to display the "Create Policy" page.

In the "Policy Details" section, enter:

     Name for the Policy: allow-sensitive-data1-dir-access

     Resource Path to apply the policy: /sensitive_data1

     Description: Allow users to access the /sensitive_data1 directory 

     Recursive: Checked

In the "Allow Conditions" section, enter:

     Select Group: alluxio-users

     Permissions: Execute, Read

Save the new policy by clicking on the "Add" button.

### Step 9. Test access to the Alluxio file system

Use the Alluxio CLI commands to test access to the file system.

#### a. Open a shell session as the user1 user

Open a command shell into the Alluxio master container.

     docker exec -it alluxio-master bash --login

Become the user1 user.

     su - user1

#### b. Verify read access

Use the "alluxio fs" command to verify that user1 can access the /sensitive_data1 directory tree.

     alluxio fs ls /sensitive_data1/dataset1/
     -rw------- root root 283 PERSISTED 02-01-2022 14:59:45:457 100% /sensitive_data1/dataset1/data-file-000

#### c. Verify no write access

Verify that user1 cannot write to the /sensitive_data1 directory tree (since the Ranger policy did not allow writes).

     alluxio fs copyFromLocal /etc/motd /sensitive_data1/dataset1/
     Permission denied by authorization plugin: alluxio.exception.AccessControlException: Permission denied: user=user1, access=--x, path=/sensitive_data1/dataset1/motd: failed at /, inode owner=root, inode group=root, inode mode=rwx------

#### d. Verify no read, write access when no Ranger policy exists

Attempt to read from the /sensitive_data2 directory (where there is no Ranger policy allowing that operation).

     alluxio fs ls /sensitive_data2/dataset1/
     Permission denied by authorization plugin: alluxio.exception.AccessControlException: Permission denied: user=user1, access=--x, path=/sensitive_data2/dataset1: failed at /, inode owner=root, inode group=root, inode mode=rwx------

Since there was no explicit Ranger policy permitting access to the /sensitive_data2 directory, Alluxio fell back on its internal POSIX style permissions. Since the /sensitive_data2 directory only had rwx------ access permissions defined on it and was owned by the root user, Alluxio would not allow user1 to access that directory. 

#### e. Verify write access on user's home directory

Continuing as user1, try to create a new file in the home directory for user1.

     alluxio fs copyFromLocal /etc/motd /user/user1/
     Copied file:///etc/motd to /user/user1

     alluxio fs ls /user/user1/
     -rw------- user1 alluxio-users 283 PERSISTED 02-01-2022 15:55:15:912 100% /user/user1/motd

Alluxio allows the file to be created because, even though there isn't a Ranger policy allowing the alluxio-users group to access the /user directory, Alluxio fell back on its POSIX style permissions allowed the write operation because the /user/user1 sub-directory is owned by the /user1 user.

Try the copyFromLocal command on the /user/user2 directory and it will fail because that directory is owned by the user2 user.

     alluxio fs copyFromLocal /etc/motd /user/user2/
     Permission denied by authorization plugin: alluxio.exception.AccessControlException: Permission denied: user=user1, access=r--, path=/user/user2: failed at user2, inode owner=user2, inode group=alluxio-users, inode mode=rwx------

#### f. Check the Ranger audit log

Back on the Ranger Admin Web UI, click on the "Audit" link at the top of the page. Then click on the "Access" tab and you will see an event documenting the policy enforcement.

#### g. Check the Alluxio master logs

To verify that Alluxio is reading the access policies from Apache Ranger, you can view the log file for the Alluxio master container like this:

     docker logs -f alluxio-master

You will see audit entries like this:

2022-02-01 15:56:18,452 INFO  xaaudit - {"repoType":1,"repo":"alluxio-datacenter1-test","reqUser":"user1","evtTime":"2022-02-01 15:56:17.142","access":"READ","resource":"/user/user1","resType":"path","action":"read","result":1,"agent":"hdfs","policy":-1,"reason":"/user/user1","enforcer":"hadoop-acl","agentHost":"alluxio-master","logType":"RangerAudit","id":"0ca65ae8-94ac-4bb7-80e8-3ab6d4746218-0","seq_num":1,"event_count":1,"event_dur_ms":0,"tags":[],"additional_info":", \"accessTypes\":[read]","cluster_name":""}
2022-02-01 15:56:18,452 INFO  xaaudit - {"repoType":1,"repo":"alluxio-datacenter1-test","reqUser":"user1","evtTime":"2022-02-01 15:56:17.145","access":"EXECUTE","resource":"/user/user1","resType":"path","action":"execute","result":1,"agent":"hdfs","policy":-1,"reason":"/user/user1","enforcer":"hadoop-acl","agentHost":"alluxio-master","logType":"RangerAudit","id":"02e99202-1a7f-4794-b762-252c8bc28069-0","seq_num":1,"event_count":1,"event_dur_ms":0,"tags":[],"additional_info":", \"accessTypes\":[execute]","cluster_name":""}


---

Please direct questions and comments to greg.palmer@alluxio.com

NOTE: The Apache Ranger containers are based on work done by kadensungbinchoa:

See https://medium.com/swlh/hands-on-apache-ranger-docker-poc-with-hadoop-hdfs-hive-presto-814344a03a17

