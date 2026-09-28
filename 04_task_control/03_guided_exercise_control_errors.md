<!-- nav:start -->
[Course home](../README.md) › [Chapter 04: Task Control](README.md) › Guided exercise (4 of 7)
<!-- nav:end -->

# Guided Exercise: Decide What Failure Means

| | |
|---|---|
| **Exercise name** | `control_errors` |
| **Time** | 40 minutes |
| **Covers** | README sections 3.6 and 4 |
| **You will** | Tolerate an optional failure, rescue a lost handler notification, make command tasks report honestly, validate input with `assert`, and recover from a failed download with `block`, `rescue`, and `always` |

---

## Before You Begin

```bash
lab start control_errors
```

Start creates `~/control_errors` (inventory: `prod` = servera, serverb; `dev` = serverc, serverd; `files/motd.txt`; `solutions/`) and cleans the files and packages used here from all four hosts.

The package `telemetry-agent` used below does not exist in the lab repositories. It stands in for any optional component that may be missing.

---

## Part A: Optional software

### Step 1: Watch the default behavior

Create `optional.yml`:

```yaml
---
- name: Required and optional software
  hosts: dev
  tasks:
    - name: Required package is installed
      ansible.builtin.dnf:
        name: tree
        state: present

    - name: Optional agent is installed when available
      ansible.builtin.dnf:
        name: telemetry-agent
        state: present

    - name: Play reached its end
      ansible.builtin.debug:
        msg: Required software is in place.
```

```bash
ansible-navigator run optional.yml
```

The second task fails with `No package telemetry-agent available`, the third never runs, and the recap shows `failed=1`.

### Step 2: Tolerate it

Add to the optional task:

```yaml
      ignore_errors: true  # noqa: ignore-errors
```

```bash
ansible-navigator run optional.yml
```

The failure is printed followed by `...ignoring`, the debug task runs, and the recap shows `failed=0 ignored=1`. The `noqa` comment tells ansible-lint that ignoring is intentional here; without it lint reports `ignore-errors`.

---

## Part B: The lost notification

### Step 3: Lose it

Create `banner.yml` **without** `force_handlers`:

```yaml
---
- name: Banner changes are always logged
  hosts: dev
  tasks:
    - name: Login banner is current
      ansible.builtin.copy:
        src: files/motd.txt
        dest: /etc/motd
        mode: "0644"
      notify: Log banner change

    - name: Optional agent is installed
      ansible.builtin.dnf:
        name: telemetry-agent
        state: present

  handlers:
    - name: Log banner change
      ansible.builtin.lineinfile:
        path: /var/log/motd_changes.log
        line: "Banner updated by Ansible at {{ ansible_facts['date_time']['iso8601'] }}"
        create: true
        mode: "0644"
```

```bash
ansible-navigator run banner.yml
ansible dev -m ansible.builtin.command -a 'cat /var/log/motd_changes.log' -o
```

The banner changed, the handler was notified, the next task failed, and the handler **did not run**: the log file does not exist. Run the playbook again: the banner task is now `ok`, so the handler is not even notified. The change is permanently unlogged.

### Step 4: Keep it

Reset the banner so the change happens again, add `force_handlers: true` under `hosts: dev`, and run:

```bash
ansible dev -m ansible.builtin.copy -a 'content="" dest=/etc/motd'
ansible-navigator run banner.yml
ansible dev -m ansible.builtin.command -a 'cat /var/log/motd_changes.log' -o
```

The optional task still fails, but `RUNNING HANDLER [Log banner change]` appears and the log has its line. `--force-handlers` on the command line does the same for a single run.

---

## Part C: Honest commands and validated input

### Step 5: Write `commands.yml`

```yaml
---
- name: Honest command tasks and input validation
  hosts: dev
  vars:
    app_port: 8080
  tasks:
    - name: Port setting is valid
      ansible.builtin.assert:
        that:
          - app_port | int >= 1024
          - app_port | int <= 65535
        fail_msg: "app_port {{ app_port }} must be between 1024 and 65535"
        success_msg: "app_port {{ app_port }} accepted"

    - name: Read the root file system type
      ansible.builtin.command: findmnt -n -o FSTYPE /
      register: root_fs
      changed_when: false
      failed_when: root_fs['stdout'] not in ['xfs', 'ext4']

    - name: Drop directory exists
      ansible.builtin.file:
        path: /srv/drop
        state: directory
        mode: "0755"

    - name: SELinux labels of the drop directory are correct
      ansible.builtin.command: restorecon -Rv /srv/drop
      register: relabel
      changed_when: "'Relabeled' in relabel['stdout']"
```

| Task | Control keyword | Why |
|---|---|---|
| `assert` | `that`, `fail_msg` | Stops early with a clear message when input is wrong |
| `findmnt` | `changed_when: false`, `failed_when` | Read only; fails only for an unsupported file system |
| `restorecon -v` | `changed_when` on output | Prints `Relabeled` only when it actually changed a label |

### Step 6: Prove each keyword

```bash
ansible-navigator run commands.yml                   # changed=1 (directory created), assert passes
ansible-navigator run commands.yml                   # changed=0
ansible dev -m ansible.builtin.command -a 'chcon -t tmp_t /srv/drop'
ansible-navigator run commands.yml                   # restorecon task changed on both hosts
ansible-navigator run commands.yml -e app_port=80    # assert fails with your message
```

`-e app_port=80` arrives as a string; `| int` in the assertion makes the comparison numeric.

---

## Part D: Recover with a block

### Step 7: Write `deploy_config.yml`

```yaml
---
- name: Application configuration with a safe fallback
  hosts: prod
  vars:
    config_url: http://materials.example.com/config/labapp.conf
  tasks:
    - name: Configuration directory exists
      ansible.builtin.file:
        path: /etc/labapp
        state: directory
        mode: "0755"

    - name: Configuration comes from the central source when possible
      block:
        - name: Central configuration is downloaded
          ansible.builtin.get_url:
            url: "{{ config_url }}"
            dest: /etc/labapp/labapp.conf
            mode: "0644"

        - name: Record the source
          ansible.builtin.set_fact:
            config_source: central

      rescue:
        - name: Explain the failure
          ansible.builtin.debug:
            msg: >-
              {{ ansible_failed_task['name'] }} failed:
              {{ ansible_failed_result['msg'] }}

        - name: Default configuration is written instead
          ansible.builtin.copy:
            content: |
              # Default configuration, central source unavailable
              listen_port = 8080
            dest: /etc/labapp/labapp.conf
            mode: "0644"

        - name: Record the source
          ansible.builtin.set_fact:
            config_source: fallback

      always:
        - name: Status file names the configuration source
          ansible.builtin.copy:
            content: "config_source={{ config_source | default('unknown') }}\n"
            dest: /etc/labapp/status
            mode: "0644"
```

### Step 8: Run the failure path

```bash
ansible-navigator run deploy_config.yml
ansible prod -m ansible.builtin.command -a 'cat /etc/labapp/status' -o
```

The download fails with HTTP 404, the rescue explains which task failed and why, writes the default file, and the always section records `config_source=fallback`. The recap shows `failed=0 rescued=1`: the play succeeded because the rescue did.

### Step 9: Run the success path

Point the variable at a URL that exists (the collection index on materials.example.com):

```bash
ansible-navigator run deploy_config.yml -e config_url=http://materials.example.com/collections/
ansible prod -m ansible.builtin.command -a 'cat /etc/labapp/status' -o
```

No rescue this time, and `config_source=central`. The always section ran in both cases.

Compare your files with `solutions/` and close the dev container.

---

## Finish

```bash
lab finish control_errors
```

## What You Proved

| Mechanism | Evidence |
|---|---|
| `ignore_errors` | `ignored=1`, play continued |
| Lost notification | Log missing after a failure, and still missing after the rerun |
| `force_handlers` | Handler ran despite the failure |
| `changed_when` on output | restorecon reported `changed` only after `chcon` |
| `assert` | Clear message for a bad port |
| `block`, `rescue`, `always` | Fallback file, `rescued=1`, status written on both paths |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: React to Changes with Handlers](02_guided_exercise_control_handlers.md) | Next: [Chapter 04 Quiz: Loops, Conditionals, Handlers, and Failures](04_quiz.md) →

<!-- navfoot:end -->
