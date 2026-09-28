<!-- nav:start -->
[Course home](../README.md) › [Chapter 08: Automating Linux Administration](README.md) › Lab solution (10 of 10)
<!-- nav:end -->

# Chapter 08 Lab Solution: `system_review`

One playbook per requirement keeps each run short and each failure easy to locate. A `site.yml` that imports them all is added at the end.

---

## Discovery

```bash
cd ~/system_review
ansible-navigator run disk_list.yml      # the 5 GiB disk without partitions, here sdb
ansible-navigator run nic_facts.yml      # primary address 192.168.250.11
```

## 1. Software: `software.yml`

```yaml
---
- name: Lab repository and agent
  hosts: app
  become: true
  vars:
    repo_url: http://materials.example.com/yum/labrepo
  tasks:
    - name: Repository signing key is trusted
      ansible.builtin.rpm_key:
        key: "{{ repo_url }}/RPM-GPG-KEY-labexample"
        state: present

    - name: Lab repository is configured
      ansible.builtin.yum_repository:
        name: lab-internal
        description: Lab Example internal packages
        file: lab_internal
        baseurl: "{{ repo_url }}/"
        gpgcheck: true
        gpgkey: "{{ repo_url }}/RPM-GPG-KEY-labexample"
        enabled: true

    - name: Agent is installed
      ansible.builtin.dnf:
        name: lab-agent
        state: present

    - name: Agent timer runs and starts at boot
      ansible.builtin.systemd_service:
        name: lab-agent.timer
        state: started
        enabled: true
```

## 2. Users: `users.yml`

```yaml
---
- name: Operators
  hosts: app
  become: true
  vars:
    operators:
      - name: ops1
        uid: 3001
      - name: ops2
        uid: 3002
  tasks:
    - name: Group ops exists with a fixed GID
      ansible.builtin.group:
        name: ops
        gid: 3000
        state: present

    - name: Operators exist in group ops
      ansible.builtin.user:
        name: "{{ item['name'] }}"
        uid: "{{ item['uid'] }}"
        groups: ops
        append: true
        state: present
      loop: "{{ operators }}"

    - name: Operators accept their SSH keys
      ansible.posix.authorized_key:
        user: "{{ item['name'] }}"
        key: "{{ lookup('ansible.builtin.file', 'files/keys/' ~ item['name'] ~ '.pub') }}"
        state: present
      loop: "{{ operators }}"

    - name: Members of ops use sudo without a password
      ansible.builtin.lineinfile:
        path: /etc/sudoers.d/ops
        line: "%ops ALL=(ALL) NOPASSWD: ALL"
        create: true
        owner: root
        group: root
        mode: "0440"
        validate: /usr/sbin/visudo -cf %s
```

## 3. Storage: `group_vars/app/storage.yml` and `storage.yml`

```yaml
---
# redhat.rhel_system_roles.storage; disk name from disk_list.yml
storage_pools:
  - name: app_vg
    type: lvm
    disks:
      - sdb
    volumes:
      - name: app_data
        size: 256m
        fs_type: xfs
        mount_point: /srv/app
        state: present
      - name: app_logs
        size: 128m
        fs_type: xfs
        mount_point: /var/log/app
        state: present
      - name: app_swap
        size: 64m
        fs_type: swap
        state: present
```

```yaml
---
- name: Application storage
  hosts: app
  become: true
  tasks:
    - name: Volume group, volumes, mounts, and swap
      ansible.builtin.include_role:
        name: redhat.rhel_system_roles.storage
```

## 4. Scheduling: `cron.yml`

```yaml
---
- name: Disk report job
  hosts: app
  become: true
  tasks:
    - name: Disk report runs every 15 minutes in working hours
      ansible.builtin.cron:
        name: Disk usage report
        cron_file: disk_report
        user: devops
        minute: "*/15"
        hour: "8-17"
        weekday: "1-5"
        job: df -h /srv/app >> /home/devops/disk_report.log
```

Hours 8-17 cover 08:00 through 17:59: the last run is at 17:45.

## 5. Network: `group_vars/app/network.yml` and `network.yml`

```yaml
---
# redhat.rhel_system_roles.network
network_provider: nm
network_connections:
  - name: labbr0
    type: bridge
    state: up
    autoconnect: true
    ip:
      dhcp4: false
      auto6: false
      address:
        - "192.168.251.{{ ansible_facts['default_ipv4']['address'].split('.')[-1] }}/24"
```

```yaml
---
- name: Lab bridge
  hosts: app
  become: true
  tasks:
    - name: Bridge connection is configured
      ansible.builtin.include_role:
        name: redhat.rhel_system_roles.network
```

## 6. Everything together: `site.yml`

```yaml
---
- name: Software
  ansible.builtin.import_playbook: software.yml

- name: Users
  ansible.builtin.import_playbook: users.yml

- name: Storage
  ansible.builtin.import_playbook: storage.yml

- name: Scheduling
  ansible.builtin.import_playbook: cron.yml

- name: Network
  ansible.builtin.import_playbook: network.yml
```

```bash
ansible-navigator run site.yml
ansible-navigator run site.yml      # changed=0
ssh -i files/keys/ops1 ops1@serverb.lab.example.com sudo -n id -un
ansible app -b -m ansible.builtin.shell -a 'lvs app_vg; findmnt /srv/app; findmnt /var/log/app; swapon --show; cat /etc/cron.d/disk_report; ip -4 addr show labbr0'
lab grade system_review
lab finish system_review
```

| Decision | Reason |
|---|---|
| Key imported with `rpm_key` and `gpgkey` set | The package verifies on the first install and on later updates |
| Timer rather than a cron job for the agent | The package ships a timer; use what the vendor provides |
| `append: true` | Keeps each user's other groups |
| Disk named from discovery, not guessed | The spare disk name depends on the hypervisor |
| Address derived from facts | One variable file serves every host in the group |
| One playbook per area plus `site.yml` | Fast reruns while working; one command for the whole host |

## Time Check

Target: 45 minutes. Software 7, users 8, storage 10, cron 5, network 8, verification 7.

<!-- navfoot:start -->

---

← Previous: [Chapter 08 Lab: Build an Application Host](08_lab.md) | You have reached the last published page. [Back to the course home](../README.md)

<!-- navfoot:end -->
