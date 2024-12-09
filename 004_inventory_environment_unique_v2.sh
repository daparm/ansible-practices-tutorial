#! /bin/bash

environments=("dev" "test" "prod")
groups=("web" "database" "app")
hosts=("web1" "web2" "database1" "database2" "app1" "app2")
domain="example.com"
subnet_third_octet="0"
subnet_fourth_octet="0"
subnet_first_and_second_octet="10.0"

for m in ${environments[@]};
do
    fqdns=("${hosts[@]/%/-${m}.${domain}}")
    groups_with_events=("${groups[@]/%/_${m}}")
    for g in ${groups_with_events[@]}; do mkdir -p inventory/${m}/group_vars/${g}; done
    mkdir -p inventory/${m}/group_vars/all
    for g in ${groups_with_events[@]}; do echo "env: \"${m}\"" >  inventory/${m}/group_vars/${g}/provision.yml; done
    for f in ${fqdns[@]}; do mkdir -p inventory/${m}/host_vars/${f}; done
    l=${m};subnet_third_octet=$(expr $subnet_third_octet + 1);subnet_fourth_octet=0;for i in ${fqdns[@]}; do echo -e "---\nip: ${subnet_first_and_second_octet}.${subnet_third_octet}.${subnet_fourth_octet}" > inventory/${l}/host_vars/${i}/network.yml; subnet_fourth_octet=$(expr $subnet_fourth_octet + 1);done
done

for m in ${environments[@]}; do cat <<EOF> inventory/$m/groups_and_hosts
---
all:
  children:
    $m:
      children:
        web_$m:
          hosts:
            web1-$m.example.com:
            web2-$m.example.com:
        database_$m:
          hosts:
            database1-$m.example.com:
            database2-$m.example.com:
        app_$m:
          hosts:
            app1-$m.example.com:
            app2-$m.example.com:
EOF
done

echo -e "---\ncross_env_variable: \"variable_across_all_variables\"" > inventory/000_cross_env_vars.yml
echo -e "provision_vm_name: \"{{ inventory_hostname }}\"" >> inventory/000_cross_env_vars.yml
ln -s $(pwd)/inventory/000_cross_env_vars.yml $(pwd)/inventory/dev/group_vars/all
ln -s $(pwd)/inventory/000_cross_env_vars.yml $(pwd)/inventory/test/group_vars/all
ln -s $(pwd)/inventory/000_cross_env_vars.yml $(pwd)/inventory/prod/group_vars/all

ansible-inventory -i inventory/prod/groups_and_hosts -i inventory/test/groups_and_hosts -i inventory/dev/groups_and_hosts --list | jq ._meta.hostvars

ansible-inventory -i inventory/dev/groups_and_hosts -i inventory/test/groups_and_hosts -i inventory/prod/groups_and_hosts --list | jq ._meta.hostvars

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
          - "{{ inventory_hostname is search('dev') }}"
          - "{{ inventory_hostname is search('test') }}"
          - "{{ inventory_hostname is search('prod') }}"

    - name: Display entire hostvars
      ansible.builtin.debug:
        var: hostvars[inventory_hostname]


    - name: ping
      ansible.builtin.ping:

EOF

ansible-playbook -i inventory/dev/groups_and_hosts -i inventory/test/groups_and_hosts -i inventory/prod/groups_and_hosts testing_variables.yml

tree inventory