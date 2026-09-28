<!-- nav:start -->
[Course home](../README.md) › [Chapter 08: Automating Linux Administration](README.md) › Guided exercise (2 of 10)
<!-- nav:end -->

# Guided Exercise: Time Zones, Time Sync, and SELinux with System Roles

| | |
|---|---|
| **Exercise name** | `system_roles` |
| **Time** | 35 minutes |
| **Covers** | README section 1 |
| **You will** | Drive the timesync and selinux roles from group variables, set a different time zone per data center with post tasks and a reboot handler, and apply SELinux settings with the block and rescue reboot pattern |

---

## Before You Begin

```bash
lab start system_roles
```

Start creates `~/system_roles` and copies `redhat.rhel_system_roles` into its `collections/`. servera and serverb are set to UTC; the boolean `httpd_can_network_connect` is off and port 8088 carries no web label.

```bash
cd ~/system_roles
cat inventory
ansible-navigator run verify_admin.yml
```

| Group | Hosts |
|---|---|
| `web` | servera, serverb |
| `na_datacenter` | servera |
| `eu_datacenter` | serverb |

Open the project in the dev container or a workstation terminal.

---

## Part A: Time synchronization and time zones

### Step 1: Read the role documentation

```bash
less /usr/share/doc/rhel-system-roles/timesync/README.md
timedatectl list-timezones | grep -E 'Denver|Berlin'
```

Note `timesync_ntp_servers` (a list of dictionaries with `hostname` and `iburst`) and `timesync_ntp_provider`.

### Step 2: Group variables

```bash
mkdir -p group_vars/{all,na_datacenter,eu_datacenter,web}
```

`group_vars/all/timesync.yml`:

```yaml
---
# redhat.rhel_system_roles.timesync
timesync_ntp_provider: chrony
timesync_ntp_servers:
  - hostname: bastion.lab.example.com
    iburst: true
```

```bash
printf -- '---\nhost_timezone: America/Denver\n' > group_vars/na_datacenter/timezone.yml
printf -- '---\nhost_timezone: Europe/Berlin\n' > group_vars/eu_datacenter/timezone.yml
ansible-inventory --host servera.lab.example.com
ansible-inventory --host serverb.lab.example.com
```

Each host sees the shared NTP settings plus its own `host_timezone`.

### Step 3: Role plus post tasks plus handler

`time_zone.yml`:

```yaml
---
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
        msg: Rebooting to apply the new time zone
```

```bash
ansible-navigator run time_zone.yml
```

Order in the output: the role's tasks, its `Restart chronyd` handler (handlers notified by roles and tasks run before `post_tasks`), the two post tasks, and finally `RUNNING HANDLER [Reboot host]` for both hosts.

### Step 4: Idempotency and proof

```bash
ansible-navigator run time_zone.yml          # changed=0, no reboot
ansible-navigator run verify_admin.yml
ansible web -m ansible.builtin.command -a 'chronyc -n sources'
```

servera reports `America/Denver`, serverb `Europe/Berlin`, both with `server bastion.lab.example.com iburst`.

---

## Part B: SELinux with the reboot pattern

### Step 5: SELinux variables for the web group

`group_vars/web/selinux.yml`:

```yaml
---
# redhat.rhel_system_roles.selinux
selinux_state: enforcing
selinux_policy: targeted
selinux_booleans:
  - name: httpd_can_network_connect
    state: true
    persistent: true
selinux_ports:
  - ports: "8088"
    proto: tcp
    setype: http_port_t
    state: present
```

### Step 6: Block and rescue

`selinux_config.yml`:

```yaml
---
- name: SELinux settings from the system role
  hosts: web
  become: true
  tasks:
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

```bash
ansible-navigator run selinux_config.yml
ansible-navigator run verify_admin.yml
```

Both hosts show the boolean `on` and port 8088 labeled `http_port_t`. The rescue section did not run: the hosts were already enforcing, so no reboot was needed. On a host that had SELinux disabled, the same playbook would reboot it once and finish the job.

### Step 7: Prove the rescue logic without breaking anything

Add a wrong port type to `group_vars/web/selinux.yml` temporarily (`setype: no_such_port_t`) and run again. The role fails, `selinux_reboot_required` is false, and the first rescue task stops the play with its clear message instead of rebooting. Restore `http_port_t`.

Close the dev container.

---

## Finish

```bash
lab finish system_roles
```

Finish sets both hosts back to UTC, turns the boolean off, and removes the port label.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `the role 'redhat.rhel_system_roles.timesync' was not found` | `collections_path` must start with `./collections` |
| `host_timezone is undefined` | A host is in `web` but in neither data center group, or a file name is misspelled |
| Hosts reboot on every run | The comparison uses `stdout`; check for typos in the zone name with `timedatectl list-timezones` |

<!-- navfoot:start -->

---

← Previous: [Chapter 08: Automating Linux Administration](README.md) | Next: [Guided Exercise: Signed Repositories, Packages, and Package Facts](02_guided_exercise_system_software.md) →

<!-- navfoot:end -->
