<!-- nav:start -->
[Course home](../README.md) › [Chapter 08: Automating Linux Administration](README.md) › Lesson (1 of 10)

**Pages in this chapter, in study order:**

1. Lesson: this page
2. Guided exercise: [Guided Exercise: Time Zones, Time Sync, and SELinux with System Roles](01_guided_exercise_system_roles.md)
3. Guided exercise: [Guided Exercise: Signed Repositories, Packages, and Package Facts](02_guided_exercise_system_software.md)
4. Guided exercise: [Guided Exercise: Accounts, Keys, sudo, and sshd](03_guided_exercise_system_users.md)
5. Guided exercise: [Guided Exercise: cron, at, Timers, Boot Target, and Reboots](04_guided_exercise_system_process.md)
6. Guided exercise: [Guided Exercise: LVM, File Systems, Swap, and Mounts](05_guided_exercise_system_storage.md)
7. Guided exercise: [Guided Exercise: Network Connections with the Network Role](06_guided_exercise_system_network.md)
8. Quiz: [Chapter 08 Quiz: Linux Administration with Ansible](07_quiz.md)
9. Graded lab: [Chapter 08 Lab: Build an Application Host](08_lab.md)
10. Lab solution: [Chapter 08 Lab Solution: `system_review`](09_lab_solution.md)
<!-- nav:end -->

# Chapter 08: Automating Linux Administration

| | |
|---|---|
| **Goal** | Automate the everyday RHEL administration tasks the exam is built around: software, users, scheduling, boot, storage, and networking, with modules and RHEL system roles |
| **Study time** | About 9 hours including exercises |
| **Activities** | [07_quiz.md](07_quiz.md), six guided exercises, [08_lab.md](08_lab.md) (graded) |
| **Lab prerequisite** | Chapter 07 complete; the spare 5 GB disk on every managed host is untouched (`lsblk`) |

---

## 0. Chapter Map

| Section | After it you can | Practice |
|---|---|---|
| 1. System Roles in Practice | Run timesync and selinux with group_vars, post tasks, handlers, and the reboot pattern | [01_guided_exercise_system_roles.md](01_guided_exercise_system_roles.md) |
| 2. Software and Subscriptions | Configure signed repositories, install packages and groups, read package facts, register systems | [02_guided_exercise_system_software.md](02_guided_exercise_system_software.md) |
| 3. Users and Authentication | Create groups and users with fixed IDs, passwords, SSH keys, sudo rules, sshd settings, and known hosts | [03_guided_exercise_system_users.md](03_guided_exercise_system_users.md) |
| 4. Scheduling and Boot | Manage cron, at, systemd services and timers, the default target, and reboots | [04_guided_exercise_system_process.md](04_guided_exercise_system_process.md) |
| 5. Storage | Create volume groups, logical volumes, file systems, mounts, and swap with the storage role; use mount and storage facts | [05_guided_exercise_system_storage.md](05_guided_exercise_system_storage.md) |
| 6. Networking | Configure connections with the network role and read network facts | [06_guided_exercise_system_network.md](06_guided_exercise_system_network.md) |
| Review | All of it on one host | [08_lab.md](08_lab.md) |

**EX294 objectives this chapter supports** (verify against the current list): automate standard RHCSA tasks using Ansible modules that work with software packages and repositories, services, firewall rules, file systems, storage devices, file content, archiving, task scheduling, security, users and groups; use RHEL system roles.

Throughout this chapter `ansible.cfg` has `become = false`, and plays that change the system set `become: true` themselves: you always see which plays need root.

---

## 1. System Roles in Practice

Chapter 7 introduced the RHEL system roles collection. This section shows the patterns that make them production ready.

### 1.1 Variables belong to groups

```
group_vars/
    all/timesync.yml              every host uses the lab time server
    na_datacenter/timezone.yml    host_timezone: America/Denver
    eu_datacenter/timezone.yml    host_timezone: Europe/Berlin
    web/selinux.yml               SELinux settings for web hosts
```

The playbook stays tiny, and a new data center is a new directory, not a code change.

### 1.2 Roles, then tasks, then handlers

```yaml
- name: Time synchronization and time zone
  hosts: web
  become: true
  roles:
    - redhat.rhel_system_roles.timesync
  post_tasks:
    - name: Current time zone is read
      ansible.builtin.command: timedatectl show -p Timezone --value
      register: current_timezone
      changed_when: false

    - name: Time zone is set
      ansible.builtin.command: timedatectl set-timezone {{ host_timezone }}
      when: current_timezone['stdout'] != host_timezone
      changed_when: true
      notify: Reboot host
  handlers:
    - name: Reboot host
      ansible.builtin.reboot:
```

Read then write, with `changed_when` on both: this is how you make a `command` task idempotent when no module fits.

### 1.3 The selinux role and reboots

Some SELinux changes (for example enabling SELinux from `disabled`) need a reboot. The role never reboots by itself: it sets `selinux_reboot_required: true` and **fails**. Handle it with block and rescue:

```yaml
- name: SELinux role is applied, with a reboot only if the role requires one
  block:
    - name: Apply the selinux role
      ansible.builtin.include_role:
        name: redhat.rhel_system_roles.selinux
  rescue:
    - name: Fail for any reason other than a pending reboot
      ansible.builtin.fail:
        msg: The selinux role failed for a reason other than a required reboot
      when: not (selinux_reboot_required | default(false))
    - name: Reboot to complete the SELinux change
      ansible.builtin.reboot:
    - name: Apply the selinux role again after the reboot
      ansible.builtin.include_role:
        name: redhat.rhel_system_roles.selinux
```

| Variable | Example | Replaces |
|---|---|---|
| `selinux_state`, `selinux_policy` | `enforcing`, `targeted` | `setenforce`, `/etc/selinux/config` |
| `selinux_booleans` | `{name: httpd_can_network_connect, state: true, persistent: true}` | `setsebool -P` |
| `selinux_fcontexts` | `{target: '/srv/www(/.*)?', setype: httpd_sys_content_t, state: present}` | `semanage fcontext -a` |
| `selinux_restore_dirs` | `[/srv/www]` | `restorecon -R` |
| `selinux_ports` | `{ports: "8088", proto: tcp, setype: http_port_t, state: present}` | `semanage port -a` |

### 1.4 Delivery options recap

| You have | Use |
|---|---|
| RHEL control node with `rhel-system-roles` RPM | `/usr/share/ansible/collections/...` (FQCN) or `/usr/share/ansible/roles/rhel-system-roles.*`; run with `ansible-playbook` or `ansible-navigator --ee false` |
| Red Hat supported execution environment | Collection is built in |
| Automation hub subscription | `collections/requirements.yml` with `name: redhat.rhel_system_roles` |
| An archive | `ansible-galaxy collection install -p collections redhat-rhel_system_roles-X.tar.gz` |

`fedora.linux_system_roles` on Galaxy is the upstream development version: same role names, no Red Hat support.

---

## 2. Software and Subscriptions

### 2.1 dnf

| Task | Module arguments |
|---|---|
| Install | `name: httpd`, `state: present` |
| Install several in one transaction | `name: [httpd, mod_ssl, httpd-tools]` |
| Install or update to the newest | `state: latest` |
| Update everything | `name: '*'`, `state: latest` |
| Remove, and orphans with it | `state: absent`, `autoremove: true` |
| Package group | `name: '@Development Tools'` (or its ID, `'@development'`) |
| Module stream (RHEL 9) | `name: '@nodejs:20/common'` |
| Specific version | `name: httpd-2.4.62-1.el10` |
| From one repository only | `enablerepo: lab-internal`, `disablerepo: '*'` |
| Download for later | `download_only: true` |
| Local or remote RPM file | `name: http://host/pkg.rpm` (`disable_gpg_check` only for trusted unsigned files) |

Never loop over `dnf`: pass the list. One transaction resolves dependencies once and is much faster.

RHEL 10 no longer ships module streams; alternative versions come as separately named packages or containers. `ansible.builtin.package` picks the platform's manager automatically but offers only the common options, and package names still differ between distributions.

### 2.2 Package facts

```yaml
- name: Package facts are gathered
  ansible.builtin.package_facts:

- name: Report the httpd version
  ansible.builtin.debug:
    msg: "{{ ansible_facts['packages']['httpd'][0]['version'] }}"
  when: "'httpd' in ansible_facts['packages']"
```

`ansible_facts['packages']` maps each name to a **list** (one entry per installed version or architecture). Facts are a snapshot: after installing something, run `package_facts` again before reading them.

### 2.3 Repositories and keys

```yaml
- name: Repository signing key is trusted
  ansible.builtin.rpm_key:
    key: http://materials.example.com/yum/labrepo/RPM-GPG-KEY-labexample
    state: present

- name: Lab repository is configured
  ansible.builtin.yum_repository:
    name: lab-internal                          # repository ID, the [section]
    description: Lab Example internal packages  # the name = line
    file: lab_internal                          # /etc/yum.repos.d/lab_internal.repo
    baseurl: http://materials.example.com/yum/labrepo/
    gpgcheck: true
    gpgkey: http://materials.example.com/yum/labrepo/RPM-GPG-KEY-labexample
    enabled: true
```

| Parameter | Trap |
|---|---|
| `name` | The ID used by `enablerepo`; `description` is required as well |
| `file` | Without it the file is named after `name`; `.repo` is appended automatically |
| `gpgcheck: true` | Needs the key: import with `rpm_key`, or give `gpgkey` so dnf imports it on first use |
| `state: absent` | Removes the section; the file disappears when empty |

`rpm_key` accepts `fingerprint:` to refuse a key that does not match: use it whenever the key comes over plain HTTP.

Repositories packaged as RPMs (EPEL's `epel-release`) are installed with `dnf`, not described with `yum_repository`.

### 2.4 Red Hat subscriptions

| Method | Use |
|---|---|
| `subscription-manager register`, then `repos --enable` | Manual |
| `redhat.rhel_system_roles.rhc` | Automated registration, repositories, Insights |
| `community.general.redhat_subscription` | Module based registration |

```yaml
rhc_state: present
rhc_auth:
  activation_keys:
    keys:
      - lab-rhel10
rhc_organization: "1234567"
rhc_repositories:
  - name: rhel-10-for-x86_64-appstream-rpms
    state: enabled
```

With Simple Content Access, registration is enough; no pool is attached. Prefer activation keys to user names and passwords, and keep either in a vault. The lab machines use local repositories, so this section is reference only.

---

## 3. Users and Authentication

### 3.1 Groups and users

```yaml
- name: Every group used by the accounts exists
  ansible.builtin.group:
    name: "{{ item }}"
    state: present
  loop: "{{ lab_users | map(attribute='groups') | flatten | unique }}"

- name: Accounts exist with fixed UIDs and supplementary groups
  ansible.builtin.user:
    name: "{{ item['name'] }}"
    uid: "{{ item['uid'] }}"
    groups: "{{ item['groups'] }}"
    append: true
    shell: /bin/bash
    password: "{{ lab_user_password | password_hash('sha512', 'labsalt2026') }}"
  loop: "{{ lab_users }}"
```

| `user` parameter | Meaning |
|---|---|
| `group` | Primary group (must exist) |
| `groups` + `append: true` | Add supplementary groups, keep others |
| `groups` without `append` | Supplementary groups become **exactly** this list |
| `uid`, `system: true` | Fixed ID; system accounts get IDs below 1000 (only at creation) |
| `password` | A **hash**, never plain text |
| `update_password: on_create` | Set the password only for new accounts |
| `password_expire_max`, `expires` | Aging and expiry |
| `state: absent`, `remove: true` | Delete the account and its home |
| `generate_ssh_key: true`, `ssh_key_type: ed25519` | Create `~/.ssh/id_ed25519`; return `ssh_public_key` |

**Password hashes and idempotency:** `password_hash('sha512')` picks a random salt, so every run produces a new hash and reports `changed`. Pass a fixed salt (second argument) or use `update_password: on_create`. Put the password itself in a vault file.

`group` creates groups; `gid:` fixes the ID, `system: true` gives a system group.

### 3.2 SSH keys, known hosts, sshd

```yaml
- name: Each account accepts its own SSH key
  ansible.posix.authorized_key:
    user: "{{ item['name'] }}"
    key: "{{ lookup('ansible.builtin.file', 'files/keys/' ~ item['name'] ~ '.pub') }}"
    state: present
  loop: "{{ lab_users }}"
```

`authorized_key` creates `~/.ssh` with the right permissions and SELinux label. `exclusive: true` removes every other key. `key` also accepts a URL (`https://git.example.com/alice.keys`).

`ansible.builtin.known_hosts` maintains `known_hosts` files; with `path: /etc/ssh/ssh_known_hosts` the entries apply to every user. The key line format is `name[,ip] type base64`.

sshd settings with `lineinfile`, always validated:

```yaml
- name: Root cannot log in over SSH
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#?PermitRootLogin\s'
    line: PermitRootLogin no
    validate: /usr/sbin/sshd -t -f %s
  notify: Restart sshd
```

sshd uses the **first** value it reads, and `sshd_config` includes `/etc/ssh/sshd_config.d/*.conf` at its top. A drop-in that sets the same keyword wins over the main file. Check the effective value with `sshd -T | grep -i permitrootlogin`.

### 3.3 sudo rules

```yaml
- name: Members of webadmin use sudo without a password
  ansible.builtin.lineinfile:
    path: /etc/sudoers.d/webadmin
    line: "%webadmin ALL=(ALL) NOPASSWD: ALL"
    create: true
    mode: "0440"
    validate: /usr/sbin/visudo -cf %s
```

`%` marks a group. `validate` checks the temporary file before it replaces the real one: a broken sudoers file can lock everyone out. Files in `/etc/sudoers.d/` whose names contain a dot or end in `~` are ignored.

---

## 4. Scheduling and Boot

### 4.1 cron

```yaml
- name: Personal crontab entry for devops
  ansible.builtin.cron:
    name: Record uptime              # stored as '#Ansible: Record uptime'; the identity of the job
    user: devops
    minute: "*/10"
    job: uptime >> /home/devops/uptime.log

- name: System job in /etc/cron.d
  ansible.builtin.cron:
    name: Record disk usage
    cron_file: lab_disk_usage        # relative: /etc/cron.d/lab_disk_usage
    user: devops                     # required with cron_file
    minute: "*/5"
    hour: "8-17"
    weekday: "1-5"
    job: df -h / >> /home/devops/disk_usage.log
```

| Field | Values | Default |
|---|---|---|
| `minute` | 0-59, `*/5`, `0,30` | `*` |
| `hour` | 0-23, `8-17` | `*` |
| `day` | 1-31 | `*` |
| `month` | 1-12 | `*` |
| `weekday` | 0-6 (0 = Sunday), `1-5` | `*` |
| `special_time` | `reboot`, `daily`, `hourly`, ... | not set |

`state: absent` with the same `name` (and `user`, and `cron_file` if used) removes the job; the cron file disappears when empty. Changing the `name` creates a **second** job. Never point `cron_file` at `/etc/crontab`. `ansible.builtin.cron` with `env: true` manages variables such as `MAILTO`.

### 4.2 at

```yaml
- name: Job runs once in two minutes
  ansible.posix.at:
    command: date > /tmp/lab_at_run
    count: 2
    units: minutes
    unique: true
```

Install the `at` package and start `atd` first. `unique: true` refuses to queue the same command twice. `state: absent` with the same command removes it.

### 4.3 systemd services and timers

| Goal | `ansible.builtin.systemd_service` arguments |
|---|---|
| Start now and at boot | `state: started`, `enabled: true` |
| Restart or reload | `state: restarted` / `reloaded` (in handlers) |
| New or changed unit files | `daemon_reload: true` |
| Prevent starting at all | `masked: true` |
| User units | `scope: user` |

A timer is a `.timer` unit that starts the `.service` of the same name:

```ini
[Timer]
OnCalendar=*:0/2        # every two minutes
Persistent=true         # catch up on runs missed while powered off
[Install]
WantedBy=timers.target
```

Deploy both files with `copy` or `template`, then start and enable the **timer** with `daemon_reload: true`. `systemctl list-timers` shows the next run. Timers log to the journal and can depend on other units, which is why many packages now ship timers instead of cron files; the `lab-agent` package in this chapter does exactly that.

### 4.4 Default target and reboot

```yaml
- name: Current default target is read
  ansible.builtin.command: systemctl get-default
  register: current_target
  changed_when: false

- name: Default target is set
  ansible.builtin.command: systemctl set-default graphical.target
  when: current_target['stdout'] != 'graphical.target'
  changed_when: true
```

Equivalent without commands: `ansible.builtin.file` with `src: /usr/lib/systemd/system/graphical.target`, `dest: /etc/systemd/system/default.target`, `state: link`, `force: true`.

```yaml
- name: Host reboots and comes back
  ansible.builtin.reboot:
    msg: Rebooting for lab maintenance
    reboot_timeout: 600               # per phase: down and up, then reconnect and test
```

`reboot` waits until `test_command` (default `whoami`) succeeds, then the play continues. It returns `elapsed`. `pre_reboot_delay` under 60 seconds rounds to 0 on Linux. Put reboots in handlers so they only happen when something required them.

---

## 5. Storage

### 5.1 The storage role

The spare disk on each lab host is 5 GB and unpartitioned. Find its kernel name first; names differ between hypervisors (`vdb`, `sdb`, `nvme0n2`):

```bash
ansible-navigator run disk_list.yml
```

```yaml
# group_vars/web/storage.yml
storage_pools:
  - name: data_vg
    type: lvm
    disks:
      - sdb                          # the spare disk from disk_list.yml
    volumes:
      - name: web_lv
        size: 512m
        fs_type: xfs
        mount_point: /srv/web
        state: present
      - name: logs_lv
        size: 1g
        fs_type: xfs
        mount_point: /srv/logs
      - name: swap_lv
        size: 256m
        fs_type: swap
```

```yaml
- name: Volume group, logical volumes, file systems, mounts, and swap
  ansible.builtin.include_role:
    name: redhat.rhel_system_roles.storage
```

In one run the role creates the physical volume, volume group, logical volumes, file systems, mount points, fstab entries (by UUID), mounts, and activates swap.

| Item | Rules |
|---|---|
| `size` | Lower case units `m`, `g`, `t`; or `50%`; bigger size on a later run grows the volume and file system |
| `fs_type` | `xfs` (default), `ext4`, `swap` |
| `mount_point` | Created if missing; omit for swap |
| `mount_options` | Default `defaults` |
| `state: absent` | On a volume removes it; on a pool removes the whole volume group |
| `storage_volumes` (top level) | File system directly on a whole disk: `{name, type: disk, disks: [sdc], mount_point}` |
| `storage_safe_mode` | Default `true`: the role refuses to destroy existing data (for example reformatting to another `fs_type`) |

XFS can only grow. Shrinking an XFS volume fails; the role protects you with safe mode.

### 5.2 Modules for everything else

| Need | Module |
|---|---|
| Mount an existing file system, NFS share, or tmpfs | `ansible.posix.mount` |
| Partitions | `community.general.parted` |
| Volume groups and logical volumes one by one | `community.general.lvg`, `community.general.lvol` |
| Make a file system | `community.general.filesystem` |

`ansible.posix.mount` states:

| `state` | fstab entry | Mounted now |
|---|---|---|
| `mounted` | Added | Yes (creates the directory) |
| `present` | Added | Not changed |
| `unmounted` | Kept | No |
| `absent` | Removed | No (directory removed too) |
| `remounted` | Kept | Remounted with new options |
| `ephemeral` | Not touched | Yes |

```yaml
- name: Scratch space is mounted now and at boot
  ansible.posix.mount:
    path: /mnt/scratch
    src: tmpfs
    fstype: tmpfs
    opts: size=64m,mode=1777
    state: mounted
```

For block devices, use `src: UUID=...` exactly as in fstab; device names can change between boots.

### 5.3 Storage facts

| Fact | Contents |
|---|---|
| `ansible_facts['devices']['sdb']` | `size`, `sectors`, `sectorsize`, `partitions`, `holders` (volumes using it), `links` |
| `ansible_facts['device_links']` | `ids`, `uuids`, `labels`, `masters` for every device |
| `ansible_facts['mounts']` | List of `{mount, device, fstype, options, size_total, size_available, uuid}` |
| `ansible_facts['lvm']` | Volume groups and logical volumes with sizes (when LVM tools exist) |

Facts are collected at the start of the play: after the storage role runs, gather again (`ansible.builtin.setup`) before reading them.

---

## 6. Networking

### 6.1 The network role

```yaml
# group_vars/web/network.yml
network_provider: nm
network_connections:
  - name: labbr0
    type: bridge
    state: up
    autoconnect: true
    zone: internal
    ip:
      dhcp4: false
      auto6: false
      address:
        - "192.168.251.{{ ansible_facts['default_ipv4']['address'].split('.')[-1] }}/24"
```

| Key | Meaning |
|---|---|
| `name` | NetworkManager profile name; for simple cases also the interface name |
| `type` | `ethernet`, `bridge`, `bond`, `vlan`, `macvlan`, `infiniband`, `wireless`, `team` |
| `interface_name`, `mac` | Bind the profile to an interface name or a MAC address |
| `state` | Runtime: `up` activates now, `down` deactivates |
| `persistent_state` | `present` (default) keeps the profile; `absent` deletes it |
| `ip.address` | List of `address/prefix` |
| `ip.gateway4`, `ip.dns`, `ip.dns_search` | Router, name servers, search domains |
| `ip.dhcp4`, `ip.auto6` | Dynamic addressing |
| `zone` | firewalld zone of the connection |
| `controller`, `port_type` | Make an ethernet profile a port of a bridge or bond |
| `parent`, `vlan: {id: 100}` | VLAN on top of **another profile listed in the same variable** |

The role manages **only** the profiles you list, but it manages them completely: listing the existing primary profile with a partial definition would replace its settings. Test network changes on an extra interface or bridge before touching the connection Ansible itself uses. In this course the extra interface is a bridge without ports, which needs no additional hardware.

For the common exam style task (a second NIC with a known MAC address):

```yaml
network_connections:
  - name: ens4
    type: ethernet
    mac: "52:54:00:01:00:6e"
    ip:
      address:
        - 192.168.0.12/24
    state: up
```

### 6.2 Other network modules

| Task | Module |
|---|---|
| Host name | `ansible.builtin.hostname` (does not edit `/etc/hosts`) |
| Firewall services, ports, zones, interfaces | `ansible.posix.firewalld` |
| One NetworkManager setting | `community.general.nmcli` |
| `/etc/hosts` entries | `ansible.builtin.lineinfile` or a template |

### 6.3 Network facts and connection variables

| Fact | Example |
|---|---|
| `ansible_facts['interfaces']` | `['lo', 'enp1s0', 'labbr0']` |
| `ansible_facts['enp1s0']` | `ipv4`, `ipv6`, `macaddress`, `mtu`, `type`, `active` (dashes in interface names become underscores) |
| `ansible_facts['default_ipv4']` | `address`, `interface`, `gateway`, `macaddress` of the default route |
| `ansible_facts['all_ipv4_addresses']` | Every IPv4 address |
| `ansible_facts['dns']` | `nameservers`, `search` |
| `ansible_facts['fqdn']`, `hostname`, `domain`, `nodename` | Name information |

Connection variables (Chapter 6): `inventory_hostname`, `ansible_host`, `ansible_port`, `ansible_user`, `ansible_connection` (`ssh`, `local`).

To find the interface with a given MAC address:

```yaml
- name: Interface with the lab MAC address
  ansible.builtin.debug:
    msg: "{{ item }}"
  loop: "{{ ansible_facts['interfaces'] }}"
  when: ansible_facts[item | replace('-', '_')]['macaddress'] | default('') == '52:54:00:01:00:6e'
```

---

## 7. Traps

| Trap | Symptom |
|---|---|
| Loop over `dnf` | Slow, one transaction per package |
| Reading `ansible_facts['packages']` after installing | Old snapshot; gather again |
| `gpgcheck: true` without a key | `Public key for ... is not installed` |
| `password: Plain text` in `user` | Unusable account; the field takes a hash |
| `password_hash` without salt | `changed` on every run |
| `groups:` without `append: true` | Other supplementary groups removed |
| sudoers without `validate` | One typo locks out sudo |
| `lineinfile` on sshd with a drop-in setting the same keyword | Change has no effect |
| cron job renamed | Duplicate job; remove the old name explicitly |
| `cron_file` without `user` | Module error |
| at job without `atd` | Job queued, never runs |
| Timer unit copied, no `daemon_reload` | `Unit lab-report.timer not found` |
| Wrong disk in `storage_pools` | Data loss risk; always confirm with `disk_list.yml` |
| Upper case size (`512M`) | Rejected or misread; use lower case |
| Partial primary connection in `network_connections` | Lost connectivity |
| Facts read right after a role changed storage or network | Stale values; run `setup` |

---

## 8. Chapter Checklist

* [ ] Keep system role variables in `group_vars`, and combine roles with post tasks and handlers.
* [ ] Handle a selinux role reboot with block and rescue.
* [ ] Configure a signed repository with `rpm_key` and `yum_repository`.
* [ ] Install packages, groups, and specific versions in one transaction.
* [ ] Read and refresh package facts.
* [ ] Create groups and users with fixed IDs, hashed passwords, and SSH keys.
* [ ] Write validated sudo and sshd changes.
* [ ] Schedule with cron (user and system), at, and systemd timers.
* [ ] Set the default target idempotently and reboot safely.
* [ ] Build LVM storage with file systems, mounts, and swap using the storage role; grow a volume.
* [ ] Mount with `ansible.posix.mount` and read storage facts.
* [ ] Configure a connection with the network role and read network facts.

## 9. Exam Rules From This Chapter

1. Read `/usr/share/doc/rhel-system-roles/ROLE/` and copy example variables.
2. Put role variables in `group_vars/GROUP/`, not in the playbook.
3. Import the GPG key before or with the repository; never disable `gpgcheck` to make it work.
4. Pass package lists, not loops.
5. Always hash passwords, with a fixed salt or `update_password: on_create`.
6. `append: true` whenever you add supplementary groups.
7. `validate:` on every sudoers and sshd edit.
8. Identify disks and interfaces with facts before configuring them.
9. `mounted`, not `present`, when the file system must be usable now.
10. After any change, prove it with an ad hoc command (`lvs`, `findmnt`, `swapon --show`, `crontab -l -u USER`, `nmcli`, `systemctl get-default`).

**Next:** Chapter 9 continues the course.

<!-- navfoot:start -->

---

← Previous: [Chapter 07 Lab Solution: `roles_review`](../07_roles/06_lab_solution.md) | Next: [Guided Exercise: Time Zones, Time Sync, and SELinux with System Roles](01_guided_exercise_system_roles.md) →

<!-- navfoot:end -->
