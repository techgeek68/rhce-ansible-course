<!-- nav:start -->
[Course home](../README.md) › [Chapter 05: Deploying and Managing Files](README.md) › Lab solution (6 of 6)
<!-- nav:end -->

# Chapter 05 Lab Solution: `files_review`

---

## 1. `templates/node_profile.j2`

```jinja
# {{ ansible_managed }}
node = {{ ansible_facts['fqdn'] }}
address = {{ ansible_facts['default_ipv4']['address'] }}
os = {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}
memory_gib = {{ (ansible_facts['memtotal_mb'] / 1024) | round(1) }}
vcpus = {{ ansible_facts['processor_vcpus'] }}
maintenance = {{ maintenance_window | default('unscheduled') }}
{% for group in group_names | sort %}
role = {{ group }}
{% endfor %}
peers = {{ groups['all'] | difference([inventory_hostname]) | sort | join(',') }}
```

| Line | Technique |
|---|---|
| Header | `# ` plus `ansible_managed`, first line, comment character included |
| `memory_gib` | Division and `round(1)`; parentheses make the filter apply to the result |
| `maintenance` | `default('unscheduled')`: `group_vars/web.yml` defines it for web hosts only |
| `role` | `for` loop over `group_names \| sort`; `trim_blocks` keeps the loop tags from producing blank lines |
| `peers` | `groups['all'] \| difference([inventory_hostname]) \| sort \| join(',')` |

Preview it before touching the hosts:

```bash
ansible-navigator run profile.yml --check --diff --limit servera.lab.example.com
```

(With `--limit`, the peers line still works: it uses inventory names, not facts of other hosts.)

---

## 2. `profile.yml`

```yaml
---
- name: Node profile, login banners, and cache cleanup
  hosts: all
  become: true
  tasks:
    - name: Node profile is rendered from the template
      ansible.builtin.template:
        src: node_profile.j2
        dest: /etc/node-profile.conf
        owner: root
        group: root
        mode: "0644"

    - name: Login banner text is installed
      ansible.builtin.copy:
        src: files/issue
        dest: /etc/issue
        owner: root
        group: root
        mode: "0644"

    - name: Network login banner links to the local banner
      ansible.builtin.file:
        src: /etc/issue
        dest: /etc/issue.net
        state: link
        force: true

    - name: SSH shows the network banner before login
      ansible.builtin.lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?Banner'
        line: Banner /etc/issue.net
        validate: /usr/sbin/sshd -t -f %s
      notify: Reload sshd

    - name: Shell environment identifies the node
      ansible.builtin.blockinfile:
        path: /etc/profile.d/lab_env.sh
        create: true
        owner: root
        group: root
        mode: "0644"
        marker: "# {mark} LAB ENVIRONMENT"
        block: |
          export LAB_ROLE={{ group_names | first }}
          export LAB_NODE={{ inventory_hostname_short }}

    - name: Find cache files older than seven days
      ansible.builtin.find:
        paths: /var/tmp/labcache
        patterns: "*.tmp"
        age: 7d
      register: stale_cache

    - name: Stale cache files are removed
      ansible.builtin.file:
        path: "{{ item['path'] }}"
        state: absent
      loop: "{{ stale_cache['files'] }}"
      loop_control:
        label: "{{ item['path'] }}"

    - name: Profile is collected into the project
      ansible.builtin.fetch:
        src: /etc/node-profile.conf
        dest: "{{ playbook_dir }}/profiles/{{ inventory_hostname }}.conf"
        flat: true

  handlers:
    - name: Reload sshd
      ansible.builtin.systemd_service:
        name: sshd
        state: reloaded
```

| Requirement | Decision |
|---|---|
| Play level escalation | `become: true` on the play; the project default is off |
| `/etc/issue.net` becomes a link | `force: true`, because on RHEL the file exists as a regular file and `file` refuses to replace it otherwise |
| Single line SSH edit, validated | `lineinfile` with `regexp: '^#?Banner'` (matches the default `#Banner none` and the new line) and `validate: /usr/sbin/sshd -t -f %s` |
| Reload only on change | `notify` plus a handler |
| Environment block | `blockinfile` with `create: true` and the custom marker; `group_names \| first` and `inventory_hostname_short` |
| Old `.tmp` files | `find` with `age: 7d` (positive = older than) and a `file: state=absent` loop over `files` |
| Collect per host | `fetch` with `flat: true` and the host name in `dest`, under `playbook_dir` so it lands in the project with navigator too |

---

## 3. Run and verify

```bash
ansible-lint profile.yml
ansible-navigator run profile.yml
ansible all -m ansible.builtin.command -a 'cat /etc/node-profile.conf'
ansible all -m ansible.builtin.command -a 'ls /var/tmp/labcache'
ls profiles/
ssh devops@serverb.lab.example.com      # PRIVATE SYSTEM banner, then log out
lab grade files_review
lab finish files_review
```

A second run reports `changed` only for the `fetch` task if the local copies were removed; everything on the hosts stays `ok`.

## Time Check

Target: 25 minutes. Template 8, playbook 12, runs and checks 5.

<!-- navfoot:start -->

---

← Previous: [Chapter 05 Lab: Node Profiles, Login Banners, and Cleanup](04_lab.md) | Next: [Chapter 06: Automation at Scale](../06_scale/README.md) →

<!-- navfoot:end -->
