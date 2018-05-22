
# Hadoop automation using ansible

## I am currently using two ansible scripts for this
* bootstrap.yml (Change root password, add user and serverless authentication)
* hadoop_install.yml (Install and configure hadoop)

# Step 1
* Clone the repository to your local folder

# Step 2
* Change the hosts file based on server to which u want to push the changes
* Change the hadoop_install.conf file inside files with master and slave Ips

# Step 3 (Run ansible scripts)
* $ ansible-playbook -i hosts playbooks/bootstrap.yml  --user root
* $ ansible-playbook -i hosts playbooks/hadoop_install.yml  --user root

# Step 4 (Run hdfs format command, disable firewall and start daemons)
* After successful completion of the above scripts, run the following command in the master node
  $ hdfs namenode -format

* Run the following command to disable firewall in all nodes so that nodes can interact with each other as a root user
  $ sudo ufw disable

* Start all the daemons by running the following command
  $ ./hadoop/sbin/start-all.sh

# Step 5 (Dashboard access)
* You should see the datanodes information by accessing the url http:master_ip:50070
* You should see the hadoop application web interface by accessing the url http:master_ip:8088
