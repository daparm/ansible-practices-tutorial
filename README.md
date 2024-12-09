# ansible-practices-tutorial

Short tutorial to display good ansible practices based on [Good Practices for Ansible - GPA](https://redhat-cop.github.io/automation-good-practices/)  

## Inventory

Inventories are a list of hosts you want to administer.

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

```bash
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
```

Running the playbook:

```bash
ansible-playbook -i groups_and_hosts testing_variables.yml  -l group4
```

If we now would have a more pleasant result, we could remove the group variable from the groups 4,3 and 1 (because 3 is a group child of group 1):

```bash
echo -e "---" >  group_vars/group1/all.yml
echo -e "---" >  group_vars/group3/all.yml
echo -e "---" >  group_vars/group4/all.yml
```

And only rely on the group_vars/all/all.yml variable.

```bash
ansible-playbook -i groups_and_hosts testing_variables.yml  -l group4
```


So as we can see, it can become quite complex, so as a good practice, try to avoid to assign hosts to multiple groups, if this is not working out for you, try to use the all variable and omit the specific variable in the affected groups.  
  
As a thumb rule: Ansible always flattens variables, including inventory variables, to the host level, so if you run into issues regarding working with group_vars, you can always use the host_vars to ensure functionality.

Cleanup:

```bash
rm -rv !("README.md"|*.sh)
```

## Multiple Environments

We learned so far how to setup a structured inventory for a single environment. But usually, we will work in projects having more then one environments.  

In both cases, it is recommended to have a dedicated inventory folder in your project for that purpose.  
Let's assume we want to manage a basic three tier application consisting of web server, database server and application server. We want to deploy this stack in three different environments: dev, test and prod.  

With this information, we can create a basic multi environment structure:  

```bash
environments=("dev" "test" "prod")
groups=("web" "database" "apps" "all")
hosts=("web1" "web2" "database1" "database2" "app1" "app2")
domain="example.com"
fqdns=("${hosts[@]/%/.${domain}}")
subnet_third_octet="0"
subnet_fourth_octet="0"
subnet_first_and_second_octet="10.0"
for m in ${environments[@]};
do
    for g in ${groups[@]}; do mkdir -p inventory/${m}/group_vars/${g}; done
    echo -e "---\nprovision_vm_name: \"{{ inventory_hostname }}\"" >  inventory/${m}/group_vars/all/all.yml
    echo "env: \"${m}\"" >>  inventory/${m}/group_vars/all/all.yml
    for f in ${fqdns[@]}; do mkdir -p inventory/${m}/host_vars/${f}; done
    l=${m};subnet_third_octet=$(expr $subnet_third_octet + 1);subnet_fourth_octet=0;for i in ${fqdns[@]}; do echo -e "---\nip: ${subnet_first_and_second_octet}.${subnet_third_octet}.${subnet_fourth_octet}" > inventory/${l}/host_vars/${i}/network.yml; subnet_fourth_octet=$(expr $subnet_fourth_octet + 1);done
done

for m in ${environments[@]}; do cat <<EOF> inventory/$m/groups_and_hosts
---
all:
  children:
    $m:
      children:
        web:
          hosts:
            web1.example.com:
            web2.example.com:
        database:
          hosts:
            database1.example.com:
            database2.example.com:
        app:
          hosts:
            app1.example.com:
            app2.example.com:
EOF
done
```

Now we have a seperated environment structure. Great. Time to test it:

```bash
ansible-inventory -i inventory/dev/groups_and_hosts --list | jq ._meta.hostvars
```
or
```bash
ansible-inventory -i inventory/test/groups_and_hosts --list | jq ._meta.hostvars
```

As we can see here, the seperation does work great for single references.

But what happens if we want to be clever and try to combine all seperated inventory into one with multiply "-i" calls? 

```bash
ansible-inventory -i inventory/dev/groups_and_hosts -i inventory/test/groups_and_hosts -i inventory/prod/groups_and_hosts --list | jq ._meta.hostvars
```

We will find out that the variable merging do kinda misbehave. On two levels, the flattened variables collidate with the host_vars reference, so a better praxis would be to ensure that we only have unique hostnames. And we will encounter that the last overlapping group_vars are overwritten by the last called inventory. Swap the prod and dev inventory to point ot the behavior and make it clear:

```bash
ansible-inventory -i inventory/prod/groups_and_hosts -i inventory/test/groups_and_hosts -i inventory/dev/groups_and_hosts --list | jq ._meta.hostvars
```

### Unique Hostnames

Let's get rid of the multi environment inventory structure with overlapping hostnames and recreate them with unqiue hostnames.  


Cleanup:

```bash
rm -rv !("README.md"|*.sh)
```



```bash
environments=("dev" "test" "prod")
groups=("web" "database" "apps" "all")
hosts=("web1" "web2" "database1" "database2" "app1" "app2")
domain="example.com"
subnet_third_octet="0"
subnet_fourth_octet="0"
subnet_first_and_second_octet="10.0"

for m in ${environments[@]};
do
    fqdns=("${hosts[@]/%/-${m}.${domain}}")
    for g in ${groups[@]}; do mkdir -p inventory/${m}/group_vars/${g}; done
    echo -e "---\nprovision_vm_name: \"{{ inventory_hostname }}\"" >  inventory/${m}/group_vars/all/all.yml
    echo "env: \"${m}\"" >>  inventory/${m}/group_vars/all/all.yml
    for f in ${fqdns[@]}; do mkdir -p inventory/${m}/host_vars/${f}; done
    l=${m};subnet_third_octet=$(expr $subnet_third_octet + 1);subnet_fourth_octet=0;for i in ${fqdns[@]}; do echo -e "---\nip: ${subnet_first_and_second_octet}.${subnet_third_octet}.${subnet_fourth_octet}" > inventory/${l}/host_vars/${i}/network.yml; subnet_fourth_octet=$(expr $subnet_fourth_octet + 1);done
done

for m in ${environments[@]}; do cat <<EOF> inventory/$m/groups_and_hosts
---
all:
  children:
    $m:
      children:
        web:
          hosts:
            web1-$m.example.com:
            web2-$m.example.com:
        database:
          hosts:
            database1-$m.example.com:
            database2-$m.example.com:
        app:
          hosts:
            app1-$m.example.com:
            app2-$m.example.com:
EOF
done
```


If we rerun the tests, we can see that it works far better referencing multiple inventory files. The group_vars are still an issue, we can not do much against it other then changing the order of the inventories and ensure we select the dominant one on the end. And we can implement a cross environments file via a symlink:  

```bash
echo -e "---\ncross_env_variable: \"variable_across_all_variables\"" > inventory/000_cross_env_vars.yml
ln -s $(pwd)/inventory/000_cross_env_vars.yml $(pwd)/inventory/dev/group_vars/all
ln -s $(pwd)/inventory/000_cross_env_vars.yml $(pwd)/inventory/test/group_vars/all
ln -s $(pwd)/inventory/000_cross_env_vars.yml $(pwd)/inventory/prod/group_vars/all
```


```bash
ansible-inventory -i inventory/prod/groups_and_hosts -i inventory/test/groups_and_hosts -i inventory/dev/groups_and_hosts --list | jq ._meta.hostvars
```
And with prod as the dominating group var:  
```bash
ansible-inventory -i inventory/dev/groups_and_hosts -i inventory/test/groups_and_hosts -i inventory/prod/groups_and_hosts --list | jq ._meta.hostvars
```

As we can see, the first three iterations of creating an proper inventory could not solve the collapsing of either hosts or groups.  

So to ultimately ensure we can not only work with isolated environments as seen in "003_inventory_environment_unique.sh" but can also chain inventories one after another, we also need to establish unique nested groups, or we will run into the issue, that Ansible cannot distinguish between the child groups "app", "database" "web" and parent groups "dev", "test" and "prod" properly.  

If we take a look on our host and group variable, we now have a unique set, which works in most scenarios. But we have to sacrifice the usage of the "all" group variable assignment, in favour of not running into overriding the variable in favour of the last used inventory file. To be able to still assign global variables across all environments, we can use the "000_cross_env_vars.yml" reference.

Running this command will show it:

```bash
ansible-inventory -i inventory/dev/groups_and_hosts -i inventory/test/groups_and_hosts -i inventory/prod/groups_and_hosts --graph --vars
```

This structure will be displayed:

```bash
@all:
  |--@ungrouped:
  |--@dev:
  |  |--@web_dev:
  |  |  |--web1-dev.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = dev}
  |  |  |  |--{ip = 10.0.1.0}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--web2-dev.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = dev}
  |  |  |  |--{ip = 10.0.1.1}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--{env = dev}
  |  |--@database_dev:
  |  |  |--database1-dev.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = dev}
  |  |  |  |--{ip = 10.0.1.2}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--database2-dev.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = dev}
  |  |  |  |--{ip = 10.0.1.3}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--{env = dev}
  |  |--@app_dev:
  |  |  |--app1-dev.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = dev}
  |  |  |  |--{ip = 10.0.1.4}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--app2-dev.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = dev}
  |  |  |  |--{ip = 10.0.1.5}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--{env = dev}
  |--@test:
  |  |--@web_test:
  |  |  |--web1-test.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = test}
  |  |  |  |--{ip = 10.0.2.0}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--web2-test.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = test}
  |  |  |  |--{ip = 10.0.2.1}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--{env = test}
  |  |--@database_test:
  |  |  |--database1-test.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = test}
  |  |  |  |--{ip = 10.0.2.2}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--database2-test.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = test}
  |  |  |  |--{ip = 10.0.2.3}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--{env = test}
  |  |--@app_test:
  |  |  |--app1-test.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = test}
  |  |  |  |--{ip = 10.0.2.4}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--app2-test.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = test}
  |  |  |  |--{ip = 10.0.2.5}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--{env = test}
  |--@prod:
  |  |--@web_prod:
  |  |  |--web1-prod.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = prod}
  |  |  |  |--{ip = 10.0.3.0}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--web2-prod.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = prod}
  |  |  |  |--{ip = 10.0.3.1}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--{env = prod}
  |  |--@database_prod:
  |  |  |--database1-prod.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = prod}
  |  |  |  |--{ip = 10.0.3.2}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--database2-prod.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = prod}
  |  |  |  |--{ip = 10.0.3.3}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--{env = prod}
  |  |--@app_prod:
  |  |  |--app1-prod.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = prod}
  |  |  |  |--{ip = 10.0.3.4}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--app2-prod.example.com
  |  |  |  |--{cross_env_variable = variable_across_all_variables}
  |  |  |  |--{env = prod}
  |  |  |  |--{ip = 10.0.3.5}
  |  |  |  |--{provision_vm_name = {{ inventory_hostname }}}
  |  |  |--{env = prod}
  |--{cross_env_variable = variable_across_all_variables}
  |--{provision_vm_name = {{ inventory_hostname }}}
```


## AAP

Working with AAP is again a little more interesting, since we can not use the cross environment vars nor the all variables. This means we have to be more creative with the variables.  