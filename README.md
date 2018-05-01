# Hadoop single node cluster Install procedure in a remote VM
Install Hadoop 2.6.0 in Ubuntu remote VM

# Step 1
- Update the /etc/hosts file in root user of your Ubuntu instance to include the remote VM instance IP
  For e.g. -> 10.XXX.XXX.XXX  master
  
- Run the command<br> 
  $ service sshd restart

# Step 2
- Run the shell script to install hadoop 2.6.0 in single cluster mode<br>
  $ chmod +x hadoop_singl_node_install.sh<br>
  $ ./hadoop_singl_node_install.sh<br>
  
# Step 3
- Format the namenode<br>
  $ hdfs namenode -format
  
# Step 4
- Go to the sbin folder and execute<br>
  $ ./start-all.sh
  
# Step 5
- Run jps to see the daemons running. There should be 6 daemons in total<br>
  $ jps
