
# Hadoop automation using ansible

## I am currently using two ansible scripts for this
* bootstrap.yml (Change root password, add user and serverless authentication)
* hadoop_install.yml (Install and configure hadoop)

* Certain prerequisites before running hadoop_install.yml file
** Keep your configuration files in a folder called files or change accordingly
** I am using a shell script to configure hadoop properties - hadoop_multi_node.sh, hadoop_install.conf
*** hadoop_install.conf contains the ip address of the master and slaves used for configuring the /etc/hosts file

==== Run hdfs format command, disable firewall and start daemons====

*After successful completion of the above scripts, run the following command in the master node
  hdfs namenode -format

*Run the following command to disable firewall in all nodes so that nodes can interact with each other as a root user
  sudo ufw disable

*Start all the daemons by running the following command
  ./hadoop/sbin/start-all.sh

*You should see the datanodes information by accessing the url [[http:master_ip:50070]] (sample [[http:master.dyn.mwn.de:50070]])
*You should see the hadoop application web interface by accessing the url [[http:master_ip:8088]] (sample [[http:master.dyn.mwn.de:8088]])
