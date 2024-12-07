#! /bin/bash

cat <<EOF> groups_and_hosts
---
all:
  hosts:
    host1:
    host2:
  children:
    group1:
      children:
        group2:
          hosts:
            host3:
            host4:
        group3:
          hosts:
            host5:
    group4:
      hosts:
        host6:
EOF

for i in $(seq 1 4); do mkdir -p group_vars/group$i;done
for i in $(seq 1 4); do echo -e "---\ng: $i" >  group_vars/group$i/all.yml;done
mkdir group_vars/all && echo -e "---\ng: all" >  group_vars/all/all.yml

for i in $(seq 1 6); do mkdir -p host_vars/host$i;done
for i in $(seq 1 6); do echo -e "---\nh: $i" >  host_vars/host$i/all.yml;done

ansible-inventory -i groups_and_hosts --graph --vars

echo -n "        host5:" >> groups_and_hosts

cat <<EOF> testing_variables.yml
---
- name: Testing variables
  hosts: all
  connection: local
  gather_facts: false

  tasks:
    - name: Display variables
      ansible.builtin.debug:
        msg: 
          - "Host variable: {{ h }}"
          - "Group variable: {{ g }}"
EOF

ansible-playbook -i groups_and_hosts testing_variables.yml  -l group4

echo -e "---" >  group_vars/group1/all.yml
echo -e "---" >  group_vars/group3/all.yml
echo -e "---" >  group_vars/group4/all.yml

ansible-playbook -i groups_and_hosts testing_variables.yml  -l group4

tree .
