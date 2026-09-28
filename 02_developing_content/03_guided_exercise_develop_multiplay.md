<!-- nav:start -->
[Course home](../README.md) › [Chapter 02: Developing Automation Content](README.md) › Guided exercise (4 of 8)
<!-- nav:end -->

# Guided Exercise: Orchestrate Several Plays

| | |
|---|---|
| **Exercise name** | `develop_multiplay` |
| **Time** | 35 minutes |
| **Covers** | README section 3 |
| **You will** | Watch a shell task break idempotency and fix it, then write a three play playbook that configures servera, tests it from serverb, and writes the result as a different user |

---

## Before You Begin

```bash
lab start develop_multiplay
```

Start creates `~/develop_multiplay`, removes httpd and the page from servera, empties `/etc/motd` on serverb, and deletes any earlier probe report.

Open the project in the dev container or a workstation terminal.

```bash
cat ansible.cfg inventory
```

`become = false` in `ansible.cfg`: in this project each play decides whether it needs root. Groups: `intranet` (servera) and `probes` (serverb).

---

## Part A: Idempotency, the hard way

### Step 1: Run the provided shell playbook twice

```bash
cat append_banner.yml
ansible-navigator run append_banner.yml
ansible-navigator run append_banner.yml
ssh devops@serverb.lab.example.com cat /etc/motd
```

Both runs report `changed=1`, and the banner now appears **twice**. Every run appends another copy.

```bash
ansible-lint append_banner.yml
```

Lint reports `no-changed-when`: a command task that claims a change on every run.

### Step 2: Replace it with a state based module

Empty the file with an ad hoc command, then rewrite the task:

```bash
ansible probes -b -m ansible.builtin.copy -a 'content="" dest=/etc/motd mode=0644'
```

`append_banner.yml`:

```yaml
---
- name: Login banner on the probe host
  hosts: probes
  become: true
  tasks:
    - name: Banner line is present exactly once
      ansible.builtin.lineinfile:
        path: /etc/motd
        line: Monitoring probe. Contact the platform team.
        state: present
```

```bash
ansible-navigator run append_banner.yml     # changed=1
ansible-navigator run append_banner.yml     # changed=0
ssh devops@serverb.lab.example.com cat /etc/motd
ansible-lint append_banner.yml              # Passed
```

One line, however often you run it.

---

## Part B: Three plays, three responsibilities

### Step 3: Play 1 configures the intranet server

Create `intranet.yml`:

```yaml
---
- name: Intranet web server is ready
  hosts: intranet
  become: true
  tasks:
    - name: Web server and firewall packages are installed
      ansible.builtin.dnf:
        name:
          - httpd
          - firewalld
        state: present

    - name: Intranet home page is in place
      ansible.builtin.copy:
        content: "Intranet online\n"
        dest: /var/www/html/index.html
        mode: "0644"

    - name: Firewalld is running and starts at boot
      ansible.builtin.systemd_service:
        name: firewalld
        state: started
        enabled: true

    - name: Firewall allows http now and after reboot
      ansible.posix.firewalld:
        service: http
        permanent: true
        immediate: true
        state: enabled

    - name: Httpd is running and starts at boot
      ansible.builtin.systemd_service:
        name: httpd
        state: started
        enabled: true
```

Notes: `name:` of `dnf` takes a **list** to install several packages in one transaction, which is faster than one task per package. Task order matters: firewalld must run before its rules can be applied.

### Step 4: Play 2 tests it from another host

Append:

```yaml
- name: Probe host checks the intranet
  hosts: probes
  become: false
  tasks:
    - name: Intranet answers with HTTP 200
      ansible.builtin.uri:
        url: http://servera.lab.example.com
        return_content: true
        status_code: 200
      register: probe

    - name: Show what the intranet returned
      ansible.builtin.debug:
        var: probe.content
```

The request originates on **serverb**, not on workstation: this proves the page is reachable across the lab network through the firewall. No root is needed to make an HTTP request, so `become: false`.

### Step 5: Play 3 writes the result as a different user

Append:

```yaml
- name: Probe result is stored for the student account
  hosts: probes
  become: true
  become_user: student
  tasks:
    - name: Report file is written as student
      ansible.builtin.copy:
        content: "{{ probe.url }} answered {{ probe.status }}: {{ probe.content }}"
        dest: /home/student/intranet_probe.txt
        mode: "0644"
```

Two things to notice:

* `probe` was registered in Play 2 on serverb and is still available in Play 3 on the same host.
* Ansible logs in as `devops` and becomes `student`, so the file is owned by student without any `owner:` argument.

### Step 6: Validate and run

```bash
ansible-navigator run intranet.yml --syntax-check
ansible-lint intranet.yml
ansible-navigator run intranet.yml --list-hosts
ansible-navigator run intranet.yml
```

`--list-hosts` prints three plays with their hosts. The run ends with:

```
servera.lab.example.com    : ok=6    changed=5  ...
serverb.lab.example.com    : ok=5    changed=1  ...
```

and the debug task shows `"probe.content": "Intranet online\n"`.

```bash
ssh devops@serverb.lab.example.com 'ls -l /home/student/intranet_probe.txt; cat /home/student/intranet_probe.txt'
```

The file is owned by `student`.

Run the playbook once more: `changed=0` for both hosts.

---

## Part C: Who logs in, who acts

### Step 7: Override the login user in one play

In Play 2, add `remote_user: student` under `hosts: probes` and run again:

```bash
ansible-navigator run intranet.yml -vvv 2>&1 | grep -E 'ESTABLISH SSH CONNECTION FOR USER'
```

Plays 1 and 3 still log in as `devops`, Play 2 as `student`. It works because the lab key is authorized for student too.

Change it to `remote_user: nobody` and run again: Play 2 fails with `UNREACHABLE ... nobody@serverb.lab.example.com: Permission denied (publickey...)`. The account in front of `@` always tells you which login user Ansible chose.

Remove the `remote_user` line so the file matches `solutions/intranet.yml`.

Close the dev container.

---

## Finish

```bash
lab finish develop_multiplay
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Play 3 fails with `Failed to set permissions on the temporary files` | The `acl` package is missing on serverb: `ansible probes -b -m ansible.builtin.dnf -a 'name=acl state=present'` |
| Play 3 fails with `'probe' is undefined` | Play 2 did not run on the same host, or the `register:` line is misindented |
| uri task times out | Play 1 firewall task missing `immediate: true` |
| Play 1 fails with a permission error | `become: true` missing on Play 1; the project default is false |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Write, Check, Run, and Replay a Single Play](02_guided_exercise_develop_singleplay.md) | Next: [Guided Exercise: Diagnose and Repair Broken Automation](04_guided_exercise_develop_troubleshoot.md) →

<!-- navfoot:end -->
