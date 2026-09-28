<!-- nav:start -->
[Course home](../README.md) › [Chapter 05: Deploying and Managing Files](README.md) › Guided exercise (2 of 6)
<!-- nav:end -->

# Guided Exercise: Manage Files, Lines, Blocks, and Links

| | |
|---|---|
| **Exercise name** | `files_manage` |
| **Time** | 40 minutes |
| **Covers** | README section 1 |
| **You will** | Build a shared report drop zone, tighten one SSH setting safely, manage two independent blocks in one file, then inspect, search, and collect files from a host |

---

## Before You Begin

```bash
lab start files_manage
```

Start creates `~/files_manage` (inventory: `app` = serverc, serverd; `files/README.txt`; `solutions/`) and resets both hosts: no report directory, default SSH settings, no leftover backups.

Open the project in the dev container or a workstation terminal.

---

## Part A: Build the drop zone

### Step 1: Group, directory, file, link

Create `drop_zone.yml`:

```yaml
---
- name: Report drop zone and SSH policy
  hosts: app
  vars:
    drop_dir: /srv/reports
    drop_group: reports
  tasks:
    - name: Report group exists
      ansible.builtin.group:
        name: "{{ drop_group }}"
        state: present

    - name: Drop directory is group writable and keeps group ownership
      ansible.builtin.file:
        path: "{{ drop_dir }}"
        state: directory
        owner: root
        group: "{{ drop_group }}"
        mode: "2770"

    - name: Instructions file is in the drop directory
      ansible.builtin.copy:
        src: files/README.txt
        dest: "{{ drop_dir }}/"
        owner: root
        group: "{{ drop_group }}"
        mode: "0640"

    - name: Shortcut link points to the drop directory
      ansible.builtin.file:
        src: "{{ drop_dir }}"
        dest: /srv/latest
        state: link
```

```bash
ansible-navigator run drop_zone.yml
ansible app -m ansible.builtin.command -a 'ls -ld /srv/reports /srv/latest /srv/reports/README.txt'
```

`drwxrws---` on the directory: the `s` in the group position is the setgid bit from the leading `2` in `2770`. Every file created inside inherits group `reports`. `/srv/latest -> /srv/reports` is the link.

Test the setgid effect:

```bash
ansible serverc.lab.example.com -m ansible.builtin.command -a 'touch /srv/reports/test.txt'
ansible serverc.lab.example.com -m ansible.builtin.command -a 'ls -l /srv/reports/test.txt'
```

The file belongs to group `reports` although root created it.

### Step 2: Watch a mode go wrong

Change the copy task's mode to `mode: 640` (no quotes, no leading zero), run, and look:

```bash
ansible-navigator run drop_zone.yml
ansible app -m ansible.builtin.command -a 'ls -l /srv/reports/README.txt'
```

The permissions are nonsense, because YAML read the decimal number 640 and Ansible applied it as octal 1200. Restore `mode: "0640"` and run again.

---

## Part B: One SSH setting, safely

### Step 3: `lineinfile` with validation and a handler

Append to the tasks, and add a `handlers:` section at the end of the play:

```yaml
    - name: SSH allows at most three authentication attempts
      ansible.builtin.lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?MaxAuthTries'
        line: MaxAuthTries 3
        backup: true
        validate: /usr/sbin/sshd -t -f %s
      notify: Reload sshd

  handlers:
    - name: Reload sshd
      ansible.builtin.systemd_service:
        name: sshd
        state: reloaded
```

```bash
ansible-navigator run drop_zone.yml
ansible app -m ansible.builtin.shell -a 'grep -n MaxAuthTries /etc/ssh/sshd_config; sshd -T | grep -i maxauthtries'
```

The commented default `#MaxAuthTries 6` became `MaxAuthTries 3`, and the running configuration reports `maxauthtries 3`.

### Step 4: Break the regexp on purpose

Change `regexp` to `'^#MaxAuthTries'` (no `?`) and run twice. Then:

```bash
ansible app -m ansible.builtin.command -a 'grep -c ^MaxAuthTries /etc/ssh/sshd_config'
```

The count grows: the regexp no longer matches the line it wrote, so each run appends a new copy. Restore `'^#?MaxAuthTries'`, then remove the duplicates:

```bash
ansible app -m ansible.builtin.lineinfile -a "path=/etc/ssh/sshd_config regexp='^MaxAuthTries' state=absent"
ansible-navigator run drop_zone.yml
```

`state: absent` with a regexp removes **every** matching line; the playbook then writes exactly one.

### Step 5: See `validate` refuse a bad file

Change `line:` to `MaxAuthTries three` and run. The task fails with sshd's own complaint about an invalid number, and the real file is untouched:

```bash
ansible app -m ansible.builtin.command -a 'sshd -t'
```

No output: the live configuration is still valid. Restore `MaxAuthTries 3`.

---

## Part C: Two blocks in one file

### Step 6: Independent markers

Append:

```yaml
    - name: Storage settings block
      ansible.builtin.blockinfile:
        path: /etc/sysconfig/reports
        create: true
        mode: "0644"
        marker: "# {mark} STORAGE SETTINGS"
        block: |
          REPORT_DIR={{ drop_dir }}
          REPORT_GROUP={{ drop_group }}

    - name: Retention settings block
      ansible.builtin.blockinfile:
        path: /etc/sysconfig/reports
        marker: "# {mark} RETENTION SETTINGS"
        block: |
          KEEP_DAYS=30
          COMPRESS=yes
```

```bash
ansible-navigator run drop_zone.yml
ansible serverc.lab.example.com -m ansible.builtin.command -a 'cat /etc/sysconfig/reports'
```

Change `KEEP_DAYS=30` to `KEEP_DAYS=60` and run again: only the retention block changes. Run a third time: `ok`.

### Step 7: Remove one block

Run an ad hoc task with the same marker and `state=absent`:

```bash
ansible app -m ansible.builtin.blockinfile \
  -a "path=/etc/sysconfig/reports marker='# {mark} RETENTION SETTINGS' state=absent"
ansible serverc.lab.example.com -m ansible.builtin.command -a 'cat /etc/sysconfig/reports'
```

Only the storage block remains. The next playbook run puts the retention block back, which is exactly what configuration management should do.

---

## Part D: Inspect, search, collect

### Step 8: Write `inspect.yml`

```yaml
---
- name: Inspect and collect files from serverc
  hosts: serverc.lab.example.com
  tasks:
    - name: Status of the SSH server configuration
      ansible.builtin.stat:
        path: /etc/ssh/sshd_config
        checksum_algorithm: sha256
      register: sshd_stat

    - name: Show owner, mode, and checksum
      ansible.builtin.debug:
        msg:
          - "owner={{ sshd_stat['stat']['pw_name'] }} group={{ sshd_stat['stat']['gr_name'] }}"
          - "mode={{ sshd_stat['stat']['mode'] }}"
          - "sha256={{ sshd_stat['stat']['checksum'] }}"
      when: sshd_stat['stat']['exists']

    - name: Find backups made by lineinfile
      ansible.builtin.find:
        paths: /etc/ssh
        patterns: "sshd_config.*~"
      register: sshd_backups

    - name: List the backups
      ansible.builtin.debug:
        msg: "{{ sshd_backups['files'] | map(attribute='path') | list }}"

    - name: Find recent log files larger than 10 KiB
      ansible.builtin.find:
        paths: /var/log
        patterns: "*.log"
        size: 10k
        age: -7d
        recurse: true
      register: found_logs

    - name: Collect the logs into the project
      ansible.builtin.fetch:
        src: "{{ item['path'] }}"
        dest: "{{ playbook_dir }}/collected/"
      loop: "{{ found_logs['files'] }}"
      loop_control:
        label: "{{ item['path'] }}"

    - name: Collect the SSH configuration under a flat name
      ansible.builtin.fetch:
        src: /etc/ssh/sshd_config
        dest: "{{ playbook_dir }}/collected/sshd_config-{{ inventory_hostname }}"
        flat: true
```

```bash
ansible-navigator run inspect.yml
find collected -type f | sort
```

The backup list shows one timestamped copy per change `lineinfile` made with `backup: true`. The collected logs sit under `collected/serverc.lab.example.com/var/log/...`, the SSH file directly at `collected/sshd_config-serverc.lab.example.com`.

Change `age: -7d` to `age: 7d` and run again: now only logs **older** than a week are found, which on fresh lab hosts is usually none.

Compare with `solutions/` and close the dev container.

---

## Finish

```bash
lab finish files_manage
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `validate` fails with `sshd: command not found` | Use the full path `/usr/sbin/sshd` |
| Blocks replace each other | Both tasks use the same `marker` |
| `fetch` fails with permission denied on `/var/log/...` | `become` is required for root only files; the project enables it |
| `collected/` is empty in the project although the run succeeded | Relative `dest` without `playbook_dir` resolved elsewhere; use `{{ playbook_dir }}/collected/` |

<!-- navfoot:start -->

---

← Previous: [Chapter 05: Deploying and Managing Files](README.md) | Next: [Guided Exercise: Render Host Specific Files with Jinja2](02_guided_exercise_files_templates.md) →

<!-- navfoot:end -->
