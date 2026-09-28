<!-- nav:start -->
[Course home](../README.md) › [Chapter 06: Automation at Scale](README.md) › Lab solution (6 of 6)
<!-- nav:end -->

# Chapter 06 Lab Solution: `scale_review`

---

## 1. Choose the pattern

```bash
ansible '*.lab.example.com' --list-hosts      # 5 hosts: utility matches too
ansible 'server*' --list-hosts                # 5 hosts: server9.old.example.com matches too
ansible 'server*.lab.example.com' --list-hosts  # exactly the 4 application servers
```

`app_*` (a wildcard over the group names `app_east` and `app_west`) also meets the requirement. Either way, prove the selection with `--list-hosts` before running anything.

## 2. and 3. The files

`site.yml`:

```yaml
---
- name: Web service on the application servers
  hosts: server*.lab.example.com
  become: true
  tasks:
    - name: Web tasks
      ansible.builtin.import_tasks: tasks/web_tasks.yml

    - name: Firewall tasks
      ansible.builtin.import_tasks: tasks/firewall_tasks.yml

- name: Verify the status pages
  ansible.builtin.import_playbook: plays/check.yml
```

`tasks/install_and_enable.yml`:

```yaml
---
# Parameters: package, service
- name: Package is installed {{ package }}
  ansible.builtin.dnf:
    name: "{{ package }}"
    state: present

- name: Service runs and starts at boot {{ service }}
  ansible.builtin.systemd_service:
    name: "{{ service }}"
    state: started
    enabled: true
```

`tasks/web_tasks.yml`:

```yaml
---
- name: Web server is installed and enabled
  ansible.builtin.import_tasks: install_and_enable.yml
  vars:
    package: httpd
    service: httpd

- name: Status directory exists
  ansible.builtin.file:
    path: /var/www/html/status
    state: directory
    mode: "0755"

- name: Status page is published
  ansible.builtin.copy:
    content: "{{ inventory_hostname }} is serving\n"
    dest: /var/www/html/status/index.html
    mode: "0644"
```

`tasks/firewall_tasks.yml`:

```yaml
---
- name: Firewall is installed and enabled
  ansible.builtin.import_tasks: install_and_enable.yml
  vars:
    package: firewalld
    service: firewalld

- name: Open http and https
  ansible.posix.firewalld:
    service: "{{ item }}"
    permanent: true
    immediate: true
    state: enabled
  loop:
    - http
    - https
```

| Decision | Reason |
|---|---|
| Imports, not includes | Nothing depends on run time data; imports fail early, and `--list-tasks` still shows every task |
| `import_tasks: install_and_enable.yml` without `tasks/` | Paths are resolved relative to the importing file first, and both files live in `tasks/` |
| Parameter names documented at the top of the shared file | Callers see what to pass without reading the tasks |
| Templates at the end of task names | Lint accepts it, and `--list-tasks` output stays readable |
| `become: true` stays on the play | Imported tasks inherit play keywords |

## 4. Verify

```bash
ansible-lint site.yml
ansible-navigator run site.yml --list-tasks     # same seven tasks as before, plus the check play
ansible-navigator run site.yml
ansible-navigator run site.yml                  # changed=0
lab grade scale_review
lab finish scale_review
```

The task list after refactoring contains the same seven operations as the original playbook, now in four files. That comparison is the fastest proof that a refactor changed structure but not behavior.

## Time Check

Target: 20 minutes. Pattern 3, split 7, shared file 6, runs 4.

<!-- navfoot:start -->

---

← Previous: [Chapter 06 Lab: Refactor an Inherited Playbook](04_lab.md) | Next: [Chapter 07: Roles and Content Collections](../07_roles/README.md) →

<!-- navfoot:end -->
