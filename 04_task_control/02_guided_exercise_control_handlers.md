<!-- nav:start -->
[Course home](../README.md) › [Chapter 04: Task Control](README.md) › Guided exercise (3 of 7)
<!-- nav:end -->

# Guided Exercise: React to Changes with Handlers

| | |
|---|---|
| **Exercise name** | `control_handlers` |
| **Time** | 30 minutes |
| **Covers** | README section 3 |
| **You will** | Deploy a web server whose configuration changes trigger a checked reload, see handler order protect a running service from a broken file, and use `flush_handlers` to test the result inside the same play |

---

## Before You Begin

```bash
lab start control_handlers
```

Start creates `~/control_handlers` (inventory: `web` = servera; `files/status.conf`, `files/index.html`; `solutions/`) and removes httpd from servera.

`files/status.conf` enables Apache's status page at `/server-status`, reachable only from servera itself.

---

## Step 1: Write the play and its handlers

Create `webstatus.yml`:

```yaml
---
- name: Web server exposes a local status page
  hosts: web
  vars:
    web_pkgs:
      - httpd
      - firewalld
  tasks:
    - name: Web packages are installed
      ansible.builtin.dnf:
        name: "{{ web_pkgs }}"
        state: present
      notify: Restart httpd

    - name: Status page configuration is installed
      ansible.builtin.copy:
        src: files/status.conf
        dest: /etc/httpd/conf.d/status.conf
        owner: root
        group: root
        mode: "0644"
      notify: Web config changed

    - name: Home page is installed
      ansible.builtin.copy:
        src: files/index.html
        dest: /var/www/html/index.html
        mode: "0644"

    - name: Services run and start at boot
      ansible.builtin.systemd_service:
        name: "{{ item }}"
        state: started
        enabled: true
      loop:
        - httpd
        - firewalld

    - name: Firewall allows http now and after reboot
      ansible.posix.firewalld:
        service: http
        permanent: true
        immediate: true
        state: enabled

    - name: Pending handlers run now
      ansible.builtin.meta: flush_handlers

    - name: Status page answers locally
      ansible.builtin.uri:
        url: http://localhost/server-status?auto
        return_content: true
      register: status_page

    - name: Show the worker summary
      ansible.builtin.debug:
        msg: "{{ status_page['content'] | regex_search('BusyWorkers: [0-9]+') }}"

  handlers:
    - name: Check httpd configuration
      ansible.builtin.command: apachectl configtest
      changed_when: false
      listen: Web config changed

    - name: Reload httpd
      ansible.builtin.systemd_service:
        name: httpd
        state: reloaded
      listen: Web config changed

    - name: Restart httpd
      ansible.builtin.systemd_service:
        name: httpd
        state: restarted
```

Design decisions:

| Choice | Reason |
|---|---|
| Package change notifies `Restart httpd` | New binaries and modules need a full restart |
| Configuration change notifies the topic `Web config changed` | A reload is enough, but only after the configuration is checked |
| The home page notifies nothing | Content changes need no reload |
| `flush_handlers` before the `uri` task | The status page exists only after httpd has reread its configuration |
| Check handler listed before Reload handler | Handlers run in section order, so a broken file never reaches the running server |

`uri` runs on servera itself here, so `localhost` is servera and passes `Require local`.

---

## Step 2: First run

```bash
ansible-lint webstatus.yml
ansible-navigator run webstatus.yml
```

Read the order in the output:

```
TASK [Firewall allows http now and after reboot]
RUNNING HANDLER [Check httpd configuration]
RUNNING HANDLER [Reload httpd]
RUNNING HANDLER [Restart httpd]
TASK [Status page answers locally]
TASK [Show the worker summary]
```

Handlers ran at the flush point, in section order, not in the order the tasks notified them. The last task prints a line such as `BusyWorkers: 1`.

---

## Step 3: No change, no handler

```bash
ansible-navigator run webstatus.yml
```

No `RUNNING HANDLER` lines, `changed=0`.

---

## Step 4: Content change, still no handler

Edit `files/index.html` (change the heading text) and run again. The home page task reports `changed`; no handler runs, and the new page is served immediately:

```bash
curl -s servera.lab.example.com
```

---

## Step 5: Configuration change, checked reload

Add a line at the top of `files/status.conf`:

```apache
ExtendedStatus On
```

```bash
ansible-navigator run webstatus.yml
```

Only `Check httpd configuration` and `Reload httpd` run. `Restart httpd` stays silent because the package task was `ok`.

---

## Step 6: Broken configuration, protected service

Introduce a typo in `files/status.conf`: change `SetHandler` to `SetHandlr`.

```bash
ansible-navigator run webstatus.yml
curl -s -o /dev/null -w '%{http_code}\n' servera.lab.example.com
```

The copy task changes the file, the check handler fails with Apache's syntax error, the reload never runs, and the play fails for servera. `curl` still returns `200`: httpd keeps running with the last configuration it accepted.

Now look at the lost notification trap. Rerun without fixing anything:

```bash
ansible-navigator run webstatus.yml
```

The copy task is now `ok` (the broken file is already in place), nothing notifies the topic, and the play **succeeds**, with a broken file on disk that will stop httpd at its next restart. Fix the typo and run once more: the copy task changes the file back, the check passes, the reload runs.

The lesson: after a failed handler, never trust a green rerun without looking at what was changed.

---

## Step 7: Watch the flush point matter

Comment out the `flush_handlers` task and change `files/status.conf` again (for example, remove `ExtendedStatus On`). Run the playbook. The `uri` task now runs **before** the reload, against the old configuration. Here it still succeeds because the status page existed already; on a first deployment it would have failed with 404. Restore the `flush_handlers` task.

Close the dev container.

---

## Finish

```bash
lab finish control_handlers
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `The requested handler 'Web config changed' was not found` | `listen:` missing or misspelled on the handlers |
| Handlers run in an unexpected order | Their order in `handlers:` decides, not the `notify` order |
| `uri` fails with 403 | The request did not come from servera; keep `url: http://localhost/...` |
| `uri` fails with 404 on the first run | `flush_handlers` missing or placed after the `uri` task |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Apply a Baseline with Loops and Conditions](01_guided_exercise_control_flow.md) | Next: [Guided Exercise: Decide What Failure Means](03_guided_exercise_control_errors.md) →

<!-- navfoot:end -->
