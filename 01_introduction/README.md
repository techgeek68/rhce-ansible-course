<!-- nav:start -->
[Course home](../README.md) › [Chapter 01: Introduction to Ansible](README.md) › Lesson (1 of 6)

**Pages in this chapter, in study order:**

1. Lesson: this page
2. Guided exercise: [Guided Exercise: Build Your Ansible Development Environment](01_guided_exercise_intro_devenv.md)
3. Guided exercise: [Guided Exercise: Configure Ansible and Automation Content Navigator](02_guided_exercise_intro_configure.md)
4. Quiz: [Chapter 01 Quiz: How Ansible Works and How It Is Configured](03_quiz.md)
5. Graded lab: [Chapter 01 Lab: Configure a Project, Run It Through an Execution Environment, Publish It](04_lab.md)
6. Lab solution: [Chapter 01 Lab Solution: `intro_review`](05_lab_solution.md)
<!-- nav:end -->

# Chapter 01: Introduction to Ansible

| | |
|---|---|
| **Goal** | Understand how Ansible works, build the toolchain you will use for the rest of the course, and control Ansible behavior through configuration files |
| **Study time** | About 4 hours including exercises |
| **Activities** | [03_quiz.md](03_quiz.md), [01_guided_exercise_intro_devenv.md](01_guided_exercise_intro_devenv.md), [02_guided_exercise_intro_configure.md](02_guided_exercise_intro_configure.md), [04_lab.md](04_lab.md) (graded) |
| **Lab prerequisite** | `00_lab_setup/02_dev_services.md` completed |

---

## 0. Chapter Map

| Section | After it you can | Practice |
|---|---|---|
| 1. How Ansible Thinks | Explain every moving part between typing a command on workstation and a change appearing on servera | [03_quiz.md](03_quiz.md) |
| 2. Your Development Environment | Edit, lint, run, and version playbooks with VS Code, a dev container, and an execution environment | [01_guided_exercise_intro_devenv.md](01_guided_exercise_intro_devenv.md) |
| 3. Configuring Ansible | Write `ansible.cfg` and `ansible-navigator.yml` from memory and predict which settings win | [02_guided_exercise_intro_configure.md](02_guided_exercise_intro_configure.md) |
| Review | Prove all of the above under exam conditions | [04_lab.md](04_lab.md) |

**EX294 objectives this chapter supports** (check the current list on the Red Hat EX294 exam page before your exam, because Red Hat revises it):

* Understand core components of Ansible: inventories, modules, variables, facts, plays, playbooks, configuration files.
* Install and configure an Ansible control node: install required packages, create a configuration file, manage privilege escalation.
* Use provided documentation to look up specific information about Ansible modules and commands.

---

## 1. How Ansible Thinks

### 1.1 The problem with doing it by hand, and the problem with scripts

Suppose you must create a `deploy` user and add one line to `/etc/motd` on servera, serverb, serverc, and serverd. By hand that is four SSH sessions and eight commands, and the only way to confirm the result is to log in again and look.

A shell script removes the typing but not the real problem. Run it twice and see what happens:

```bash
#!/bin/bash
useradd deploy
echo "Managed by the automation team" >> /etc/motd
```

| Run | `useradd deploy` | `echo >> /etc/motd` |
|---|---|---|
| First | Creates the user | Adds the line |
| Second | Fails: `user 'deploy' already exists` | Adds the line **again** |

The script describes **actions**. Ansible describes the **end state** and works out which actions are still needed:

```yaml
- name: Standard login setup
  hosts: all
  become: true
  tasks:
    - name: The deploy account exists
      ansible.builtin.user:
        name: deploy
        state: present

    - name: The banner line is present exactly once
      ansible.builtin.lineinfile:
        path: /etc/motd
        line: Managed by the automation team
```

| Run | Result per host |
|---|---|
| First | `changed=2` |
| Second | `changed=0`, both tasks report `ok` |
| After someone deletes the line on serverc | serverc `changed=1`, the others `changed=0` |

That property, where repeating a run changes nothing once the system is already correct, is **idempotency**. It is why you can run the same playbook every hour as a drift detector, and why graders on the exam can rerun checks without breaking your work. Keep that last row in mind: a correct playbook also **repairs** drift.

Because a playbook is plain text, it also behaves like source code: it can be reviewed, versioned in Git, compared, and rolled back. Describing infrastructure this way is called **Infrastructure as Code**.

### 1.2 Vocabulary, mapped onto your lab

| Term | Meaning | Where it is in your lab |
|---|---|---|
| Control node | The machine where Ansible is installed and where you run commands | workstation |
| Managed host | A machine Ansible configures. It needs SSH and Python, and no Ansible software | servera, serverb, serverc, serverd |
| Inventory | The list of managed hosts, optionally organized into groups | `inventory` file in each project |
| Module | A small program that makes one kind of change or gathers one kind of data | `ansible.builtin.user`, `ansible.builtin.dnf` |
| Task | One call to one module with its arguments | "The deploy account exists" |
| Play | A list of tasks aimed at a set of hosts | The block that starts with `- name: Standard login setup` |
| Playbook | A YAML file holding one or more plays | `site.yml` |
| Plugin | Code that extends Ansible itself: how it connects, how it prints output, how it reads inventory | `ssh` connection plugin, `default` output callback |
| Collection | A distributable package of modules, plugins, and roles | `ansible.posix`, `community.general` |
| FQCN | Fully qualified collection name: `namespace.collection.module` | `ansible.builtin.copy` |
| Execution environment (EE) | A container image holding ansible-core, collections, and their Python dependencies | `ee-supported-rhel9` in the lab registry |

### 1.3 What actually happens when a task runs

Ansible is **agentless**: nothing is installed or running on the managed hosts between runs. Each task follows this sequence:

1. Ansible on the control node reads its configuration, the inventory, and the playbook.
2. For each task, it contacts the hosts in parallel batches. The default batch size is 5 (`forks`).
3. It opens an SSH connection as the remote user.
4. It creates a temporary directory under `~/.ansible/tmp` on the managed host and copies in the module, bundled with its arguments.
5. It runs the module with the host's Python, through `sudo` if privilege escalation is on.
6. The module compares the current state with the requested state, changes only what differs, and prints a JSON result.
7. Ansible deletes the temporary directory and reports `ok`, `changed`, `failed`, or `unreachable`.

See it for yourself on workstation:

```bash
ansible servera.lab.example.com -i servera.lab.example.com, -u devops \
  -m ansible.builtin.ping -vvv 2>&1 | grep -E 'ESTABLISH SSH|PUT|EXEC .*python|rm -f -r'
```

You will see the SSH connection opened, the module file transferred (`PUT`), the Python execution, and the cleanup. The trailing comma after the host name tells Ansible that this is a host list, not an inventory file name.

Consequences you must remember:

| Because Ansible works this way | This must be true on every managed host |
|---|---|
| It logs in over SSH | sshd runs and the remote user can authenticate (usually with a key) |
| Modules are Python programs | Python 3 is installed (only `ansible.builtin.raw` works without it) |
| Root changes go through `sudo` | The remote user has sudo rights, with or without a password |
| Linux and UNIX use SSH | Windows hosts use WinRM instead; network devices often use SSH or an API |

### 1.4 Anatomy of a playbook

```yaml
---                                   # optional YAML document start
- name: Standard login setup          # PLAY: a list item at the top level
  hosts: all                          #   which inventory hosts or groups to target
  become: true                        #   run tasks through sudo as root
  tasks:                              #   the ordered list of tasks
    - name: The deploy account exists # TASK: describe the result, not the command
      ansible.builtin.user:           #   MODULE, always written as its FQCN
        name: deploy                  #   module ARGUMENTS, indented under the module
        state: present
```

Rules the parser enforces and graders notice:

* Indentation is spaces only. Two spaces per level is the convention.
* A play is a list item (`- name:`), so a playbook is a list of plays. Each play can target different hosts.
* Tasks run top to bottom. When a task fails on a host, Ansible stops running the remaining tasks **for that host only**; the other hosts continue.

### 1.5 How Ansible is packaged

| Package | What it contains | How you get it on RHEL | Version example |
|---|---|---|---|
| `ansible-core` | The engine, the command line tools (`ansible`, `ansible-playbook`, `ansible-doc`, `ansible-galaxy`, `ansible-config`), and only the `ansible.builtin` modules | `dnf install ansible-core` from AppStream | 2.14, 2.15, 2.16 |
| Community `ansible` | ansible-core plus a large curated set of community collections | pip, not shipped by Red Hat | 9, 10, 11 |
| Red Hat Ansible Automation Platform | Supported ansible-core, certified collections, execution environments, automation controller (the former Ansible Tower) with web UI, API, and role based access control, and the development tools | Subscription repositories and registry.redhat.io | AAP 2.4 uses core 2.15; AAP 2.5 and 2.6 use core 2.16 |

Why this split exists: until 2.9, everything shipped as one large package, so a fix to one module waited for the next engine release. Since 2.10 the engine (first called `ansible-base`, renamed `ansible-core` in 2.11) is separate, and all other content moved into **collections** that are released and installed independently.

The practical effect for you: any module that is not in `ansible.builtin` must be installed as a collection, and you should always call modules by FQCN so there is never doubt about which collection provides them.

Read your control node the way an examiner would:

```bash
ansible --version
```

| Output line | What it tells you |
|---|---|
| `ansible [core 2.x.y]` | Engine version, which decides available keywords and builtin modules |
| `config file = ...` | **Which `ansible.cfg` is active.** The first thing to check when settings seem ignored |
| `configured module search path` | Where custom modules are looked up |
| `ansible collection location` | Where installed collections are searched, in order |
| `executable location` | Which `ansible` binary answered, useful when both RPM and pip versions exist |
| `python version` | The control node Python used by Ansible |

```bash
ansible-doc -l ansible.builtin | wc -l      # how many builtin modules you have
ansible-doc ansible.builtin.user            # full documentation with examples, offline
ansible-galaxy collection list              # installed collections and their paths
```

`ansible-doc` works without internet access, which is exactly your situation in the exam. Jump to the `EXAMPLES` section with `/EXAMPLES` inside the pager.

### 1.6 Where Ansible fits

| Lifecycle stage | Typical tool | Example in this lab |
|---|---|---|
| Day 0: create infrastructure | Terraform, Kickstart, PXE, cloud APIs | The Kickstart files that built servera to serverd |
| Day 1: configure it | Ansible | Install httpd, set firewall rules, create users |
| Day 2: keep it correct and change it safely | Ansible | Rerun playbooks to repair drift, patch hosts in batches |

Ansible can also do Day 0 work (it has modules to create VMs and cloud instances), and Terraform output can feed an Ansible inventory, so the two are complementary rather than competing.

Common uses you will practice in this course: configuration management (pushing `chrony.conf` to every host), application deployment, orchestration (update the web tier, then the database tier, in a defined order), security and compliance (enforce SELinux, sudo, and firewall policy), and container management with Podman.

### 1.7 Traps in this section

| Trap | Why it costs points |
|---|---|
| Using `ansible.builtin.command` or `shell` where a real module exists | The task is not idempotent and reports `changed` every run. Graders often check for `changed=0` on a second run |
| Writing short module names such as `user:` | Works only while no installed collection has the same short name. Always use FQCN |
| Believing the managed hosts need Ansible installed | They need Python and SSH access only |
| Expecting a failure on one host to stop all hosts | Only the failing host stops; read the recap line for every host |

---

## 2. Your Development Environment

### 2.1 Three ways to run the same playbook

```
Path 1: local engine
  workstation terminal
    ansible-playbook site.yml  (ansible-core RPM)  ==SSH==>  servera..serverd

Path 2: execution environment
  workstation terminal
    ansible-navigator run site.yml
      podman runs ee-supported-rhel9 (ansible-core + collections + Python libs)  ==SSH==>  servera..serverd

Path 3: dev container (what VS Code does in this course)
  VS Code on workstation
    dev container: ansible-dev-tools-rhel9 (navigator, lint, builder)
      podman inside it runs ee-supported-rhel9  ==SSH==>  servera..serverd
```

| Path | Strength | Weakness | When to use it |
|---|---|---|---|
| 1 | Fastest, no containers, `~/.ansible.cfg` and local collections apply | Results depend on what is installed on this one machine | Quick checks; any environment that only has ansible-core |
| 2 | Same Ansible version and collections everywhere, identical to automation controller | Image must be available; first pull is large | Team projects and production style runs |
| 3 | Whole toolchain versioned in the repository; new team members are productive in minutes | Most moving parts, needs a GUI | Daily development in this course |

**Exam lens:** you work in a terminal on the exam. Be fluent with both `ansible-navigator run PLAYBOOK -m stdout` and `ansible-playbook PLAYBOOK`. The GUI is a convenience for learning, never a dependency. Every guided exercise in this repository shows the terminal equivalent of each GUI step.

### 2.2 The toolbox

| Tool | Question it answers | Command to know |
|---|---|---|
| `ansible-navigator` | Run content inside an execution environment and inspect results | `ansible-navigator run site.yml -m stdout` |
| | Which images do I have? | `ansible-navigator images` |
| | What configuration is active, and where did each value come from? | `ansible-navigator config` |
| | Module documentation as the EE sees it | `ansible-navigator doc ansible.builtin.user -m stdout` |
| `ansible-lint` | Is this content correct and following current practice? | `ansible-lint site.yml` |
| `ansible-builder` | Build a custom execution environment image | `ansible-builder build -t my-ee:1.0` |
| Ansible extension for VS Code | Live lint, completion of module names and arguments, run menu | Right click a playbook, **Run Ansible Playbook via** |
| Dev Containers extension | Open the project inside a container image | **Reopen in Container** |

On RHEL 10 these tools ship bundled in the `ansible-dev-tools` RPM from the Ansible Automation Platform repository (for example `ansible-automation-platform-2.6-for-rhel-10-x86_64-rpms`); the `ansible-dev-tools-rhel9` container image provides the same tools anywhere Podman runs.

### 2.3 VS Code settings: from the GUI to the JSON behind it

Every checkbox in the Settings editor writes a key into a JSON file. Knowing the keys lets you configure a machine in seconds and review settings in Git.

| Settings editor path | JSON key | Lab value | Scope |
|---|---|---|---|
| Ansible, Validation, Lint: Enabled | `ansible.validation.lint.enabled` | `true` | Workspace |
| Ansible, Execution Environment: Enabled | `ansible.executionEnvironment.enabled` | `true` | Workspace |
| Ansible, Execution Environment: Container Engine | `ansible.executionEnvironment.containerEngine` | `podman` | Workspace |
| Ansible, Execution Environment: Image | `ansible.executionEnvironment.image` | `utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest` | Workspace |
| Ansible, Execution Environment, Pull: Policy | `ansible.executionEnvironment.pull.policy` | `missing` | Workspace |
| Ansible, Execution Environment, Pull: Arguments | `ansible.executionEnvironment.pull.arguments` | `--tls-verify=false` | Workspace |
| Dev Containers: Docker Path | `dev.containers.dockerPath` | `podman` | User |
| Dev Containers: Docker Compose Path | `dev.containers.dockerComposePath` | `podman-compose` | User |

| Scope | File | Travels with the project? |
|---|---|---|
| Workspace | `PROJECT/.vscode/settings.json` | Yes, commit it |
| User | `~/.config/Code/User/settings.json` | No, it belongs to this machine |

Critical detail: the extension's execution environment settings only affect the **Run playbook via ansible-navigator** menu. Running `ansible-navigator` in a terminal reads `ansible-navigator.yml` instead. Keep the image, pull policy, and pull arguments identical in both places, or the menu and the terminal will run different Ansible versions.

### 2.4 The dev container definition

The Ansible extension generates `.devcontainer/podman/devcontainer.json`. This is the lab version with each line explained:

```jsonc
{
  "name": "ansible-dev-container-podman",       // label shown when you choose Reopen in Container
  "image": "utility.lab.example.com:5000/ansible-automation-platform-26/ansible-dev-tools-rhel9:latest",
  "containerUser": "root",                        // root inside the container maps to student outside (rootless Podman)
  "runArgs": [
    "--rm",                                       // delete the container when VS Code disconnects
    "--tls-verify=false",                         // the lab registry is plain HTTP
    "--cap-add=CAP_MKNOD",                        // this and the next options let Podman run
    "--cap-add=NET_ADMIN",                        // nested inside the container, which is how
    "--cap-add=SYS_ADMIN",                        // ansible-navigator starts the execution
    "--cap-add=SYS_RESOURCE",                     // environment from within the dev container
    "--device=/dev/fuse",
    "--security-opt=seccomp=unconfined",
    "--security-opt=label=disable",
    "--security-opt=apparmor=unconfined",
    "--security-opt=unmask=/sys/fs/cgroup",
    "--userns=host",
    "--hostname=ansible-dev-container"
  ],
  "mounts": [                                     // local lab addition: your SSH key and known_hosts,
    "source=${localEnv:HOME}/.ssh,target=/root/.ssh,type=bind,readonly"   // read only
  ],
  "customizations": { "vscode": { "extensions": ["redhat.ansible"] } }
}
```

The generated file may list the capability options in a different order; what matters is the image, `--rm`, `--tls-verify=false`, and the SSH mount. JSON files do not allow comments; the comments above are for reading only.

When the container opens, your project is mounted at `/workspaces/PROJECT_NAME` and the status bar at the lower left shows the container name.

### 2.5 Git: the ten commands behind the Source Control view

```
working tree  ==git add==>  staging area  ==git commit==>  local repository  ==git push==>  remote (Gitea)
      ^                                                                              |
      +=========================== git pull (fetch + merge) ========================+
```

| File state | Meaning | `git status` shows |
|---|---|---|
| Modified | Changed in the working tree, not yet staged | `modified:` in red |
| Staged | Selected for the next commit | `modified:` in green |
| Committed | Stored in the local repository | Nothing, or `ahead of 'origin/main' by N` if not pushed |

| VS Code action | Terminal equivalent |
|---|---|
| First use on a machine | `git config --global user.name 'Student User'` and `git config --global user.email student@lab.example.com` |
| Clone Repository | `git clone http://utility.lab.example.com:3000/student/REPO.git ~/git-repos/REPO` |
| `+` next to a file | `git add FILE` |
| `+` on the Changes header | `git add -A` |
| `-` next to a staged file | `git restore --staged FILE` |
| Letters `A` and `M` beside files | `git status -s` shows the same letters |
| Commit | `git commit -m 'message'` |
| More Actions, Push | `git push` (first push of a new branch: `git push -u origin main`) |
| More Actions, Pull | `git pull` |
| Timeline / file history | `git log --oneline -- FILE` and `git diff HEAD~1 -- FILE` |

Commit messages: say what changed and why, in the imperative. `Report managed host name in hello.yml` is useful a year later; `update` is not.

Keep generated files out of the repository with `.gitignore`:

```
*-artifact-*.json
ansible-navigator.log
ansible.log
```

### 2.6 Traps in this section

| Trap | Symptom |
|---|---|
| Committed but never pushed | Your work is only on workstation; the Gitea page shows the old version |
| Git identity not set | Commit fails with `Please tell me who you are`, or commits carry a wrong author that a grader checks |
| VS Code EE settings differ from `ansible-navigator.yml` | The Run menu and the terminal give different results |
| Editing files in the container that are outside `/workspaces` | Changes disappear when the container is removed (`--rm`) |

---

## 3. Configuring Ansible

### 3.1 Where a setting can come from

From lowest to highest precedence:

1. The active configuration file (`ansible.cfg`)
2. Environment variables named `ANSIBLE_*` (for example `ANSIBLE_REMOTE_USER`)
3. Command line options (for example `-u devops`, `-b`, `-i inventory`)
4. Playbook keywords (for example `remote_user:` or `become:` in a play or task)
5. Variables (for example `ansible_user` or `ansible_become` in the inventory)

So `become: false` written in a play beats `become = true` in `ansible.cfg`, and an inventory variable `ansible_user=student` beats both `-u devops` and `remote_user = devops`. When a setting seems to be ignored, walk up this list.

### 3.2 Which `ansible.cfg` is used

Ansible searches these locations in order and uses **only the first file it finds**. Files are never merged.

| Order | Location | Typical use |
|---|---|---|
| 1 | File named by `$ANSIBLE_CONFIG` | Temporary override, CI jobs, the `lab` command in this course |
| 2 | `./ansible.cfg` in the current directory | Per project settings: the normal case and the exam case |
| 3 | `~/.ansible.cfg` | Personal defaults for one user |
| 4 | `/etc/ansible/ansible.cfg` | System wide defaults |

Two consequences that catch people:

* If `./ansible.cfg` exists, **nothing** from `~/.ansible.cfg` applies, even settings the project file does not mention.
* Ansible refuses to load `./ansible.cfg` from a **world writable** directory (such as a project inside `/tmp` with mode 777) and prints a warning, because anyone could plant a configuration there. It falls back to the next location.

Inside an execution environment the picture changes: `ansible-navigator` mounts your project directory into the container, so the project `ansible.cfg` applies, but your `~/.ansible.cfg` on workstation is not in the container. **Put everything a project needs in the project file.**

Find out what is really active:

```bash
ansible --version | grep 'config file'     # which file won
ansible-config dump --only-changed         # every non default value and its source
ansible-config view                        # print the active file
ansible-navigator config                   # same information as seen inside the EE
```

`ansible-config dump --only-changed` output format:

```
CONFIG_FILE() = /home/student/project/ansible.cfg
DEFAULT_BECOME(/home/student/project/ansible.cfg) = True
DEFAULT_REMOTE_USER(env: ANSIBLE_REMOTE_USER) = devops
```

The text in parentheses is the source of each value.

### 3.3 The settings you set in almost every project

```ini
[defaults]
inventory = ./inventory          ; file or directory of inventory sources, relative to this file
remote_user = devops             ; SSH login name on managed hosts
ask_pass = false                 ; true only for password based SSH (requires sshpass)

[privilege_escalation]
become = false                   ; true makes every play run through sudo unless it says otherwise
become_method = sudo             ; alternatives include su
become_user = root               ; the account to become
become_ask_pass = false          ; true when sudo on the managed hosts asks for a password
```

Every value in `[privilege_escalation]` above is the default, so a file without that section behaves the same. Write it anyway on the exam when a task asks for these values: explicit is gradable, implicit is a guess.

What goes wrong when each setting is wrong:

| Setting | Wrong or missing | What you see |
|---|---|---|
| `inventory` | Path wrong or unset | `[WARNING]: provided hosts list is empty, only localhost is available` and `skipping: no hosts matched` |
| `remote_user` | Unset when running through `ansible-navigator` | Connects as `root`, the EE default: `UNREACHABLE ... Permission denied (publickey...)` |
| `become` | `false` for a task that needs root | Module error such as `This command has to be run under the root user.` |
| `become_ask_pass` | `false` although sudo needs a password | `Missing sudo password` |
| `ask_pass` | `true` without `sshpass` installed | `to use the 'ssh' connection type with passwords ... you must install the sshpass program` |

Other `[defaults]` options worth knowing:

| Option | Default | Purpose and caution |
|---|---|---|
| `forks` | `5` | Hosts handled in parallel. Raise it for large inventories |
| `host_key_checking` | `True` | `False` skips the SSH host key prompt. Acceptable in labs, a security risk in production |
| `timeout` | `10` | SSH connection timeout in seconds. Raise for slow links |
| `log_path` | unset | Also write `ansible-playbook` output to this file |
| `private_key_file` | unset | Use this SSH key instead of the SSH agent or `~/.ssh/config` |
| `connection` | `ssh` | Other plugins include `local` and `paramiko_ssh` |
| `collections_path` | user and system paths | Where collections are searched; add `./collections` for project local collections |

### 3.4 Privilege escalation on the managed host side

`become_method = sudo` only works if the managed host allows it. On RHEL 8, 9, and 10 members of `wheel` may use sudo after typing their password. For an automation account, add a drop in file owned by root:

```bash
echo 'devops ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/devops
sudo chmod 0440 /etc/sudoers.d/devops
sudo visudo -cf /etc/sudoers.d/devops       # syntax check: "parsed OK"
```

| Sudoers line | Effect | Matching Ansible setting |
|---|---|---|
| `devops ALL=(ALL) ALL` | sudo asks for devops's password | `become_ask_pass = true`, or `-K` on the command line |
| `devops ALL=(ALL) NOPASSWD: ALL` | No password prompt | `become_ask_pass = false` |
| `%wheel ALL=(ALL) NOPASSWD: ALL` | Every wheel member, no prompt | Same, for any wheel account |

The lab uses `NOPASSWD` for `devops`. Decide deliberately in real environments: passwordless sudo for an automation account trades convenience against the damage a stolen key can do.

Escalation can be switched on at four levels: `ansible.cfg`, command line (`-b`), play (`become: true`), or task. Enabling it only where needed is the cleaner design; enabling it globally is simpler when a project mostly configures the system.

Quick proof on workstation that the managed host side is right:

```bash
ssh devops@servera.lab.example.com 'sudo -n true && echo sudo works without a password'
```

### 3.5 SSH key authentication

```bash
ssh-keygen -t ed25519                           # only if ~/.ssh/id_ed25519 does not exist
ssh-copy-id devops@servera.lab.example.com      # appends your public key to authorized_keys
ssh devops@servera.lab.example.com hostname     # must not prompt for a password
```

Your lab already trusts the student key on every server, so these steps are for understanding and for the exam, where you may need to distribute a key yourself.

### 3.6 Generating a reference configuration

```bash
ansible-config init --disabled > ansible.cfg          # every option, all commented out
ansible-config init --disabled -t all > full.cfg      # include plugin options too
ansible-config list | less                            # every option with description and env var name
ansible-navigator config init --disabled --eei ee-supported-rhel9 --pp never -m stdout > ansible.cfg
```

The navigator variant produces nearly the same file, but default paths refer to `/home/runner` (the home directory inside the EE) instead of your own home.

**Exam lens:** you do not need to memorize option names. `ansible-config init --disabled | grep -n log_path` finds the exact spelling and section in two seconds. Without `--disabled`, every option is written uncommented with its default value, which hides the settings you actually changed.

### 3.7 Comments

| Character | Where it works | Effect |
|---|---|---|
| `#` | Start of a line in `ansible.cfg` and `ansible-navigator.yml` | Whole line ignored |
| `;` | Start of a line, or after a value in `ansible.cfg` | Everything to its right ignored |
| `#` after a value in `ansible.cfg` | Does not start a comment | Becomes **part of the value** |

`remote_user = devops  # automation account` sets the remote user to the literal string `devops  # automation account`. Prove it in the guided exercise with `ansible-config dump --only-changed`.

### 3.8 `ansible-navigator.yml`

Search order, first match wins:

1. The file named by `$ANSIBLE_NAVIGATOR_CONFIG`
2. `ansible-navigator.yml` (or `.yaml`, `.json`) in the current project directory
3. `~/.ansible-navigator.yml` in your home directory (note the leading dot)

```yaml
---
ansible-navigator:                     # every setting lives under this top level key
  execution-environment:
    container-engine: podman           # must be an engine installed on this machine
    enabled: true                      # false runs the local ansible-core instead of a container
    image: utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest
    pull:
      policy: missing                  # always | missing | never | tag
      arguments:
        - "--tls-verify=false"         # passed to "podman pull"; lab registry is plain HTTP
  mode: stdout                         # stdout prints like ansible-playbook; interactive opens the TUI
  playbook-artifact:
    enable: false                      # stop writing a JSON artifact for every run
```

| Key | Command line equivalent |
|---|---|
| `execution-environment.enabled` | `--ee true` or `--ee false` |
| `execution-environment.image` | `--eei IMAGE` |
| `execution-environment.pull.policy` | `--pp missing` |
| `execution-environment.pull.arguments` | `--pa=--tls-verify=false` |
| `execution-environment.container-engine` | `--ce podman` |
| `mode` | `-m stdout` |
| `playbook-artifact.enable` | `--pae false` |

Why two of these settings matter more than they look:

* **`mode: stdout`** is required whenever a run must prompt you (for a vault password or a sudo password), and whenever navigator runs from a script or CI job. The interactive TUI cannot prompt.
* **Playbook artifacts** are JSON records of each run, useful for replaying results with `ansible-navigator replay FILE`. They must be **disabled** for runs that prompt for passwords, and they clutter the project, so most projects turn them off and add the pattern to `.gitignore`.

Interactive mode keys: `Esc` goes back one level, `:q` quits, a number opens that row, `:f TEXT` filters rows, `:help` lists everything.

### 3.9 Diagnosing configuration problems

| Symptom | First command | Usual cause |
|---|---|---|
| Settings in `ansible.cfg` are ignored | `ansible --version \| grep 'config file'` | Wrong directory, `ANSIBLE_CONFIG` set, or world writable directory |
| Works with `ansible-playbook`, fails with `ansible-navigator` | `ansible-navigator config` | Setting only in `~/.ansible.cfg`, or collection installed only on workstation |
| Navigator pulls the wrong image | `ansible-navigator images` | Project `ansible-navigator.yml` missing, so `~/.ansible-navigator.yml` or defaults apply |
| Remote user is odd | `ansible-config dump --only-changed \| grep REMOTE_USER` | Inline `#` comment, or `ANSIBLE_REMOTE_USER` exported |
| Password prompt never appears in navigator | Check `mode` and `playbook-artifact.enable` | Interactive mode or artifacts enabled |

---

## 4. Chapter Checklist

Tick each item only when you can do it without looking at this chapter.

* [ ] Explain the seven steps of a task run and what each requires on the managed host.
* [ ] State what `ansible-core` contains and why non builtin modules need collections.
* [ ] Read `ansible --version` and name the active configuration file.
* [ ] List the four `ansible.cfg` locations in precedence order and explain why they do not merge.
* [ ] Write an `ansible.cfg` with inventory, remote user, and full privilege escalation settings from memory.
* [ ] Write an `ansible-navigator.yml` with image, pull policy, pull arguments, stdout mode, and artifacts disabled from memory.
* [ ] Translate every navigator setting to its command line option.
* [ ] Clone, commit, and push with Git in a terminal.
* [ ] Find any configuration option name with `ansible-config init --disabled | grep`.

## 5. Exam Rules From This Chapter

1. Check `ansible --version` in the project directory before running anything.
2. Put every project setting in the project `ansible.cfg`; never rely on `~/.ansible.cfg`.
3. Always set `remote_user`; the execution environment default is `root`.
4. Use FQCN for every module.
5. Use `-m stdout` (or `mode: stdout`) with `ansible-navigator`.
6. Disable playbook artifacts when a run must prompt for a password.
7. Prefer modules over `command` and `shell`; rerun and look for `changed=0`.
8. Look up option names with `ansible-config` and module arguments with `ansible-doc`; both work offline.
9. Never put a `#` comment after a value in `ansible.cfg`.
10. After configuration changes, prove them with `ansible-config dump --only-changed`.

**Next:** Chapter 2 builds inventories and writes multi play playbooks on top of the configuration you set up here.

<!-- navfoot:start -->

---

← Previous: [00 Lab Setup, Part 3: Developer Services](../00_lab_setup/02_dev_services.md) | Next: [Guided Exercise: Build Your Ansible Development Environment](01_guided_exercise_intro_devenv.md) →

<!-- navfoot:end -->
