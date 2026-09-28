<!-- nav:start -->
[Course home](../README.md) › [Chapter 08: Automating Linux Administration](README.md) › Guided exercise (5 of 10)
<!-- nav:end -->

# Guided Exercise: cron, at, Timers, Boot Target, and Reboots

| | |
|---|---|
| **Exercise name** | `system_process` |
| **Time** | 35 minutes |
| **Covers** | README section 4 |
| **You will** | Schedule user and system cron jobs and remove them cleanly, queue a one time job, replace cron with a systemd timer, switch the default target idempotently, and reboot under control |

---

## Before You Begin

```bash
lab start system_process
```

Start creates `~/system_process` and removes any earlier jobs, timers, and target changes from servera. Open the project in the dev container or a workstation terminal.

---

## Step 1: Two kinds of cron jobs

`cron.yml`:

```yaml
---
- name: Scheduled jobs with cron
  hosts: web
  become: true
  tasks:
    - name: Personal crontab entry for devops
      ansible.builtin.cron:
        name: Record uptime
        user: devops
        minute: "*/10"
        job: uptime >> /home/devops/uptime.log

    - name: System job in /etc/cron.d
      ansible.builtin.cron:
        name: Record disk usage
        cron_file: lab_disk_usage
        user: devops
        minute: "*/5"
        hour: "8-17"
        weekday: "1-5"
        job: df -h / >> /home/devops/disk_usage.log
```

```bash
ansible-navigator run cron.yml
ansible web -b -m ansible.builtin.command -a 'crontab -l -u devops'
ansible web -m ansible.builtin.command -a 'cat /etc/cron.d/lab_disk_usage'
```

The personal entry has five time fields; the `/etc/cron.d` line has a sixth field, the user. Both carry an `#Ansible:` comment with the task's `name`.

### The rename trap

Change the first `name` to `Record system uptime` and run again. `crontab -l -u devops` now shows **two** jobs: the name is the identity. Put the original name back and remove the duplicate:

```bash
ansible web -b -m ansible.builtin.cron -a 'name="Record system uptime" user=devops state=absent'
```

---

## Step 2: Remove the jobs

`remove_cron.yml`:

```yaml
---
- name: Remove the scheduled cron jobs
  hosts: web
  become: true
  tasks:
    - name: Personal crontab entry is gone
      ansible.builtin.cron:
        name: Record uptime
        user: devops
        state: absent

    - name: System job is gone
      ansible.builtin.cron:
        name: Record disk usage
        cron_file: lab_disk_usage
        user: devops
        state: absent
```

```bash
ansible-navigator run remove_cron.yml
ansible web -m ansible.builtin.command -a 'ls /etc/cron.d'
```

The cron file is deleted once its last job is gone.

---

## Step 3: A one time job

`at_job.yml`:

```yaml
---
- name: One time job with at
  hosts: web
  become: true
  tasks:
    - name: At is installed
      ansible.builtin.dnf:
        name: at
        state: present

    - name: Atd runs and starts at boot
      ansible.builtin.systemd_service:
        name: atd
        state: started
        enabled: true

    - name: Job runs once in two minutes
      ansible.posix.at:
        command: date > /tmp/lab_at_run
        count: 2
        units: minutes
        unique: true
```

```bash
ansible-navigator run at_job.yml
ansible-navigator run at_job.yml     # unique: the job is not queued twice
ansible web -b -m ansible.builtin.command -a atq
```

After two minutes, `ansible web -m ansible.builtin.command -a 'cat /tmp/lab_at_run'` shows the time the job ran and `atq` is empty.

---

## Step 4: A systemd timer instead of cron

`timer.yml`:

```yaml
---
- name: Recurring job with a systemd timer
  hosts: web
  become: true
  tasks:
    - name: Service unit exists
      ansible.builtin.copy:
        dest: /etc/systemd/system/lab-report.service
        mode: "0644"
        content: |
          [Unit]
          Description=Append a time stamp to the lab report

          [Service]
          Type=oneshot
          ExecStart=/bin/sh -c 'date >> /var/log/lab-report.log'

    - name: Timer unit exists
      ansible.builtin.copy:
        dest: /etc/systemd/system/lab-report.timer
        mode: "0644"
        content: |
          [Unit]
          Description=Run lab-report every two minutes

          [Timer]
          OnCalendar=*:0/2
          Persistent=true

          [Install]
          WantedBy=timers.target

    - name: Timer runs and starts at boot
      ansible.builtin.systemd_service:
        name: lab-report.timer
        state: started
        enabled: true
        daemon_reload: true
```

Try it once **without** `daemon_reload: true` after changing the timer's `OnCalendar` to `*:0/3`: the timer keeps its old schedule (`systemctl list-timers` still shows two minute steps) and systemd warns that the unit file changed on disk. Put `daemon_reload: true` back and run again.

```bash
ansible-navigator run timer.yml
ansible web -m ansible.builtin.command -a 'systemctl list-timers lab-report.timer'
ansible web -b -m ansible.builtin.command -a 'journalctl -u lab-report.service -n 3 --no-pager'
```

---

## Step 5: Default boot target, idempotently

`boot_target.yml`:

```yaml
---
- name: Default boot target
  hosts: web
  become: true
  gather_facts: false
  vars:
    default_target: graphical.target
  tasks:
    - name: Current default target is read
      ansible.builtin.command: systemctl get-default
      register: current_target
      changed_when: false

    - name: Default target is set
      ansible.builtin.command: systemctl set-default {{ default_target }}
      when: current_target['stdout'] != default_target
      changed_when: true
```

```bash
ansible-navigator run boot_target.yml     # changed=1
ansible-navigator run boot_target.yml     # changed=0
```

---

## Step 6: Controlled reboot

`reboot.yml`:

```yaml
---
- name: Controlled reboot
  hosts: web
  become: true
  gather_facts: false
  tasks:
    - name: Boot time before
      ansible.builtin.command: who -b
      register: boot_before
      changed_when: false

    - name: Host reboots and comes back
      ansible.builtin.reboot:
        msg: Rebooting for lab maintenance
        reboot_timeout: 600
      register: reboot_result

    - name: Boot time after
      ansible.builtin.command: who -b
      register: boot_after
      changed_when: false

    - name: Report
      ansible.builtin.debug:
        msg:
          - "Before: {{ boot_before['stdout'] | trim }}"
          - "After:  {{ boot_after['stdout'] | trim }}"
          - "Reboot took {{ reboot_result['elapsed'] | default('?') }} seconds"
```

```bash
ansible-navigator run reboot.yml
ansible web -m ansible.builtin.command -a 'systemctl get-default'
ansible web -m ansible.builtin.command -a 'systemctl is-enabled lab-report.timer'
```

The play waited for the host and continued. The default target and the enabled timer survived the reboot; the at job queue is empty, as one time jobs should be.

Close the dev container.

---

## Finish

```bash
lab finish system_process
```

Finish removes the jobs and timer and restores `multi-user.target`.

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Accounts, Keys, sudo, and sshd](03_guided_exercise_system_users.md) | Next: [Guided Exercise: LVM, File Systems, Swap, and Mounts](05_guided_exercise_system_storage.md) →

<!-- navfoot:end -->
