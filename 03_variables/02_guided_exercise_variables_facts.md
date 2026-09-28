<!-- nav:start -->
[Course home](../README.md) › [Chapter 03: Variables, Facts, and Secrets](README.md) › Guided exercise (3 of 7)
<!-- nav:end -->

# Guided Exercise: Drive Automation from Facts

| | |
|---|---|
| **Exercise name** | `variables_facts` |
| **Time** | 40 minutes |
| **Covers** | README section 2 |
| **You will** | Explore and filter facts, export them to files, create static and dynamic custom facts, let each host's facts decide what is deployed, and read data about other hosts through magic variables |

---

## Before You Begin

```bash
lab start variables_facts
```

Start creates `~/variables_facts` (inventory group `web` with servera and serverb) and removes vsftpd and any custom facts from both hosts.

Open the project in the dev container or a workstation terminal.

---

## Step 1: Explore facts ad hoc

```bash
ansible servera.lab.example.com -m ansible.builtin.setup | wc -l
ansible servera.lab.example.com -m ansible.builtin.setup -a 'filter=ansible_default_ipv4'
ansible web -m ansible.builtin.setup -a 'filter=ansible_*_mb'
ansible servera.lab.example.com -m ansible.builtin.setup -a 'gather_subset=!all,network' | wc -l
```

The full fact set runs to over a thousand lines; the network subset is a fraction of it. Note the `ansible_` prefix on every key in ad hoc output.

---

## Step 2: A one line report per host

Create `report.yml`:

```yaml
---
- name: Short hardware and network report
  hosts: web
  become: false
  tasks:
    - name: One line summary per host
      ansible.builtin.debug:
        msg: >-
          {{ ansible_facts['fqdn'] }} runs {{ ansible_facts['distribution'] }}
          {{ ansible_facts['distribution_version'] }} on {{ ansible_facts['processor_vcpus'] }} vCPU
          with {{ ansible_facts['memtotal_mb'] }} MiB RAM at
          {{ ansible_facts['default_ipv4']['address'] }}
```

```bash
ansible-navigator run report.yml
```

Each host prints one sentence with its own values, for example `servera.lab.example.com runs RedHat 9.x on 1 vCPU with 1780 MiB RAM at 192.168.250.10`. The `>-` block joins the lines with spaces.

---

## Step 3: See why the old fact names are discouraged

Add a second task to `report.yml`:

```yaml
    - name: Old style fact name
      ansible.builtin.debug:
        var: ansible_hostname
```

It works. Now add this line to the `[defaults]` section of `ansible.cfg` and run again:

```ini
inject_facts_as_vars = false
```

The old style task fails with `'ansible_hostname' is undefined`, while the first task keeps working. Remove the old style task and the configuration line.

---

## Step 4: Export facts to the project

Create `export_facts.yml`:

```yaml
---
- name: Facts are saved on the control side for later analysis
  hosts: web
  become: false
  tasks:
    - name: Facts directory exists in the project
      ansible.builtin.file:
        path: "{{ playbook_dir }}/facts"
        state: directory
        mode: "0755"
      delegate_to: localhost

    - name: One JSON file per host
      ansible.builtin.copy:
        content: "{{ ansible_facts | to_nice_json }}\n"
        dest: "{{ playbook_dir }}/facts/{{ inventory_hostname }}.json"
        mode: "0644"
      delegate_to: localhost
```

```bash
ansible-navigator run export_facts.yml
ls facts/
grep -m1 '"fqdn"' facts/serverb.lab.example.com.json
```

`become: false` matters here: the delegated tasks run on the control side, where there is no sudo rule for you. Run it twice: the copy task stays `changed`, because facts such as `uptime_seconds` change every time.

---

## Step 5: Install custom facts

Create `custom_facts.yml`:

```yaml
---
- name: Custom facts are installed on the web hosts
  hosts: web
  tasks:
    - name: Facts directory exists
      ansible.builtin.file:
        path: /etc/ansible/facts.d
        state: directory
        mode: "0755"

    - name: Static deployment facts
      ansible.builtin.copy:
        content: |
          [deploy]
          package = vsftpd
          service = vsftpd
          state = started
          enabled = true
        dest: /etc/ansible/facts.d/app.fact
        mode: "0644"

    - name: Dynamic runtime facts
      ansible.builtin.copy:
        content: |
          #!/bin/bash
          printf '{"boot_id": "%s", "logged_in_users": %s}\n' \
            "$(cat /proc/sys/kernel/random/boot_id)" "$(who | wc -l)"
        dest: /etc/ansible/facts.d/runtime.fact
        mode: "0755"
```

```bash
ansible-navigator run custom_facts.yml
ansible web -m ansible.builtin.setup -a 'filter=ansible_local'
```

`app` comes from the INI file; `runtime` is produced by running the script, so `logged_in_users` changes as people log in. Notice `"enabled": "true"` in quotes: INI values are strings.

---

## Step 6: Check the service before deployment

Create `check_service.yml`:

```yaml
---
- name: Service state as seen by service facts
  hosts: web
  become: false
  gather_facts: false
  tasks:
    - name: Collect service facts
      ansible.builtin.service_facts:

    - name: Show vsftpd when it exists
      ansible.builtin.debug:
        var: ansible_facts['services']['vsftpd.service']
      when: "'vsftpd.service' in ansible_facts['services']"
```

```bash
ansible-navigator run check_service.yml
```

The second task is `skipping` on both hosts: vsftpd does not exist yet. (`when` is the subject of the next chapter; here it only prevents an error.)

---

## Step 7: Let each host's facts decide

Create `deploy_from_facts.yml`:

```yaml
---
- name: Deployment is driven by each host's own facts
  hosts: web
  tasks:
    - name: Short name for the deployment facts
      ansible.builtin.set_fact:
        deploy: "{{ ansible_facts['ansible_local']['app']['deploy'] }}"

    - name: Package from the facts is installed
      ansible.builtin.dnf:
        name: "{{ deploy['package'] }}"
        state: present

    - name: Service from the facts is in the requested state
      ansible.builtin.systemd_service:
        name: "{{ deploy['service'] }}"
        state: "{{ deploy['state'] }}"
        enabled: "{{ deploy['enabled'] }}"
```

```bash
ansible-navigator run deploy_from_facts.yml
ansible-navigator run check_service.yml
```

Both hosts now report vsftpd `running` and `enabled`.

Change only serverb's fact, then deploy again:

```bash
ansible serverb.lab.example.com -m ansible.builtin.lineinfile \
  -a 'path=/etc/ansible/facts.d/app.fact regexp="^state" line="state = stopped"'
ansible serverb.lab.example.com -m ansible.builtin.lineinfile \
  -a 'path=/etc/ansible/facts.d/app.fact regexp="^enabled" line="enabled = false"'
ansible-navigator run deploy_from_facts.yml
ansible-navigator run check_service.yml
```

The same playbook stopped and disabled vsftpd on serverb only. The host carried its own configuration.

---

## Step 8: Read other hosts through magic variables

Create `peers.yml`:

```yaml
---
- name: Network facts are collected from every web host
  hosts: web
  become: false
  gather_facts: false
  tasks:
    - name: Gather only network facts
      ansible.builtin.setup:
        gather_subset:
          - "!all"
          - network

- name: Servera records what it knows about its peers
  hosts: servera.lab.example.com
  become: false
  gather_facts: false
  tasks:
    - name: Peer report is written from magic variables
      ansible.builtin.copy:
        content: |
          inventory name: {{ inventory_hostname }}
          my groups: {{ group_names | join(', ') }}
          web hosts: {{ groups['web'] | join(', ') }}
          serverb address: {{ hostvars['serverb.lab.example.com']['ansible_facts']['default_ipv4']['address'] }}
        dest: /tmp/peers.txt
        mode: "0644"
```

```bash
ansible-navigator run peers.yml
ansible servera.lab.example.com -m ansible.builtin.command -a 'cat /tmp/peers.txt'
```

```
inventory name: servera.lab.example.com
my groups: web
web hosts: servera.lab.example.com, serverb.lab.example.com
serverb address: 192.168.250.11
```

Now comment out the whole first play and run again: the second play fails because nobody gathered serverb's facts in this run. Restore the first play.

Close the dev container.

---

## Finish

```bash
lab finish variables_facts
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ansible_local` is empty | The file must end in `.fact` and sit in `/etc/ansible/facts.d/` |
| `runtime` fact missing, warning about the script | The script must be executable (mode 0755) and print valid JSON |
| Export fails with a sudo error | Add `become: false` to the export play |
| `hostvars[...]['ansible_facts']` has no attribute `default_ipv4` | The first play of `peers.yml` did not run or gathered too little |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Place Variables at the Right Scope](01_guided_exercise_variables_vars.md) | Next: [Guided Exercise: Protect Secrets with Ansible Vault](03_guided_exercise_variables_vault.md) →

<!-- navfoot:end -->
