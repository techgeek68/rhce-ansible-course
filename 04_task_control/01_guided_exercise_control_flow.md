<!-- nav:start -->
[Course home](../README.md) › [Chapter 04: Task Control](README.md) › Guided exercise (2 of 7)
<!-- nav:end -->

# Guided Exercise: Apply a Baseline with Loops and Conditions

| | |
|---|---|
| **Exercise name** | `control_flow` |
| **Time** | 40 minutes |
| **Covers** | README sections 1 and 2 |
| **You will** | Build a compliance baseline from one variable file: groups and users from lists, kernel settings from a dictionary, software chosen by memory and version, a login warning chosen by SELinux mode, and a report built from a registered loop |

---

## Before You Begin

```bash
lab start control_flow
```

Start creates `~/control_flow` (inventory: `web` = servera, serverb; `db` = serverc, serverd; `vars/baseline.yml`; `solutions/`), resets the four hosts, and then switches **serverb to SELinux permissive** so that the hosts differ. `lab finish` sets it back to enforcing.

Open the project in the dev container or a workstation terminal.

```bash
cat vars/baseline.yml
ansible all -m ansible.builtin.setup -a 'filter=ansible_selinux' -o | cut -c1-120
ansible all -m ansible.builtin.setup -a 'filter=ansible_memtotal_mb' -o
```

Note each host's SELinux mode and memory; you will predict results from them.

---

## Step 1: Groups from a simple list

Create `baseline.yml`:

```yaml
---
- name: Compliance baseline
  hosts: all
  vars_files:
    - vars/baseline.yml
  tasks:
    - name: Admin groups exist
      ansible.builtin.group:
        name: "{{ item }}"
        state: present
      loop: "{{ admin_groups }}"
```

```bash
ansible-navigator run baseline.yml
```

Each host shows `(item=ops)` and `(item=audit)`.

---

## Step 2: Users from a list of dictionaries

Append:

```yaml
    - name: Site users are in their declared state
      ansible.builtin.user:
        name: "{{ item['name'] }}"
        groups: "{{ item['groups'] }}"
        append: true
        state: "{{ item['state'] }}"
        remove: "{{ item['state'] == 'absent' }}"
      loop: "{{ site_users }}"
```

Run it and look at the output: every line prints the whole dictionary. Add a label under the loop:

```yaml
      loop_control:
        label: "{{ item['name'] }} ({{ item['state'] }})"
```

Run again: `ok: [servera.lab.example.com] => (item=ana (present))`. `lee` is `absent`, so the account is removed where it exists; the expression `item['state'] == 'absent'` also removes its home directory.

`append: true` adds the groups without removing other memberships; without it, `groups` would replace every supplementary group.

---

## Step 3: Kernel settings from a dictionary, db hosts only

Append:

```yaml
    - name: Database kernel parameters are set
      ansible.posix.sysctl:
        name: "{{ item['key'] }}"
        value: "{{ item['value'] }}"
        sysctl_file: /etc/sysctl.d/90-db.conf
        reload: true
      loop: "{{ db_kernel_params | dict2items }}"
      when: "'db' in group_names"
```

Predict: serverc and serverd change, servera and serverb skip. Run and confirm. The `when` is checked for each item, so skipped hosts show one `skipping` line per item.

```bash
ansible db -m ansible.builtin.command -a 'cat /etc/sysctl.d/90-db.conf'
```

Try the loop without `dict2items` once to see the error: `Invalid data passed to 'loop', it requires a list`.

---

## Step 4: Software chosen by memory and version

Append:

```yaml
    - name: Monitoring tools on hosts with enough memory
      ansible.builtin.dnf:
        name: sysstat
        state: present
      when:
        - ansible_facts['memtotal_mb'] >= monitor_min_ram_mb
        - ansible_facts['distribution_major_version'] | int >= 9
```

Predict from the memory values you noted: hosts with at least 1024 MiB get sysstat. The list under `when` means both conditions must hold.

Remove `| int` and run once more. The version condition now compares the string `"9"` (or `"10"`) with the integer 9, and the task fails with a type comparison error. Restore `| int`.

---

## Step 5: A warning chosen by SELinux mode

Append:

```yaml
    - name: Warn at login when SELinux is not enforcing
      ansible.builtin.copy:
        content: "WARNING: SELinux is {{ ansible_facts['selinux']['mode'] }} on this host.\n"
        dest: /etc/motd
        mode: "0644"
      when: ansible_facts['selinux']['mode'] != 'enforcing'

    - name: Clear the warning when SELinux is enforcing
      ansible.builtin.copy:
        content: ""
        dest: /etc/motd
        mode: "0644"
      when: ansible_facts['selinux']['mode'] == 'enforcing'
```

```bash
ansible-navigator run baseline.yml
ansible all -m ansible.builtin.command -a 'cat /etc/motd' -o
```

Only serverb shows `WARNING: SELinux is permissive on this host.` Two mutually exclusive conditions keep the file correct in both directions: if someone later fixes SELinux, the next run clears the warning.

---

## Step 6: A report from a registered loop

Append a second play:

```yaml
- name: Account report
  hosts: all
  become: false
  gather_facts: false
  vars_files:
    - vars/baseline.yml
  tasks:
    - name: Look up every site user
      ansible.builtin.command: getent passwd {{ item['name'] }}
      loop: "{{ site_users }}"
      loop_control:
        label: "{{ item['name'] }}"
      register: lookups
      changed_when: false
      failed_when: lookups['rc'] not in [0, 2]

    - name: Report accounts that do not exist
      ansible.builtin.debug:
        msg: "{{ item['item']['name'] }} is absent on {{ inventory_hostname }}"
      loop: "{{ lookups['results'] }}"
      loop_control:
        label: "{{ item['item']['name'] }}"
      when: item['rc'] == 2
```

`getent` exits with 2 when an account does not exist. `failed_when` turns that expected result into success, while any other code still fails. Inside `failed_when` of a looping task, `lookups` means the current item's result.

```bash
ansible-navigator run baseline.yml
```

The report prints `lee is absent on ...` for every host. To see where `rc` and `item` live, add this task temporarily at the end of the second play, run once, then remove it:

```yaml
    - name: Show the first registered result
      ansible.builtin.debug:
        var: lookups['results'][0]
```

---

## Step 7: Idempotency

```bash
ansible-navigator run baseline.yml
```

Expected: `changed=0` for every host. The SELinux mode, the memory, and the group membership still steer the tasks, but nothing needs changing.

Compare with `solutions/baseline.yml` and close the dev container.

---

## Finish

```bash
lab finish control_flow
```

Finish removes the accounts, groups, kernel parameter file, and sysstat, empties `/etc/motd`, and sets SELinux back to enforcing on serverb. Kernel values already applied stay in memory until the next reboot, which is harmless in the lab.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Unsupported parameters for (ansible.builtin.user) module: when` | `when` is indented under the module; move it to task level |
| Users lose other groups | `append: true` missing |
| All hosts get the SELinux warning | `ansible_facts['selinux']['mode']` misspelled, so the comparison with `enforcing` is always false |
| Report task fails for lee | `failed_when` missing on the lookup task |

<!-- navfoot:start -->

---

← Previous: [Chapter 04: Task Control](README.md) | Next: [Guided Exercise: React to Changes with Handlers](02_guided_exercise_control_handlers.md) →

<!-- navfoot:end -->
