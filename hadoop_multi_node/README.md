# Hadoop multi node cluster Install procedure in a remote VM
Install Hadoop 2.6.0 in Ubuntu remote VM (1 master and n slave nodes) (.. In Development and Testing Stage)

# Step 1
- Update the hadoop_install.conf file with the IPs of the master and the slave nodes as shown below
  master:10.XXX.XXX.XXX
  slave:10.XX.XX.XX,10.XX.XX.XX,10.XX.XX.XX

# Step 2
- Run the shell script on each machine to install hadoop 2.6.0 (It will ask for whether it is master or slave)<br>
  $ chmod +x hadoop_multi_node_install.sh<br>
  $ ./hadoop_multi_node_install.sh<br>
  
# Step 3
- Set JAVA_HOME and passwordless authentication for master and slave nodes (In process of automating this)

# Step 4
- Format the namenode in master machine<br>
  $ hdfs namenode -format
  
# Step 5
- Go to the sbin folder in master machine and execute<br>
  $ ./start-all.sh
  
# Step 6
- Run jps to see the daemons running both in master and slave<br>
  $ jps

# Step 7
- Open a browser, type the following URL and press Enter<br>
  http://10.XXX.XXX.XXX:50070 <br>
- You should be able to see the hadoop namenode dashboard
