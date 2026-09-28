<!-- nav:start -->
[Course home](../README.md) › [Chapter 02: Developing Automation Content](README.md) › Lab solution (8 of 8)
<!-- nav:end -->

# Chapter 02 Lab Solution: `develop_review`

---

## 1. Inventory

```ini
[probes]
servera.lab.example.com

[web]
server[b:c].lab.example.com

[web:vars]
http_welcome="App tier ready"

[db]
serverd.lab.example.com

[app:children]
web
db
```

Verify before moving on:

```bash
ansible-inventory --graph
ansible-inventory --host serverb.lab.example.com      # {"http_welcome": "App tier ready"}
ansible-inventory --host serverd.lab.example.com      # {}
```

| Requirement | Construct |
|---|---|
| One range for serverb and serverc | `server[b:c].lab.example.com` |
| Group of groups | `[app:children]` |
| Variable for web only | `[web:vars]`; putting it under `[app:vars]` would give it to serverd too |

---

## 2. Logging

Add to `[defaults]` in `ansible.cfg`:

```ini
log_path = ./ansible.log
```

---

## 3. `database.yml`

```yaml
---
- name: Database tier is ready
  hosts: db
  become: true
  tasks:
    - name: Install database packages
      ansible.builtin.dnf:
        name:
          - firewalld
          - mariadb-server
        state: present

    - name: Firewalld enabled and running
      ansible.builtin.systemd_service:
        name: firewalld
        enabled: true
        state: started

    - name: Firewalld permits the mysql service
      ansible.posix.firewalld:
        service: mysql
        permanent: true
        state: enabled
        immediate: true

    - name: MariaDB enabled and running
      ansible.builtin.systemd_service:
        name: mariadb
        enabled: true
        state: started
```

| Fault | Found by | Fix |
|---|---|---|
| Play without a name | `ansible-lint` (`name[play]`) | Add `name:` |
| `become: yes` | `ansible-lint` (`yaml[truthy]`) | `true` |
| `dnf:` | `ansible-lint` (`fqcn[action-core]`) | `ansible.builtin.dnf:` |
| Task name starting lowercase | `ansible-lint` (`name[casing]`) | Capitalize |
| Trailing spaces after a task name | `ansible-lint` (`yaml[trailing-spaces]`) | Delete them |
| Service `mariadb-server` | Running the playbook: `Could not find the requested service mariadb-server` | The package is `mariadb-server`, the unit is `mariadb` |

The last fault is invisible to lint. Only a real run finds it, which is why the requirement says "passes lint **and** runs successfully".

```bash
ansible-lint database.yml
ansible-navigator run database.yml
```

---

## 4. `webserver.yml`

```yaml
---
- name: Web tier serves the application banner
  hosts: web
  become: true
  tasks:
    - name: Web packages are installed
      ansible.builtin.dnf:
        name:
          - httpd
          - firewalld
        state: present

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

    - name: Home page shows the welcome line
      ansible.builtin.copy:
        content: "{{ http_welcome }} on {{ inventory_hostname }}\n"
        dest: /var/www/html/index.html
        mode: "0644"

    - name: Httpd is running and starts at boot
      ansible.builtin.systemd_service:
        name: httpd
        state: started
        enabled: true

- name: Probe host confirms the web tier answers
  hosts: probes
  become: false
  tasks:
    - name: Serverb answers with HTTP 200
      ansible.builtin.uri:
        url: http://serverb.lab.example.com
        status_code: 200

    - name: Serverc answers with HTTP 200
      ansible.builtin.uri:
        url: http://serverc.lab.example.com
        status_code: 200
```

| Requirement wording | Decision |
|---|---|
| "without upgrading them" | `state: present`, not `latest` |
| "permanently and immediately" | `permanent: true` and `immediate: true` together |
| "exactly one line ... inventory host name" | `content:` with `inventory_hostname`, which is the name as written in the inventory, hence the FQDN; the trailing `\n` ends the line |
| "without privilege escalation" | `become: false` on Play 2; the project default is also false, but stating it makes the intent explicit and gradable |

Loops would shorten Play 2; they come in a later chapter.

```bash
ansible-navigator run webserver.yml --syntax-check
ansible-lint webserver.yml
ansible-navigator run webserver.yml
ansible-navigator run webserver.yml        # changed=0 everywhere
curl -s serverb.lab.example.com            # App tier ready on serverb.lab.example.com
grep -c 'PLAY RECAP' ansible.log
```

---

## 5. Grade

```bash
lab grade develop_review
lab finish develop_review
```

## Time Check

Target: 20 minutes. Inventory 4, logging 1, database repair 5, webserver 8, runs and checks 2. Repeat from `lab start` tomorrow if you needed more than 30.

<!-- navfoot:start -->

---

← Previous: [Chapter 02 Lab: Inventory, Repair, Build, and Verify](06_lab.md) | Next: [Chapter 03: Variables, Facts, and Secrets](../03_variables/README.md) →

<!-- navfoot:end -->
