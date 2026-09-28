<!-- nav:start -->
[Course home](../README.md) › [Chapter 06: Automation at Scale](README.md) › Guided exercise (2 of 6)
<!-- nav:end -->

# Guided Exercise: Assemble a Playbook from Reusable Files

| | |
|---|---|
| **Exercise name** | `scale_files` |
| **Time** | 40 minutes |
| **Covers** | README sections 1 and 2 |
| **You will** | Build a web tier from parameterized task files, load platform variables at run time, choose a content profile by variable, reuse a verification play, and prove where imports and includes behave differently |

---

## Before You Begin

```bash
lab start scale_files
```

Start creates `~/scale_files` and removes httpd, web content, and the http and https firewall rules from servera and serverb. The project already contains the building blocks:

```bash
cd ~/scale_files
find tasks vars plays -type f | sort
head -n 3 tasks/*.yml tasks/profiles/*.yml
```

| File | Job | Parameters |
|---|---|---|
| `tasks/packages.yml` | Install packages | `pkgs` (list) |
| `tasks/service.yml` | Start and enable one service | `svc_name` |
| `tasks/firewall.yml` | Open firewalld services | `fw_services` (list) |
| `tasks/profiles/basic.yml`, `health.yml` | Alternative web content | none |
| `tasks/once.yml`, `tasks/broken.yml` | Demonstration files for Part B | none |
| `vars/RedHat.yml`, `vars/default.yml` | `web_pkg`, `web_svc` per platform | none |
| `plays/verify.yml` | Complete play: every web host answers | `verify_path` (optional) |

Open the project in the dev container or a workstation terminal.

---

## Part A: Build `site.yml`

### Step 1: Load platform variables at run time

Create `site.yml`:

```yaml
---
- name: Web tier assembled from task files
  hosts: web
  vars:
    web_profile: basic
  tasks:
    - name: Platform specific variables are loaded
      ansible.builtin.include_vars:
        file: "{{ lookup('ansible.builtin.first_found', platform_files) }}"
      vars:
        platform_files:
          files:
            - "{{ ansible_facts['distribution'] }}-{{ ansible_facts['distribution_major_version'] }}.yml"
            - "{{ ansible_facts['distribution'] }}.yml"
            - default.yml
          paths:
            - vars
```

On the lab hosts `RedHat-9.yml` (or `RedHat-10.yml`) does not exist, `RedHat.yml` does, so that file wins. `default.yml` is the safety net for any other platform.

### Step 2: Import a parameterized task file

Append:

```yaml
    - name: Packages are installed
      ansible.builtin.import_tasks: tasks/packages.yml
      vars:
        pkgs:
          - "{{ web_pkg }}"
          - firewalld
```

### Step 3: Loop over an included task file

Append:

```yaml
    - name: Services run and start at boot
      ansible.builtin.include_tasks: tasks/service.yml
      loop:
        - "{{ web_svc }}"
        - firewalld
      loop_control:
        loop_var: svc_name
```

`import_tasks` cannot loop; `include_tasks` can. `loop_var: svc_name` delivers each value under the name `tasks/service.yml` expects.

### Step 4: Import the firewall rules

Append:

```yaml
    - name: Firewall rules are in place
      ansible.builtin.import_tasks: tasks/firewall.yml
      vars:
        fw_services:
          - http
          - https
```

### Step 5: Include a profile chosen by variable

Append:

```yaml
    - name: Profile specific content is deployed
      ansible.builtin.include_tasks: "tasks/profiles/{{ web_profile }}.yml"
```

### Step 6: Reuse a whole play

Append at the **top level** (no indentation, beside the first play):

```yaml
- name: Web tier answers
  ansible.builtin.import_playbook: plays/verify.yml
```

---

## Part B: Observe the differences

### Step 7: What tooling sees

```bash
ansible-navigator run site.yml --syntax-check
ansible-navigator run site.yml --list-tasks
```

`--list-tasks` shows the imported tasks by their own names (`Required packages are installed`, `Firewall allows the services now and after reboot`) but only the **include statements** for the service loop and the profile. The verification play appears as play 2.

### Step 8: Run it

```bash
ansible-navigator run site.yml
```

Watch for `included: .../tasks/service.yml for servera.lab.example.com, serverb.lab.example.com => (item=httpd)` lines: each loop iteration loads the file anew. The imported tasks appear without any marker, exactly as if written in `site.yml`. The last play, running on `localhost`, gets HTTP 200 from both hosts.

```bash
ansible-navigator run site.yml                        # changed=0
ansible-navigator run site.yml -e web_profile=health  # only the profile tasks change
curl -s servera.lab.example.com/health.txt            # ok
```

The profile file name came from a variable at run time, which only an include allows. Try the same with `import_tasks` and a fact in the name to see the parse time error, then undo it.

### Step 9: When errors surface

Create `broken_import.yml` and `broken_include.yml`:

```yaml
# broken_import.yml
---
- name: Import a broken file
  hosts: servera.lab.example.com
  gather_facts: false
  tasks:
    - name: First task runs
      ansible.builtin.debug:
        msg: before

    - name: Broken file
      ansible.builtin.import_tasks: tasks/broken.yml
```

`broken_include.yml` is identical except that it uses `ansible.builtin.include_tasks`.

```bash
ansible-navigator run broken_import.yml --syntax-check
ansible-navigator run broken_include.yml --syntax-check
ansible-navigator run broken_include.yml
```

The import fails at syntax check with the YAML error in `tasks/broken.yml`. The include **passes** syntax check; the run prints `before` and fails only when it reaches the include. Imports catch mistakes early; includes defer them.

### Step 10: When conditions are evaluated

Create `conditions.yml`:

```yaml
---
- name: Imported file, condition copied to every task
  hosts: servera.lab.example.com
  become: false
  gather_facts: false
  tasks:
    - name: Import the two tasks
      ansible.builtin.import_tasks: tasks/once.yml
      when: setup_done is not defined

- name: Included file, condition checked once
  hosts: serverb.lab.example.com
  become: false
  gather_facts: false
  tasks:
    - name: Include the two tasks
      ansible.builtin.include_tasks: tasks/once.yml
      when: setup_done is not defined
```

```bash
ansible-navigator run conditions.yml
```

On servera (import) the second task is **skipped**: the first task defined `setup_done`, and the copied condition was checked again. On serverb (include) both tasks run: the condition was checked once, before the file was loaded.

Compare your files with `solutions/` and close the dev container.

---

## Finish

```bash
lab finish scale_files
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `You cannot use loops on 'import_tasks' statements` | Use `include_tasks` for the service loop |
| `'svc_name' is undefined` | `loop_control: loop_var: svc_name` missing |
| `No file was found when using first_found` | `paths: [vars]` missing, or run from outside the project |
| `import_playbook` rejected | It is indented inside the first play; move it to column 1 |

<!-- navfoot:start -->

---

← Previous: [Chapter 06: Automation at Scale](README.md) | Next: [Guided Exercise: Select Exactly the Right Hosts](02_guided_exercise_scale_hosts.md) →

<!-- navfoot:end -->
