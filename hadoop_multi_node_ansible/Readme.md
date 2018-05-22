
===Hadoop automation using ansible===

*Finally succeeded in automating the setup of hadoop multinode cluster. I am currently using two ansible scripts for this
**bootstrap.yml
**hadoop_install.yml

====bootstrap.yml (Change root password, add user and serverless authentication)====

<source lang=bash>
---
- hosts: all
  gather_facts: False

  vars:
    - root_password: 'HASHED_KEY_PASSWORD'
 
  tasks:
  - name: install python 2
    raw: test -e /usr/bin/python || (apt -y update && apt install -y python-minimal)

  - name: Change root password
    user:
      name=root
      password={{ root_password }}

  - name: Transfer the script
    copy: src=~/.ssh/id_rsa dest=/root/.ssh/id_rsa mode=0400
 
  - name: Add user hadoop
    user:
      name=hadoop
      shell=/bin/bash
 
  - name: Add SSH public key to user hadoop
    authorized_key:
      user=hadoop
      key="{{ lookup('file', "../files/workstation.pub") }}"

  - name: Transfer the script
    copy: src=~/.ssh/id_rsa dest=/home/hadoop/.ssh/id_rsa mode=0400 owner=hadoop group=hadoop
 
  handlers:
  - name: restart sshd
    service: 
      name=sshd
      state=restarted
</source>

====hadoop_install.yml (Install and Configure Hadoop)====

<source lang=bash>
---
- name: Extract Hadoop
  hosts: all
  tasks:
      - unarchive:
          src: http://archive.apache.org/dist/hadoop/core/hadoop-2.6.0/hadoop-2.6.0.tar.gz
          dest: /home/hadoop/
          remote_src: yes
          creates: /home/hadoop/hadoop

      - command: mv /home/hadoop/hadoop-2.6.0 /home/hadoop/hadoop creates=/home/hadoop/hadoop removes=/home/hadoop/hadoop-2.6.0

      - lineinfile: path=/home/hadoop/.bashrc regexp="HADOOP_PREFIX=" line="export HADOOP_PREFIX=/home/hadoop/hadoop"
      - lineinfile: path=/home/hadoop/.bashrc regexp="PATH=" line="export PATH=$PATH:$HADOOP_PREFIX/bin"

- name: Update the xml files
  hosts: all
  tasks:
      - template: src={{ item.src }} dest={{ item.dest }} owner="hadoop" group="hadoop"
        with_items:
         - {src: "../files/core-site.xml", dest: "/home/hadoop/hadoop/etc/hadoop/core-site.xml"}
         - {src: "../files/hdfs-site.xml", dest: "/home/hadoop/hadoop/etc/hadoop/hdfs-site.xml"}
         - {src: "../files/yarn-site.xml", dest: "/home/hadoop/hadoop/etc/hadoop/yarn-site.xml"}
         - {src: "../files/mapred-site.xml", dest: "/home/hadoop/hadoop/etc/hadoop/mapred-site.xml"}


- hosts: all
  gather_facts: True
  vars:
    - username: hadoop

  tasks:
  - name: Transfer the script
    copy: src=../files/hadoop_multi_node.sh dest=/root mode=0777

  - name: Transfer the configuration file
    copy: src=../files/hadoop_install.conf dest=/root mode=0777

  - name: Execute the script
    shell: yes | /root/hadoop_multi_node.sh
    register: output
</source>


*Certain prerequisites before running hadoop_install.yml file
**Keep your configuration files in a folder called files or change accordingly
**I am using a shell script to configure hadoop properties - hadoop_multi_node.sh, hadoop_install.conf
***hadoop_install.conf contains the ip address of the master and slaves used for configuring the /etc/hosts file

==== Run hdfs format command, disable firewall and start daemons====

*After successful completion of the above scripts, run the following command in the master node
  hdfs namenode -format

*Run the following command to disable firewall in all nodes so that nodes can interact with each other as a root user
  sudo ufw disable

*Start all the daemons by running the following command
  ./hadoop/sbin/start-all.sh

*You should see the datanodes information by accessing the url [[http:master_ip:50070]] (sample [[http:master.dyn.mwn.de:50070]])
*You should see the hadoop application web interface by accessing the url [[http:master_ip:8088]] (sample [[http:master.dyn.mwn.de:8088]])
