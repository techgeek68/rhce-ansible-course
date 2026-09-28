<!-- nav:start -->
[Course home](../README.md) › [Chapter 07: Roles and Content Collections](README.md) › Lab solution (7 of 7)
<!-- nav:end -->

# Chapter 07 Lab Solution: `roles_review`

---

## 1. Collection

```bash
cd ~/roles_review
curl -s http://materials.example.com/collections/ | grep -o 'community-general-[0-9.]*\.tar\.gz' | sort -u
```

`collections/requirements.yml` (with the version you found):

```yaml
---
collections:
  - name: http://materials.example.com/collections/community-general-X.Y.Z.tar.gz
```

```bash
ansible-galaxy collection install -r collections/requirements.yml -p collections
ansible-galaxy collection list community.general
```

## 2. Role from Git

Add to `[defaults]` in `ansible.cfg`:

```ini
roles_path = ./roles
```

`roles/requirements.yml`:

```yaml
---
- name: infra.httpd
  src: http://utility.lab.example.com:3000/student/infra.httpd.git
  scm: git
  version: v1.0.0
```

```bash
ansible-galaxy role install -r roles/requirements.yml
ansible-galaxy role list
cat roles/infra.httpd/README.md
```

The README tells you the role provides the handler `Restart httpd`, which the provided tasks notify.

## 3. Your role

```bash
ansible-galaxy role init roles/team.sites
rm -rf roles/team.sites/tests roles/team.sites/files roles/team.sites/vars roles/team.sites/defaults roles/team.sites/handlers
mv site_tasks.yml roles/team.sites/tasks/main.yml
mv site.conf.j2 roles/team.sites/templates/
```

`roles/team.sites/meta/main.yml`:

```yaml
---
galaxy_info:
  author: Student User
  description: Team development sites on their own ports
  license: MIT
  min_ansible_version: "2.14"
  platforms:
    - name: EL
      versions:
        - "9"
        - "10"

dependencies:
  - name: infra.httpd
    src: http://utility.lab.example.com:3000/student/infra.httpd.git
    scm: git
    version: v1.0.0
```

The dependency uses the requirements format, so `ansible-galaxy` could install it; at run time Ansible uses `name`. `handlers/` was removed because the role relies on the dependency's handler.

## 4. Variables

```bash
mkdir -p group_vars/portal
mv sites.yml selinux.yml group_vars/portal/
ansible-inventory --host serverb.lab.example.com | head -20
```

## 5. and 6. Playbook, first without SELinux

```yaml
---
- name: Configure the team portal
  hosts: portal
  become: true
  force_handlers: true
  tasks:
    - name: Team sites are deployed
      ansible.builtin.include_role:
        name: team.sites
```

```bash
ansible-navigator run portal.yml
```

`infra.httpd` runs first (dependency), then the team tasks, then `RUNNING HANDLER [infra.httpd : Restart httpd]` **fails**: Apache cannot bind to ports 8181 and 8182, because SELinux does not label them `http_port_t`. `journalctl -u httpd` on serverb shows `Permission denied: AH00072: make_sock: could not bind`.

Final `portal.yml`:

```yaml
---
- name: Configure the team portal
  hosts: portal
  become: true
  force_handlers: true
  tasks:
    - name: SELinux allows the team ports and content
      ansible.builtin.include_role:
        name: redhat.rhel_system_roles.selinux

    - name: Team sites are deployed
      ansible.builtin.include_role:
        name: team.sites

    - name: Portal inventory is recorded
      community.general.ini_file:
        path: /etc/portal.ini
        section: portal
        option: teams
        value: "{{ team_sites | map(attribute='name') | join(',') }}"
        mode: "0644"
```

```bash
ansible-navigator run portal.yml
curl -s serverb.lab.example.com
curl -s serverb.lab.example.com:8181
curl -s serverb.lab.example.com:8182
ansible portal -m ansible.builtin.command -a 'cat /etc/portal.ini'
lab grade roles_review
lab finish roles_review
```

| Decision | Reason |
|---|---|
| SELinux role first | Ports and file contexts must be labeled before Apache restarts on them |
| `force_handlers: true` | A later failure (for example in the ini task) must not lose the restart that applies the virtual hosts |
| Variables in `group_vars/portal/` | Both roles read them automatically for every portal host |
| `map(attribute='name') \| join(',')` | Builds `alpha,bravo` from the list of dictionaries |

Why the second run recovers although the configuration file no longer changes: the first run's failed restart left httpd **stopped**. On the second run the team tasks report `ok`, so nothing notifies the handler; but `infra.httpd`'s task `Httpd runs and starts at boot` sees the stopped service and starts it, now with the ports labeled. If the dependency had not enforced `state: started`, the fix would have stayed unapplied: the lost notification trap from Chapter 4. Roles that manage services should always assert the running state, not rely only on handlers.

## Time Check

Target: 35 minutes. Requirements and installs 10, role 10, variables and playbook 10, debugging the SELinux failure 5.

<!-- navfoot:start -->

---

← Previous: [Chapter 07 Lab: Team Development Portal from Roles and Collections](05_lab.md) | Next: [Chapter 08: Automating Linux Administration](../08_linux_admin/README.md) →

<!-- navfoot:end -->
