<!-- nav:start -->
[Course home](../README.md) › [Chapter 05: Deploying and Managing Files](README.md) › Guided exercise (3 of 6)
<!-- nav:end -->

# Guided Exercise: Render Host Specific Files with Jinja2

| | |
|---|---|
| **Exercise name** | `files_templates` |
| **Time** | 40 minutes |
| **Covers** | README section 2 |
| **You will** | Write three templates: a login banner driven by facts and group membership, a peer list built from every host's facts, and an application configuration shaped by filters; then publish data as YAML and parse command output as JSON |

---

## Before You Begin

```bash
lab start files_templates
```

Start creates `~/files_templates` with an inventory (`web` = servera, serverb; `db` = serverc, serverd), an `ansible.cfg` that already contains:

```ini
ansible_managed = Managed by Ansible from the files_templates project
```

an empty `templates/` directory, and `solutions/`. It empties `/etc/motd` and removes `/etc/lab` on all four hosts.

Open the project in the dev container or a workstation terminal.

---

## Step 1: The login banner template

Create `templates/motd.j2`:

```jinja
{# Login banner. Rendered separately for every host. #}
==== {{ ansible_managed }} ====
Host:    {{ ansible_facts['fqdn'] }}
System:  {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}
Size:    {{ (ansible_facts['memtotal_mb'] / 1024) | round(1) }} GiB RAM, {{ ansible_facts['processor_vcpus'] }} vCPU
{% if 'web' in group_names %}
Role:    web server. Report issues to {{ support['web'] }}
{% elif 'db' in group_names %}
Role:    database server. Report issues to {{ support['db'] }}
{% else %}
Role:    unassigned
{% endif %}
Addresses:
{% for addr in ansible_facts['all_ipv4_addresses'] | sort %}
  {{ loop.index }}. {{ addr }}
{% endfor %}
```

The first line is a Jinja2 comment: it never appears in the output, and because the module enables `trim_blocks`, it leaves no blank line either.

---

## Step 2: The playbook

Create `site_files.yml`:

```yaml
---
- name: Host specific files from templates
  hosts: all
  vars:
    support:
      web: web-team@lab.example.com
      db: dba-team@lab.example.com
  tasks:
    - name: Login banner describes the host
      ansible.builtin.template:
        src: motd.j2
        dest: /etc/motd
        owner: root
        group: root
        mode: "0644"
```

```bash
ansible-navigator run site_files.yml
ansible all -m ansible.builtin.command -a 'cat /etc/motd'
```

Each host shows its own banner (and prints it at the next interactive SSH login): servera names the web team, serverc the database team, and each lists its own addresses.

---

## Step 3: Preview a change before applying it

Change the `Size:` line in the template to also show free memory:

```jinja
Size:    {{ (ansible_facts['memtotal_mb'] / 1024) | round(1) }} GiB RAM ({{ ansible_facts['memfree_mb'] }} MiB free), {{ ansible_facts['processor_vcpus'] }} vCPU
```

```bash
ansible-navigator run site_files.yml --check --diff
```

The diff shows the old and new line for every host, and nothing changes. Then realize that free memory differs every run, so this banner would never be idempotent. Undo the edit; a file managed by Ansible should contain values that are stable between runs.

---

## Step 4: A peer list from every host's facts

Create `templates/peers.j2`:

```jinja
# {{ ansible_managed }}
# Every lab host with its address, as known to Ansible
{% for host in groups['all'] | sort %}
{{ hostvars[host]['ansible_facts']['default_ipv4']['address'] }} {{ host }}{{ '  # this host' if host == inventory_hostname else '' }}
{% endfor %}
```

Append to the tasks:

```yaml
    - name: Configuration directory exists
      ansible.builtin.file:
        path: /etc/lab
        state: directory
        mode: "0755"

    - name: Peer list names every lab host
      ansible.builtin.template:
        src: peers.j2
        dest: /etc/lab/peers.conf
        mode: "0644"
```

```bash
ansible-navigator run site_files.yml
ansible serverb.lab.example.com -m ansible.builtin.command -a 'cat /etc/lab/peers.conf'
```

Four lines with the lab addresses from 192.168.250.10 to .13; the serverb line carries `# this host`. It works because the play targets `all`, so every host's facts were gathered before any template was rendered.

Run once with `--limit servera.lab.example.com` and watch it fail: in that run, only servera's facts exist.

---

## Step 5: Filters in an application configuration

Create `templates/app.ini.j2`:

```jinja
# {{ ansible_managed }}
[service]
name = {{ app_name | lower }}
listen_port = {{ app_port | default(8080) }}
debug = {{ app_debug | default(false) | bool | ternary('on', 'off') }}
admins = {{ app_admins | join(',') }}

[limits]
{% for key, value in app_limits | dictsort %}
{{ key }} = {{ value }}
{% endfor %}
```

Add to the play's `vars`:

```yaml
    app_name: ReportService
    app_admins:
      - ana
      - raj
    app_limits:
      timeout: 30
      max_clients: 50
```

and to the tasks:

```yaml
    - name: Application settings are rendered with filters
      ansible.builtin.template:
        src: app.ini.j2
        dest: /etc/lab/app.ini
        mode: "0644"
```

```bash
ansible-navigator run site_files.yml
ansible servera.lab.example.com -m ansible.builtin.command -a 'cat /etc/lab/app.ini'
```

| Line | Filter at work |
|---|---|
| `name = reportservice` | `lower` |
| `listen_port = 8080` | `default`, because `app_port` is not defined |
| `debug = off` | `default(false)`, `bool`, `ternary` |
| `admins = ana,raj` | `join` |
| `max_clients` before `timeout` | `dictsort` orders keys alphabetically, so the file is stable between runs |

Override two values for one run and watch the file change:

```bash
ansible-navigator run site_files.yml -e app_port=9090 -e app_debug=yes --check --diff
```

`app_debug=yes` arrives as the string `yes`; `bool` converts it to true.

---

## Step 6: Data formats in both directions

Append a task that publishes the settings as YAML:

```yaml
    - name: Settings are also published as YAML
      ansible.builtin.copy:
        content: "{{ {'name': app_name, 'admins': app_admins, 'limits': app_limits} | to_nice_yaml }}"
        dest: /etc/lab/app_settings.yml
        mode: "0644"
```

And a second play that reads JSON produced by a command:

```yaml
- name: Parse command output with from_json
  hosts: serverc.lab.example.com
  become: false
  gather_facts: false
  tasks:
    - name: List whole disks as JSON
      ansible.builtin.command: lsblk -J -d -o NAME,SIZE,TYPE
      register: lsblk_out
      changed_when: false

    - name: Show disk names and sizes
      ansible.builtin.debug:
        msg: "{{ item['name'] }} is {{ item['size'] }}"
      loop: "{{ (lsblk_out['stdout'] | from_json)['blockdevices'] | selectattr('type', 'equalto', 'disk') | list }}"
      loop_control:
        label: "{{ item['name'] }}"
```

```bash
ansible-navigator run site_files.yml
ansible serverc.lab.example.com -m ansible.builtin.command -a 'cat /etc/lab/app_settings.yml'
```

The YAML file mirrors the variables; the debug task prints serverc's system disk and its spare 5 GiB disk, with the kernel names your hypervisor uses (`vda`/`vdb`, `sda`/`sdb`, or `nvme0n1`/`nvme0n2`).

---

## Step 7: Idempotency

```bash
ansible-navigator run site_files.yml
```

`changed=0` on every host. Compare your templates with `solutions/templates/` and close the dev container.

---

## Finish

```bash
lab finish files_templates
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Could not find or access 'motd.j2'` | The file must be in `templates/` next to the playbook |
| Blank lines in `app.ini` | A tag has trailing spaces after `%}`; `trim_blocks` removes only the newline directly after the tag |
| `'dict object' has no attribute 'ansible_facts'` in `peers.j2` | The run was limited; facts were not gathered for every host |
| `Unexpected end of template` | Missing `{% endif %}` or `{% endfor %}` |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Manage Files, Lines, Blocks, and Links](01_guided_exercise_files_manage.md) | Next: [Chapter 05 Quiz: Files and Templates](03_quiz.md) →

<!-- navfoot:end -->
