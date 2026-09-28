<!-- nav:start -->
[Course home](../README.md) › [Chapter 04: Task Control](README.md) › Lab solution (7 of 7)
<!-- nav:end -->

# Chapter 04 Lab Solution: `control_review`

---

## The playbook

```yaml
---
- name: Central log server
  hosts: loghost
  vars_files:
    - vars/logging.yml
  tasks:
    - name: Log host meets the requirements
      ansible.builtin.assert:
        that:
          - ansible_facts['memtotal_mb'] >= log_min_ram_mb | int
          - ansible_facts['distribution'] == 'RedHat'
        fail_msg: "{{ inventory_hostname }} does not meet the log server requirements"
        success_msg: "{{ inventory_hostname }} meets the log server requirements"

    - name: Log server packages are installed
      ansible.builtin.dnf:
        name: "{{ log_server_pkgs }}"
        state: present

    - name: Log directories exist
      ansible.builtin.file:
        path: "{{ item }}"
        state: directory
        owner: root
        group: root
        mode: "0750"
      loop: "{{ log_dirs }}"

    - name: Log host receives remote messages
      ansible.builtin.copy:
        src: files/loghost.conf
        dest: /etc/rsyslog.d/loghost.conf
        owner: root
        group: root
        mode: "0644"
      notify: Restart rsyslog

    - name: Log services run and start at boot
      ansible.builtin.systemd_service:
        name: "{{ item }}"
        state: started
        enabled: true
      loop: "{{ log_services }}"

    - name: Firewall accepts syslog over TCP
      ansible.posix.firewalld:
        port: "{{ item }}"
        permanent: true
        immediate: true
        state: enabled
      loop: "{{ log_ports }}"

    - name: Pending handlers run now
      ansible.builtin.meta: flush_handlers

    - name: Log host accepts connections
      block:
        - name: Port 514 answers
          ansible.builtin.wait_for:
            port: 514
            timeout: 15

      rescue:
        - name: Schedule an rsyslog restart
          ansible.builtin.debug:
            msg: rsyslog is not listening on 514, restarting it
          changed_when: true
          notify: Restart rsyslog

  handlers:
    - name: Restart rsyslog
      ansible.builtin.systemd_service:
        name: rsyslog
        state: restarted

- name: Log clients
  hosts: clients
  vars_files:
    - vars/logging.yml
  tasks:
    - name: Messages are forwarded to the log host
      ansible.builtin.copy:
        src: files/forward.conf
        dest: /etc/rsyslog.d/forward.conf
        owner: root
        group: root
        mode: "0644"
      notify: Restart rsyslog

    - name: Monitoring tools on clients with enough memory
      ansible.builtin.dnf:
        name: sysstat
        state: present
      when: ansible_facts['memtotal_mb'] >= sysstat_min_ram_mb | int

    - name: Pending handlers run now
      ansible.builtin.meta: flush_handlers

    - name: Test message reaches the log host
      ansible.builtin.command: logger -t control_review "{{ inventory_hostname }} reporting"
      changed_when: false

  handlers:
    - name: Restart rsyslog
      ansible.builtin.systemd_service:
        name: rsyslog
        state: restarted
```

## Decisions, requirement by requirement

| Requirement | Solution | Why this form |
|---|---|---|
| Stop when memory or distribution is wrong | `assert` with two conditions and `fail_msg` | States the requirement positively; runs before anything changes |
| Works with `-e log_min_ram_mb=VALUE` | `log_min_ram_mb \| int` | Extra variables in `key=value` form are strings; without `int`, the comparison raises a type error instead of your message |
| Packages | `name: "{{ log_server_pkgs }}"` | One dnf transaction, no loop |
| Directories, services, ports | `loop` over the variables | These modules take one item per call |
| Restart only on configuration change | `notify: Restart rsyslog` on the copy tasks | Handlers run only after a `changed` result |
| Handlers before the check | `meta: flush_handlers` | The port check must see the new configuration |
| Recovery | `block` with `wait_for`, `rescue` with `changed_when: true` and `notify` | `debug` never reports changed by itself, so it could not notify without `changed_when` |
| sysstat by memory | `when:` with `sysstat_min_ram_mb \| int` | Same string safety as the assert |
| Test message without change | `changed_when: false` on `logger` | Sending a log line does not change the host's configuration |
| Handlers in both plays | Each play has its own `handlers:` | Handlers belong to a play; the name can repeat across plays |

The second play has its own `flush_handlers` so that each client restarts rsyslog with the forwarding rule **before** it sends the test message. Without it, the first run's test messages would go only to the local log.

## Verify

```bash
ansible-lint logging.yml
ansible-navigator run logging.yml
ansible-navigator run logging.yml                         # changed=0 everywhere
ansible loghost -m ansible.builtin.command -a 'ls -l /var/log/remote'
ansible loghost -m ansible.builtin.shell -a 'grep -h control_review /var/log/remote/*.log'
ansible-navigator run logging.yml -e log_min_ram_mb=999999   # stops on serverd with the message
lab grade control_review
lab finish control_review
```

The file names under `/var/log/remote/` use each client's short host name (`servera.log`), because rsyslog sends short names unless configured to preserve fully qualified names.

## Time Check

Target: 30 minutes. Play 1: 18, play 2: 7, runs and checks: 5.

<!-- navfoot:start -->

---

← Previous: [Chapter 04 Lab: Central Logging with Task Control](05_lab.md) | Next: [Chapter 05: Deploying and Managing Files](../05_deploying_files/README.md) →

<!-- navfoot:end -->
