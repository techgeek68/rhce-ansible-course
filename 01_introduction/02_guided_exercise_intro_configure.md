<!-- nav:start -->
[Course home](../README.md) › [Chapter 01: Introduction to Ansible](README.md) › Guided exercise (3 of 6)
<!-- nav:end -->

# Guided Exercise: Configure Ansible and Automation Content Navigator

| | |
|---|---|
| **Exercise name** | `intro_configure` |
| **Time** | 40 minutes |
| **Covers** | README section 3 |
| **You will** | Write `ansible-navigator.yml` and `ansible.cfg` for a project, watch each setting change the outcome of a run, inspect effective configuration, and prove the precedence rules with experiments |

This exercise deliberately runs a playbook **before** the configuration is complete, so you see the real error messages you will later recognize under exam pressure.

---

## Before You Begin

```bash
lab start intro_configure
```

This creates `~/intro_configure` with an inventory, three playbooks, a dev container definition, workspace settings, and a `solutions/` directory. There is no `ansible.cfg` and no `ansible-navigator.yml` yet: writing them is your job.

---

## Step 1: Inspect the starting point

On workstation:

```bash
cd ~/intro_configure
find . -path ./solutions -prune -o -type f -print | sort
cat inventory
ansible --version | grep 'config file'
```

Expected:

```
./.devcontainer/podman/devcontainer.json
./.vscode/settings.json
./inventory
./ping_db.yml
./ping_web.yml
./whoami.yml
```

The inventory defines two groups: `web` (servera, serverb) and `db` (serverc, serverd). `config file` shows `/etc/ansible/ansible.cfg` or `None`: this project has no configuration of its own yet.

Read `whoami.yml`. It asks every host which account runs the tasks and prints the answer. You will use it as a probe for `remote_user` and `become`.

---

## Step 2: Open the project in the dev container

1. In VS Code: **File, Open Folder**, choose `/home/student/intro_configure`, click **Select**. Trust the authors if asked.
2. Click **Reopen in Container**, choose **ansible-dev-container-podman**.
3. Confirm `Dev Container: ansible-dev-container-podman` in the lower left, then open **Terminal, New Terminal**.

Steps 3 to 9 run in this container terminal (prompt path `/workspaces/intro_configure`). If you prefer, the same commands work in a workstation terminal in `~/intro_configure`, because the tools are installed there too.

---

## Step 3: Write `ansible-navigator.yml`

Create `ansible-navigator.yml` in the project root:

```yaml
---
ansible-navigator:
  execution-environment:
    container-engine: podman
    enabled: true
    image: utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest
    pull:
      policy: missing
      arguments:
        - "--tls-verify=false"
  mode: stdout
```

Now let navigator show you what it will use:

```bash
ansible-navigator images -m interactive
```

The header summarizes image, pull arguments, and pull policy, then pulls the image if needed. The list shows `ee-supported-rhel9` with the `Execution environment` column set to `True`. Press `0` to see the image details (Ansible version, collections, Python packages), then `Esc` twice to leave.

`-m interactive` on the command line overrides `mode: stdout` from the file for this one command: command line options always beat the settings file.

---

## Step 4: Run without `ansible.cfg` and read the failure

```bash
ansible-navigator run whoami.yml
```

Result: a warning that the host list is empty, `skipping: no hosts matched`. Without `ansible.cfg`, Ansible does not know where the inventory is.

Give the inventory on the command line and try again:

```bash
ansible-navigator run whoami.yml -i inventory
```

Result: every host is `UNREACHABLE` with `root@servera.lab.example.com: Permission denied (publickey...)`. Inside the execution environment the default login is `root`, and root has no authorized key on the servers. This is the most common navigator failure on the exam.

---

## Step 5: Write `ansible.cfg`

Create `ansible.cfg` in the project root:

```ini
[defaults]
inventory = ./inventory
remote_user = devops
ask_pass = false
```

Run the probes:

```bash
ansible-navigator run ping_web.yml
ansible-navigator run ping_db.yml
ansible-navigator run whoami.yml
```

Expected: the two ping playbooks return `ok` for their two hosts each, and `whoami.yml` prints:

```
"msg": "servera.lab.example.com runs tasks as devops"
```

for all four hosts.

---

## Step 6: Watch privilege escalation take effect

Append the escalation section to `ansible.cfg`:

```ini
[privilege_escalation]
become = true
become_method = sudo
become_user = root
become_ask_pass = false
```

```bash
ansible-navigator run whoami.yml
```

Every host now reports `runs tasks as root`. Nothing changed on the managed hosts; Ansible simply wrapped each module in `sudo`.

Now set `become = false` again and request escalation for one run only:

```bash
ansible-navigator run whoami.yml --become
```

Root again: options that navigator does not recognize are passed through to `ansible-playbook`. Leave `become = false` in the file. The file now matches `solutions/ansible.cfg`, and it is the safer default: later chapters enable escalation only in the plays that need it.

---

## Step 7: Stop the artifact clutter

```bash
ls *-artifact-*.json
```

Each run so far left a JSON artifact in the project. Add the artifact setting at the end of `ansible-navigator.yml` (same indentation as `mode`):

```yaml
  playbook-artifact:
    enable: false
```

Delete the old artifacts and prove that no new one appears:

```bash
rm -f *-artifact-*.json
ansible-navigator run ping_web.yml
ls *-artifact-*.json 2>/dev/null | wc -l          # 0
```

Your file now matches `solutions/ansible-navigator.yml`.

---

## Step 8: Inspect the effective configuration

Interactive view:

```bash
ansible-navigator config -m interactive
```

1. Type `:f remote` and press Enter to filter the list.
2. Press the number of the **Default remote user** row.
3. Read the details: `current_value: devops`, `source` pointing to `/workspaces/intro_configure/ansible.cfg`, and the matching `env` (`ANSIBLE_REMOTE_USER`) and `ini` (`remote_user` in `[defaults]`) names.
4. Press `Esc` twice, or type `:q` and Enter.

The same information from the plain command line, which is faster on the exam:

```bash
ansible-config dump --only-changed
```

```
CONFIG_FILE() = /workspaces/intro_configure/ansible.cfg
DEFAULT_ASK_PASS(/workspaces/intro_configure/ansible.cfg) = False
DEFAULT_BECOME(/workspaces/intro_configure/ansible.cfg) = False
...
DEFAULT_HOST_LIST(/workspaces/intro_configure/ansible.cfg) = ['/workspaces/intro_configure/inventory']
DEFAULT_REMOTE_USER(/workspaces/intro_configure/ansible.cfg) = devops
```

---

## Step 9: Find option names without documentation

Pretend you forgot how to enable logging to a file:

```bash
ansible-config init --disabled | grep -n -B3 log_path
```

The output shows the section, the description, and the exact key `log_path`. Do not add it; this step is about the lookup technique.

Close the container with **File, Close Remote Connection**.

---

## Step 10: Prove the precedence rules (workstation terminal)

These experiments run on workstation, **outside** the container, because they involve your home directory.

**10.1 The home file applies only when no project file is present.**

```bash
cat > ~/.ansible.cfg <<'EOF'
# intro_configure experiment
[defaults]
remote_user = student
forks = 20
EOF

cd ~
ansible --version | grep 'config file'           # /home/student/.ansible.cfg
ansible-config dump --only-changed               # DEFAULT_FORKS = 20, DEFAULT_REMOTE_USER = student

cd ~/intro_configure
ansible --version | grep 'config file'           # /home/student/intro_configure/ansible.cfg
ansible-config dump --only-changed | grep -E 'FORKS|REMOTE_USER'
```

In the project directory `REMOTE_USER` is `devops` and `FORKS` is absent (default 5). The home file was not merged; it was ignored completely.

**10.2 `ANSIBLE_CONFIG` beats the project file.**

```bash
ANSIBLE_CONFIG=~/.ansible.cfg ansible-config dump --only-changed | grep REMOTE_USER    # student
```

**10.3 An environment variable overrides one setting of the active file.**

```bash
ANSIBLE_REMOTE_USER=operator ansible-config dump --only-changed | grep REMOTE_USER
```

```
DEFAULT_REMOTE_USER(env: ANSIBLE_REMOTE_USER) = operator
```

**10.4 A world writable directory is ignored.**

```bash
mkdir /tmp/ww && chmod 0777 /tmp/ww
cp ansible.cfg /tmp/ww/
cd /tmp/ww
ansible --version 2>&1 | grep -iE 'world writable|config file'
cd ~/intro_configure && rm -rf /tmp/ww
```

Ansible warns that it is running in a world writable directory and ignores that `ansible.cfg`; `config file` falls back to `~/.ansible.cfg`.

**10.5 A `#` after a value is not a comment.**

```bash
mkdir -p ~/cfgtest && cd ~/cfgtest
printf '[defaults]\nremote_user = devops  # automation account\n' > ansible.cfg
ansible-config dump --only-changed | grep REMOTE_USER
printf '[defaults]\nremote_user = devops  ; automation account\n' > ansible.cfg
ansible-config dump --only-changed | grep REMOTE_USER
cd ~ && rm -rf ~/cfgtest
```

The first result contains the comment text as part of the user name. The second shows plain `devops`.

---

## Finish

```bash
lab finish intro_configure
```

Finish deletes `~/.ansible.cfg` (it recognizes the `# intro_configure experiment` first line) so the experiment cannot affect later exercises, and removes any playbook artifacts from the project.

---

## What You Proved

| Rule | Where you saw it |
|---|---|
| No inventory setting means no hosts | Step 4, first run |
| Navigator defaults to root inside the EE | Step 4, second run |
| `become` changes the effective user without touching the host | Step 6 |
| Command line options override the settings file | Step 3 (`-m interactive`) and step 6 (`--become`) |
| Only one `ansible.cfg` is read | Step 10.1 |
| `ANSIBLE_CONFIG` and `ANSIBLE_*` variables override files | Steps 10.2 and 10.3 |
| World writable directories are distrusted | Step 10.4 |
| Inline comments need `;` | Step 10.5 |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ansible-navigator images` fails to pull | Check spelling of the image path and that `--tls-verify=false` sits under `pull.arguments` as a list item |
| YAML error when navigator starts | Indentation: `execution-environment`, `mode`, and `playbook-artifact` must line up two spaces under `ansible-navigator:` |
| `whoami.yml` still reports devops after enabling become | The `[privilege_escalation]` header is misspelled; check with `ansible-config dump --only-changed \| grep BECOME` |
| Step 10 results differ from the text | You ran them inside the container, where the home directory is `/root`. Use a workstation terminal |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Build Your Ansible Development Environment](01_guided_exercise_intro_devenv.md) | Next: [Chapter 01 Quiz: How Ansible Works and How It Is Configured](03_quiz.md) →

<!-- navfoot:end -->
