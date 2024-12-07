# ansible-practices-tutorial

Short tutorial to display good ansible practices based on [Good Practices for Ansible - GPA](https://redhat-cop.github.io/automation-good-practices/)  

## Inventory

Inventories are 

```bash
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
        host5:
EOF
```
Create the group_vars directory structure:

```bash
for i in $(seq 1 4); do mkdir -p group_vars/group$i;done
for i in $(seq 1 4); do echo -e "---\ng: $i" >  group_vars/group$i/all.yml;done
mkdir group_vars/all && echo -e "---\ng: all" >  group_vars/all/all.yml
```

Create the host_vars directory structure:

```bash
for i in $(seq 1 6); do mkdir -p host_vars/host$i;done
for i in $(seq 1 6); do echo -e "---\nh: $i" >  host_vars/host$i/all.yml;done
```

One can use the ansible-inventory command to examinate the inventory and variable structure.

```bash
ansible-inventory -i groups_and_hosts --list
```

If we run the above ansible-inventory command, we'll see "all" and "ungrouped" behaving a little special. The "all" and "ungrouped" groups are default groups. Every host will always belong to at least 2 groups (all and ungrouped or all and some other group).  

In general ansible-inventory can be very handy tool, to check the structure and understanding what variable ansible is going to use.  
In addition to the "--list" parameter the "--host" and "--graph --vars" are also very helpful. The -l (--limit) option is also useful to get only a subset of groups.

The "--host" parameter displays the hostvars of the respective host, if you want to see only all hostvars across an entire group you can use jq to process the output.  

Here are some example commands:

```bash
ansible-inventory -i groups_and_hosts --list | jq ._meta.hostvars
ansible-inventory -i groups_and_hosts --list -l ungrouped | jq ._meta.hostvars
ansible-inventory -i groups_and_hosts --list -l group1 | jq ._meta.hostvars
ansible-inventory -i groups_and_hosts --host host1
ansible-inventory -i groups_and_hosts --host host6
ansible-inventory -i groups_and_hosts --graph
ansible-inventory -i groups_and_hosts --graph --vars
```

Hosts in multiple groups:

Having a host in multiple groups can be often very useful if creating a inventory structure.
Lets add "host5" which belongs in our example inventory to "group3" to "group4":

```bash
echo -n "        host5:" >> groups_and_hosts
```

If we now run:  

```bash
ansible-inventory -i groups_and_hosts --list -l group4 | jq ._meta.hostvars
```

The group variable "g" differs for each host, allthough we are in the same group. This is because we have defined the same group varialbe before. Variables that occur higher in an inventory can override variables that occur lower in the inventory. The default group variables all and ungrouped though are not effected by this behaviour.  

We can even see the behaviour better if running:

```bash
ansible-inventory -i groups_and_hosts --graph --vars
```

```
  |--@group4:
  |  |--host6
  |  |  |--{g = 4}
  |  |  |--{h = 6}
  |  |--host5
  |  |  |--{g = 3}
  |  |  |--{h = 5}
  |  |--{g = 4}
  |--{g = all}
```

To ensure the ansible-inventory command is acting like the ansible-playbook, we can also create a playbook:

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

Running the playbook:

```bash
ansible-playbook -i groups_and_hosts testing_variables.yml  -l group4
```