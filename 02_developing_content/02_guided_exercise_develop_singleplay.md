<!-- nav:start -->
[Course home](../README.md) › [Chapter 02: Developing Automation Content](README.md) › Guided exercise (3 of 8)
<!-- nav:end -->

# Guided Exercise: Write, Check, Run, and Replay a Single Play

| | |
|---|---|
| **Exercise name** | `develop_singleplay` |
| **Time** | 35 minutes |
| **Covers** | README section 2 |
| **You will** | Build a playbook task by task from module documentation, validate it three ways before running it, run it twice to prove idempotency, replay an artifact, and preview a content change with diff mode |

---

## Before You Begin

```bash
lab start develop_singleplay
```

Start creates `~/develop_singleplay` and removes httpd, the web page, and the http firewall rule from servera and serverb, so both hosts begin clean.

Open the project in the dev container (or use a workstation terminal in `~/develop_singleplay`).

---

## Step 1: Review what you were given

```bash
cat ansible.cfg ansible-navigator.yml inventory files/index.html
```

| File | What to notice |
|---|---|
| `ansible.cfg` | `become = true` for every play; `collections_path` includes `./collections` |
| `ansible-navigator.yml` | Artifacts are **enabled** in this project so you can practice replay |
| `inventory` | Group `web` with servera and serverb |
| `files/index.html` | The page to publish; `copy` looks for relative `src` paths in `files/` |

```bash
ls collections/ansible_collections/ansible/
```

`posix` is present: `lab start` installed `ansible.posix` from materials.example.com, so `ansible.posix.firewalld` works in any execution environment and with plain `ansible-playbook`.

---

## Step 2: Get argument skeletons from the documentation

```bash
ansible-navigator doc -s ansible.builtin.dnf -m stdout | head -30
ansible-navigator doc -s ansible.posix.firewalld -m stdout | grep -E '^\s+(service|permanent|immediate|state):'
```

The `-s` output lists every argument with a comment. This is how you write tasks on the exam without memorizing every option.

---

## Step 3: Write the play

Create `site.yml`. Build it in this order and save after each task:

```yaml
---
- name: Status page is published on the web tier
  hosts: web
  tasks:
    - name: Httpd package is installed
      ansible.builtin.dnf:
        name: httpd
        state: present

    - name: Status page is in the document root
      ansible.builtin.copy:
        src: files/index.html
        dest: /var/www/html/index.html
        owner: root
        group: root
        mode: "0644"

    - name: Httpd is running and starts at boot
      ansible.builtin.systemd_service:
        name: httpd
        state: started
        enabled: true

    - name: Firewall allows http now and after reboot
      ansible.posix.firewalld:
        service: http
        permanent: true
        immediate: true
        state: enabled
```

Why each task is written this way:

| Task | Decision |
|---|---|
| dnf | `state: present` installs once and never upgrades; `latest` would upgrade on every run when updates exist |
| copy | Owner, group, and mode are stated, so a manual `chmod` on the host is repaired on the next run |
| systemd_service | `started` and `enabled` are two separate properties: running now, and running after reboot |
| firewalld | `permanent` survives reboot, `immediate` applies now; you need both |

No `become:` in the play: `ansible.cfg` already enables it.

---

## Step 4: Validate before running

```bash
ansible-navigator run site.yml --syntax-check
ansible-lint site.yml
ansible-navigator run site.yml --list-hosts
ansible-navigator run site.yml --list-tasks
```

| Command | Expected |
|---|---|
| `--syntax-check` | `playbook: /workspaces/develop_singleplay/site.yml` (or your workstation path) |
| `ansible-lint` | `Passed` with 0 failures |
| `--list-hosts` | The two web hosts |
| `--list-tasks` | Your four task names in order |

---

## Step 5: Dry run and see the limits of check mode

```bash
ansible-navigator run site.yml --check
```

The package and file tasks report `changed`: they would change. The service task is likely to **fail** with a message that the httpd service cannot be found, because in check mode the package was never really installed. This is the limitation from README section 2.5: check mode predicts each task in isolation. Nothing on the hosts changed.

---

## Step 6: Run for real, then run again

```bash
ansible-navigator run site.yml
```

Expected recap: `ok=5 changed=4` for each host (Gathering Facts plus four tasks).

```bash
ansible-navigator run site.yml
```

Expected recap: `ok=5 changed=0`. The play is idempotent.

Verify from outside Ansible:

```bash
curl -s servera.lab.example.com
curl -s serverb.lab.example.com
```

Both print the status page.

---

## Step 7: Replay an artifact

```bash
ls -1t site-artifact-*.json
ansible-navigator replay "$(ls -1t site-artifact-*.json | head -n1)" -m stdout
```

Every `ansible-navigator run` so far wrote one artifact, including the syntax check and list runs. `ls -1t` sorts newest first, so this replays the second real run from Step 6, exactly as it appeared. Replay without `-m stdout` to browse it interactively: pick the play, then a task, then a host, to see the full JSON result that the screen output summarized. Press `Esc` to go back and `:q` to quit.

Remove the artifacts when you are done; they are listed in `.gitignore` so they never reach Git:

```bash
rm -f site-artifact-*.json
```

---

## Step 8: Preview a content change with diff mode

Edit `files/index.html` and change the second line to:

```html
<p>Deployed by Ansible from workstation. Maintenance window: Saturday.</p>
```

```bash
ansible-navigator run site.yml --check --diff
```

Diff mode prints the old and new line for each host, and only the copy task reports `changed`. Apply it:

```bash
ansible-navigator run site.yml
curl -s servera.lab.example.com
```

---

## Step 9: Read the extra detail that verbosity adds

```bash
ansible-navigator run site.yml -v | grep -A3 'Status page'
ansible-navigator run site.yml -vvv | grep -m3 'ESTABLISH SSH CONNECTION'
```

`-v` shows each task's result dictionary; `-vvv` shows the SSH connection as `devops` to each host.

Close the dev container.

---

## Finish

```bash
lab finish develop_singleplay
```

Finish removes httpd, the page, and the firewall rule from both hosts.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `couldn't resolve module/action 'ansible.posix.firewalld'` | `collections/` missing; run `lab start develop_singleplay` again |
| `Could not find or access 'files/index.html'` | Run the command from the project root |
| Second run still shows `changed` for copy | Someone edited the page on the host, or `mode` is unquoted and interpreted differently; quote `"0644"` |
| `curl` hangs | The firewall task did not run with `immediate: true` |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Build and Query a Static Inventory](01_guided_exercise_develop_inventory.md) | Next: [Guided Exercise: Orchestrate Several Plays](03_guided_exercise_develop_multiplay.md) →

<!-- navfoot:end -->
