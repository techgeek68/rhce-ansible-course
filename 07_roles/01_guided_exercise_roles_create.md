<!-- nav:start -->
[Course home](../README.md) › [Chapter 07: Roles and Content Collections](README.md) › Guided exercise (2 of 7)
<!-- nav:end -->

# Guided Exercise: Write a Reusable Role

| | |
|---|---|
| **Exercise name** | `roles_create` |
| **Time** | 45 minutes |
| **Covers** | README sections 1 and 2 |
| **You will** | Build a `vhost` role that creates one Apache virtual host per call, validate its input, call it twice with different parameters, and prove the precedence and ordering rules of roles |

---

## Before You Begin

```bash
lab start roles_create
```

Start creates `~/roles_create` and removes Apache and any earlier sites from servera. The project contains:

| File | Purpose |
|---|---|
| `ansible.cfg` | Includes `roles_path = ./roles` |
| `inventory` | Group `web` with servera |
| `vhost.conf.j2` | Template for the role (you will move it) |
| `argument_specs.yml` | Input specification for the role (you will move it) |
| `roles/announce/` | A tiny ready made role used in Part C |
| `solutions/` | The finished role and playbooks |

Open the project in the dev container or a workstation terminal.

---

## Part A: Build the role

### Step 1: Create the skeleton and remove what you do not need

```bash
ansible-galaxy role init roles/vhost
rm -rf roles/vhost/tests roles/vhost/files
find roles/vhost | sort
```

### Step 2: Defaults and internal variables

`roles/vhost/defaults/main.yml`: values callers may change.

```yaml
---
vhost_port: 80
vhost_title: Welcome
vhost_root: /var/www/sites
```

`roles/vhost/vars/main.yml`: values the role relies on.

```yaml
---
vhost_packages:
  - httpd
  - firewalld
```

`vhost_name` has no default on purpose: every call must name its site.

### Step 3: Template, specification, and handler

```bash
mv vhost.conf.j2 roles/vhost/templates/
mv argument_specs.yml roles/vhost/meta/
cat roles/vhost/templates/vhost.conf.j2
```

The template adds a `Listen` line only when the port is not 80, because Apache already listens on 80.

`roles/vhost/handlers/main.yml`:

```yaml
---
- name: Restart httpd
  ansible.builtin.systemd_service:
    name: httpd
    state: restarted
```

### Step 4: Tasks

`roles/vhost/tasks/main.yml`:

```yaml
---
- name: Web packages are installed
  ansible.builtin.dnf:
    name: "{{ vhost_packages }}"
    state: present

- name: Web and firewall services run and start at boot
  ansible.builtin.systemd_service:
    name: "{{ item }}"
    state: started
    enabled: true
  loop:
    - firewalld
    - httpd

- name: Document root exists for {{ vhost_name }}
  ansible.builtin.file:
    path: "{{ vhost_root }}/{{ vhost_name }}"
    state: directory
    mode: "0755"

- name: Home page exists for {{ vhost_name }}
  ansible.builtin.copy:
    content: "{{ vhost_title }}\n"
    dest: "{{ vhost_root }}/{{ vhost_name }}/index.html"
    mode: "0644"

- name: Virtual host configuration for {{ vhost_name }}
  ansible.builtin.template:
    src: vhost.conf.j2
    dest: /etc/httpd/conf.d/{{ vhost_name }}.conf
    owner: root
    group: root
    mode: "0644"
  notify: Restart httpd

- name: Firewall allows the site port {{ vhost_port }}
  ansible.posix.firewalld:
    port: "{{ vhost_port }}/tcp"
    permanent: true
    immediate: true
    state: enabled
```

`src: vhost.conf.j2` is found in the role's own `templates/`; `notify` finds the role's handler.

### Step 5: Metadata and README

Edit `roles/vhost/meta/main.yml`: set `author`, `description`, `company`, a `license` such as `MIT`, `min_ansible_version: "2.14"` (quoted), and `platforms` EL 9 and 10. Leave `dependencies: []`. Replace the generated `README.md` text with a short description and a variable table. Compare with `solutions/roles/vhost/`.

```bash
ansible-lint roles/vhost
ansible-doc -t role -r roles vhost
```

Lint passes. `ansible-doc` renders your argument specification as documentation.

---

## Part B: Use the role twice

### Step 6: Write `sites.yml`

```yaml
---
- name: Two virtual hosts from one role
  hosts: web
  tasks:
    - name: Main site
      ansible.builtin.include_role:
        name: vhost
      vars:
        vhost_name: main
        vhost_title: Main site on {{ inventory_hostname }}

    - name: Documentation site
      ansible.builtin.include_role:
        name: vhost
      vars:
        vhost_name: docs
        vhost_port: 8008
        vhost_title: Documentation site
```

Port 8008 is already labeled `http_port_t` in the SELinux policy, so Apache may bind to it without extra configuration.

```bash
ansible-navigator run sites.yml
curl -s servera.lab.example.com
curl -s servera.lab.example.com:8008
```

Output lines read `TASK [vhost : Virtual host configuration for docs]`: the role name prefixes every task. The handler runs once at the end although both calls notified it.

```bash
ansible-navigator run sites.yml     # changed=0
```

### Step 7: Let the specification catch a mistake

Change `vhost_port: 8008` to `vhost_port: eighty` and run. The role stops at `Validating arguments against arg spec 'main'` with a clear message, before touching the host. Remove `vhost_name` from the first call and run: `missing required arguments: vhost_name`. Restore both.

---

## Part C: Precedence and order

### Step 8: `vars/main.yml` beats the play

Add a play level variable to `sites.yml`, above `tasks:`:

```yaml
  vars:
    vhost_packages:
      - httpd
```

Run with `--check`: firewalld is still in the list the role installs. The role's `vars/main.yml` outranks play vars, which is exactly why only constants belong there. Remove the play `vars` block.

Now move `vhost_title: Welcome` temporarily from `defaults/main.yml` to `vars/main.yml` and run again with `--check --diff`: the explicit `vhost_title` values on the `include_role` tasks still win (task vars outrank role vars), but any play or inventory value would now be ignored. Move it back to `defaults/main.yml`.

### Step 9: Section order ignores file order

Create `order.yml`, deliberately written backwards:

```yaml
---
- name: Play section order
  hosts: web
  become: false
  gather_facts: false
  tasks:
    - name: Written first, runs third
      ansible.builtin.debug:
        msg: tasks section

  post_tasks:
    - name: Runs last
      ansible.builtin.debug:
        msg: post_tasks section

  roles:
    - role: announce
      announce_text: roles section, runs second

  pre_tasks:
    - name: Runs first
      ansible.builtin.debug:
        msg: pre_tasks section
```

```bash
ansible-navigator run order.yml | grep '"msg"'
```

```
"msg": "pre_tasks section"
"msg": "roles section, runs second"
"msg": "tasks section"
"msg": "post_tasks section"
```

Close the dev container.

---

## Finish

```bash
lab finish roles_create
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `the role 'vhost' was not found` | `roles_path = ./roles` missing, or the role directory is misnamed |
| `Could not find or access 'vhost.conf.j2'` | Template not in `roles/vhost/templates/` |
| Apache fails to restart after adding a port | The port is not labeled `http_port_t`; use 8008 here, or label the port with the selinux system role (lab) |
| Lint reports `var-naming[no-role-prefix]` | Every role variable must start with `vhost_` |

<!-- navfoot:start -->

---

← Previous: [Chapter 07: Roles and Content Collections](README.md) | Next: [Guided Exercise: Install Pinned Roles from an Archive and from Git](02_guided_exercise_roles_external.md) →

<!-- navfoot:end -->
