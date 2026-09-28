<!-- nav:start -->
[Course home](../README.md) › [Chapter 02: Developing Automation Content](README.md) › Lesson (1 of 8)

**Pages in this chapter, in study order:**

1. Lesson: this page
2. Guided exercise: [Guided Exercise: Build and Query a Static Inventory](01_guided_exercise_develop_inventory.md)
3. Guided exercise: [Guided Exercise: Write, Check, Run, and Replay a Single Play](02_guided_exercise_develop_singleplay.md)
4. Guided exercise: [Guided Exercise: Orchestrate Several Plays](03_guided_exercise_develop_multiplay.md)
5. Guided exercise: [Guided Exercise: Diagnose and Repair Broken Automation](04_guided_exercise_develop_troubleshoot.md)
6. Quiz: [Chapter 02 Quiz: Inventories, Playbooks, and Troubleshooting](05_quiz.md)
7. Graded lab: [Chapter 02 Lab: Inventory, Repair, Build, and Verify](06_lab.md)
8. Lab solution: [Chapter 02 Lab Solution: `develop_review`](07_lab_solution.md)
<!-- nav:end -->

# Chapter 02: Developing Automation Content

| | |
|---|---|
| **Goal** | Describe managed hosts in an inventory, write single and multiple play playbooks, and find and fix faults in playbooks and managed hosts |
| **Study time** | About 6 hours including exercises |
| **Activities** | [05_quiz.md](05_quiz.md), four guided exercises, [06_lab.md](06_lab.md) (graded) |
| **Lab prerequisite** | Chapter 01 complete; `00_lab_setup/02_dev_services.md` section 3 (collections on materials.example.com) done |

---

## 0. Chapter Map

| Section | After it you can | Practice |
|---|---|---|
| 1. Inventories | Write INI and YAML inventories with groups, nested groups, ranges, and variables, and select hosts with patterns | [01_guided_exercise_develop_inventory.md](01_guided_exercise_develop_inventory.md) |
| 2. Writing a Play | Write correct YAML, pick the right module, and run a play safely with syntax check, check mode, and diff | [02_guided_exercise_develop_singleplay.md](02_guided_exercise_develop_singleplay.md) |
| 3. Playbooks with Several Plays | Orchestrate work across host sets, control login and privilege per play, and keep tasks idempotent | [03_guided_exercise_develop_multiplay.md](03_guided_exercise_develop_multiplay.md) |
| 4. Troubleshooting | Diagnose YAML, lint, runtime, connection, and privilege faults in a fixed order | [04_guided_exercise_develop_troubleshoot.md](04_guided_exercise_develop_troubleshoot.md) |
| Review | All of the above under a time limit | [06_lab.md](06_lab.md) |

**EX294 objectives this chapter supports** (verify against the current objective list before your exam):

* Create and use static inventories to define groups of hosts.
* Run ad hoc Ansible commands.
* Create Ansible plays and playbooks; know how to work with commonly used Ansible modules.
* Use provided documentation to look up information about modules and commands.

**Project convention in this chapter:** every exercise project contains `ansible.cfg`, `ansible-navigator.yml`, a dev container definition, and a `collections/` directory into which `lab start` installs `ansible.posix` from materials.example.com. The line `collections_path = ./collections:/usr/share/ansible/collections` in `ansible.cfg` makes that collection available both to `ansible-navigator` and to plain `ansible-playbook`, whichever image or control node you use.

---

## 1. Inventories

### 1.1 What an inventory answers

An inventory answers three questions for Ansible: **which hosts exist**, **how they are grouped**, and **what is special about each one** (connection details and other variables). A play never names machines directly unless you want it to; it names a group, and the inventory decides who is in it.

Two kinds exist:

| Kind | Source | Typical use |
|---|---|---|
| Static | A text file you write (INI or YAML) | Fixed server fleets, labs, the exam |
| Dynamic | An inventory plugin that queries an external system at run time | Clouds, virtualization platforms, CMDBs, anything that changes often |

### 1.2 INI inventory, rule by rule

```ini
# Ungrouped hosts come first, before any [section]
bastion.lab.example.com

[web]                          ; a group: name in brackets, one host per line
servera.lab.example.com
serverb.lab.example.com

[db]
serverd.lab.example.com

[prod]                         ; a host can sit in any number of groups
serverb.lab.example.com
serverd.lab.example.com

[datacenter:children]          ; a group made of groups
web
db
```

| Rule | Detail |
|---|---|
| Two groups always exist | `all` holds every host; `ungrouped` holds hosts that are in no group other than `all` |
| Hosts belong to many groups | Group by role, site, stage, owner: any axis you will want to target |
| `:children` nests groups | Nesting can go to any depth. A group can list its own hosts **and** have children; members are merged |
| Names | A host and a group must never share a name |
| Group name characters | Use letters, digits, and underscores. A hyphen (`db-servers`) triggers an `Invalid characters were found in group names` warning because group names must also work as variable names |
| Comments | `#` or `;` at the start of a line |

### 1.3 Ranges

A range in square brackets expands into many names. The pattern is `[START:END]` or `[START:END:STEP]`, and both ends are included.

| Written | Expands to |
|---|---|
| `server[a:d].lab.example.com` | servera, serverb, serverc, serverd |
| `web[01:12].example.com` | web01 to web12 (leading zero kept, so `web1` is **not** included) |
| `web[1:12].example.com` | web1 to web12 (no leading zeros) |
| `node[0:10:2].example.com` | node0, node2, node4, node6, node8, node10 |
| `192.168.250.[10:13]` | 192.168.250.10 to 192.168.250.13 |
| `192.168.[4:7].[0:255]` | every address in 192.168.4.0/22 |
| `2001:db8::[a:f]` | six IPv6 addresses |

Leading zeros are the trap: the range decides the exact spelling, and `--host web1.example.com` fails if the range was written `[01:12]`.

### 1.4 Variables in the inventory

```ini
[db]
serverd.lab.example.com db_engine=mariadb ansible_port=22

[prod:vars]
change_window="Saturday 02:00 UTC"
```

Host variables go on the host line; group variables go in a `[GROUP:vars]` section. When the same variable is set at several levels, the more specific one wins: host beats child group, child group beats parent group, any group beats `all`.

Variables whose names start with `ansible_` change how Ansible connects:

| Variable | Effect |
|---|---|
| `ansible_host` | Address to connect to, while the inventory name stays readable |
| `ansible_port` | SSH port |
| `ansible_user` | Login user (beats `remote_user` everywhere) |
| `ansible_become`, `ansible_become_user`, `ansible_become_method` | Privilege escalation for that host |
| `ansible_connection` | Connection plugin: `ssh`, `local`, and others |
| `ansible_python_interpreter` | Python path on the managed host |

Inline variables are fine for a few values. Larger projects move them into `host_vars/` and `group_vars/` directories, covered in the variables chapter.

### 1.5 The same inventory in YAML

```yaml
---
all:
  children:
    web:
      hosts:
        server[a:c].lab.example.com:
    db:
      hosts:
        serverd.lab.example.com:
          db_engine: mariadb
    prod:
      hosts:
        serverc.lab.example.com:
        serverd.lab.example.com:
      vars:
        change_window: Saturday 02:00 UTC
```

In YAML, every host is a key ending with a colon, even when it has no variables. INI is shorter for flat lists; YAML is clearer when hosts carry many variables. Both parse to the identical structure, which you can prove with `ansible-inventory --graph`.

### 1.6 Verifying an inventory

Never trust an inventory you have not queried.

| Question | ansible-navigator (inside the EE) | ansible-core on the control node |
|---|---|---|
| Whole structure as a tree | `ansible-navigator inventory -i inventory -m stdout --graph` | `ansible-inventory -i inventory --graph` |
| One group | `... --graph prod` | `ansible-inventory -i inventory --graph prod` |
| Everything as JSON, with variables | `... --list` | `ansible-inventory -i inventory --list` |
| One host and its variables | `... --host serverd.lab.example.com` | `ansible-inventory -i inventory --host serverd.lab.example.com` |
| Which hosts a pattern selects | none | `ansible -i inventory 'PATTERN' --list-hosts` |

`--host` with a name that does not exist fails with `You must pass a single valid host to --host parameter`: a quick test for range spelling. Without `-m stdout`, `ansible-navigator inventory` opens an interactive browser: `0` browses groups, `1` browses hosts, `Esc` goes back. Rows 10 and above need a colon, for example `:12`.

### 1.7 Host patterns

The `hosts:` line of a play and the first argument of `ansible` accept patterns, not only names:

| Pattern | Selects |
|---|---|
| `all` or `*` | Every host |
| `web` | Members of group web |
| `servera.lab.example.com` | That host |
| `*.lab.example.com` | Hosts whose names match the wildcard |
| `web:db` or `web,db` | Union: in web **or** db |
| `web:&prod` | Intersection: in web **and** in prod |
| `web:!prod` | Exclusion: in web but **not** in prod |
| `~server[ab]\..*` | Regular expression (starts with `~`) |
| `ungrouped` | Hosts with no group |

Quote patterns on the command line: `ansible 'web:!prod' --list-hosts`. The `!` otherwise triggers shell history expansion.

### 1.8 Where the inventory comes from

1. `-i PATH` on the command line (repeatable; several sources are merged).
2. `inventory =` in the active `ansible.cfg`.
3. `/etc/ansible/hosts`, the system default. Do not use it for projects.

`PATH` can be a file, a directory of inventory files (all merged), or a dynamic inventory plugin configuration.

### 1.9 Dynamic inventory in one paragraph

A dynamic source is a YAML file whose `plugin:` key names an inventory plugin, plus the plugin's settings (credentials, filters, how to build groups from tags). You pass it with `-i` like a static file, and you can mix it with static files in one inventory directory. `ansible-doc -t inventory -l` lists installed inventory plugins. The lab has no cloud platform, so this course uses static inventories only.

### 1.10 Traps

| Trap | Consequence |
|---|---|
| Hyphens in group names | Warning today, errors in stricter tooling; use underscores |
| Range with leading zeros, host referenced without | Host not found |
| Host and group with the same name | Ambiguous targeting; Ansible warns |
| Forgetting that hosts listed before the first `[group]` are ungrouped | A requirement such as "servera belongs to no group" fails if you also put it in a group |
| Short names in the inventory but FQDNs in the task wording | Grading scripts compare names literally; use exactly what the task specifies |

---

## 2. Writing a Play

### 2.1 YAML in six rules

1. **Spaces only**, never tabs. Two spaces per level is the convention.
2. Items at the same level have the **same indentation**; children are indented **more** than their parent.
3. `- ` (dash, space) starts a list item. A playbook is a list of plays; `tasks:` is a list of tasks.
4. `key: value` (colon, space) forms a dictionary entry. Keys in one dictionary must be unique; their order does not matter.
5. `#` starts a comment, either on its own line or after a space following data.
6. `---` optionally marks the start of the document, `...` the end.

Quoting decides how a value is read:

| You write | YAML reads | Fix when needed |
|---|---|---|
| `msg: Welcome: staff only` | **Syntax error**: a colon followed by a space inside a plain value | `msg: "Welcome: staff only"` |
| `msg: {{ greeting }}` | **Syntax error**: `{` starts an inline dictionary | `msg: "{{ greeting }}"` |
| `mode: 0644` | The octal number 420, which usually works but lint forbids it | `mode: "0644"` |
| `enabled: yes` | Boolean true, but lint wants `true` | `enabled: true` |
| `port: 8080` | Integer | `port: "8080"` only if a string is required |
| `path: C:\temp` in double quotes | `\t` becomes a tab | Use single quotes: `'C:\temp'` |

### 2.2 Anatomy of a play

```yaml
---
- name: Status page is published on the web tier   # play name: printed in the output
  hosts: web                                       # host pattern from the inventory
  become: true                                     # optional: run tasks through sudo
  tasks:                                           # ordered list of tasks
    - name: Httpd package is installed             # task name: describe the result
      ansible.builtin.dnf:                         # module, as FQCN
        name: httpd                                # module arguments
        state: present
```

Name every play and task. The names are what you read in the output, in logs, and in `--start-at-task`; lint reports unnamed plays and names that do not start with a capital letter.

### 2.3 Finding the right module

```bash
ansible-navigator doc -l -m stdout | grep -i firewall         # search modules in the EE
ansible-navigator doc ansible.posix.firewalld -m stdout       # full documentation
ansible-navigator doc -s ansible.posix.firewalld -m stdout    # argument skeleton to paste
ansible-navigator collections                                  # browse collections interactively

ansible-doc -l | grep -i firewall                              # same, for the control node
ansible-doc -s ansible.builtin.user
```

`ansible-doc` shows what is installed on the control node; `ansible-navigator doc` shows what is inside the execution environment. They can differ, which is why a module can work in one and be missing in the other.

In the full documentation, jump straight to working examples by typing `/EXAMPLES` in the pager.

Modules you will use constantly (EX294 relies heavily on these):

| Job | Module | Arguments to know |
|---|---|---|
| Install or remove packages | `ansible.builtin.dnf` | `name` (string or list), `state: present / latest / absent` |
| Distribution independent packages | `ansible.builtin.package` | `name`, `state` |
| Put a file or text on the host | `ansible.builtin.copy` | `src` or `content`, `dest`, `owner`, `group`, `mode` |
| File from a Jinja2 template | `ansible.builtin.template` | `src` (looked up in `templates/`), `dest`, `mode` |
| Directories, links, permissions, deletion | `ansible.builtin.file` | `path`, `state: directory / file / link / absent / touch`, `mode` |
| One line in a file | `ansible.builtin.lineinfile` | `path`, `line`, `regexp`, `state` |
| A block of lines | `ansible.builtin.blockinfile` | `path`, `block`, `marker` |
| Services | `ansible.builtin.systemd_service` (or `service`) | `name`, `state: started / stopped / restarted`, `enabled` |
| Firewall | `ansible.posix.firewalld` | `service` or `port`, `permanent`, `immediate`, `state: enabled` |
| Users and groups | `ansible.builtin.user`, `ansible.builtin.group` | `name`, `uid`, `groups`, `append`, `state` |
| Scheduled jobs | `ansible.builtin.cron` | `name`, `minute`, `hour`, `job`, `user` |
| HTTP requests and checks | `ansible.builtin.uri` | `url`, `status_code`, `return_content` |
| Downloads | `ansible.builtin.get_url` | `url`, `dest`, `mode` |
| Facts about a file | `ansible.builtin.stat` | `path` |
| Mount points | `ansible.posix.mount` | `path`, `src`, `fstype`, `state: mounted` |
| Show values | `ansible.builtin.debug` | `msg` or `var`, `verbosity` |
| Test connectivity | `ansible.builtin.ping` | none |
| Run a command | `ansible.builtin.command` / `shell` | `cmd`, `creates`, `removes`, `chdir` |

### 2.4 Running and reading the result

```bash
ansible-navigator run site.yml            # inside the EE; mode from ansible-navigator.yml
ansible-navigator run site.yml -m stdout  # force plain output
ansible-playbook site.yml                 # control node engine, same output format
```

Per task and host you see one of:

| Status | Meaning |
|---|---|
| `ok` | Already in the requested state; nothing done |
| `changed` | Ansible changed the host to reach the state |
| `failed` / `fatal` | The task failed; that host stops running the play |
| `skipping` | A condition excluded the task for that host |
| `unreachable` | Ansible could not connect or authenticate |

The **PLAY RECAP** totals these per host, plus `rescued` and `ignored` (covered in the error handling chapter). A correct play run a second time shows `changed=0` everywhere.

`Gathering Facts` is an implicit first task that runs `ansible.builtin.setup` to collect host information. Disable it with `gather_facts: false` in plays that do not need facts, to save time.

### 2.5 Look before you leap

| Option | What it does | Use it when |
|---|---|---|
| `--syntax-check` | Parses the playbook, runs nothing | After every edit |
| `--list-hosts` | Shows which hosts each play targets | After inventory or pattern changes |
| `--list-tasks` | Shows task names in order | Planning `--start-at-task` |
| `--check` (`-C`) | Dry run: reports what would change | Before touching real systems |
| `--diff` (`-D`) | Shows file content differences | With `--check`, to review configuration changes |

Check mode is a prediction, not a guarantee: a task that depends on something an earlier task would have created (for example starting a service whose package is not yet installed) can fail in check mode although the real run succeeds.

### 2.6 Playbook artifacts and replay

With artifacts enabled, each `ansible-navigator run` writes `PLAYBOOK-artifact-TIMESTAMP.json` holding the whole run. `ansible-navigator replay FILE` shows it again, interactively or with `-m stdout`. Artifacts let someone without access to your project inspect a failed run. Disable them (`--pae false` or `playbook-artifact.enable: false`) when a run must prompt for input, when output may contain secrets, or simply to keep the project clean.

### 2.7 Verbosity

| Option | Adds |
|---|---|
| `-v` | Task results |
| `-vv` | Task configuration and file paths used |
| `-vvv` | Connection details: SSH command, user, host |
| `-vvvv` | Connection plugin internals, scripts executed remotely |
| `-vvvvv`, `-vvvvvv` | Engine internals; useful when reporting bugs |

`-vvv` answers most "why can it not connect" questions. The higher levels are rarely worth their noise.

---

## 3. Playbooks with Several Plays

### 3.1 Why several plays

One play targets one host pattern. When a change spans roles, order matters, and several plays in one file express it:

```yaml
---
- name: Database is ready
  hosts: db
  become: true
  tasks:
    - name: MariaDB server is installed
      ansible.builtin.dnf:
        name: mariadb-server
        state: present

- name: Web tier is ready
  hosts: web
  become: true
  tasks:
    - name: Httpd is installed
      ansible.builtin.dnf:
        name: httpd
        state: present

- name: Monitoring host confirms the result
  hosts: probes
  become: false
  tasks:
    - name: Web tier answers
      ansible.builtin.uri:
        url: http://serverb.lab.example.com
```

Plays run top to bottom; the second play starts only after the first has finished on all its hosts.

### 3.2 Choosing the login user and the effective user per play

Two different accounts are involved in every task:

| Account | Controlled by | Lab value |
|---|---|---|
| **Login user**: whom SSH authenticates | `ansible_user` variable, then `remote_user` in the play, then `remote_user` in `ansible.cfg`, then the default | devops |
| **Effective user**: who runs the module | `become`, `become_user`, `become_method` | root when `become: true` |

Defaults when nothing is set: with `ansible-navigator` the login user is `root` (the user inside the execution environment); with `ansible-playbook` it is your own account on the control node.

Play level keywords override the configuration file for that play only:

```yaml
- name: Report is written as the student account
  hosts: probes
  remote_user: devops        # log in as devops
  become: true               # then switch user
  become_user: student       # to student, not root
  become_method: sudo
  tasks:
    - name: Report file exists
      ansible.builtin.copy:
        content: "probe ok\n"
        dest: /home/student/report.txt
```

`become_user` set to an unprivileged account needs the `acl` package on the managed host, because Ansible grants that account access to its temporary module files with `setfacl`. Without it the task fails with `Failed to set permissions on the temporary files Ansible needs to create when becoming an unprivileged user`.

Booleans accept `yes` and `no`, but write `true` and `false`: lint enforces it and the exam graders read your playbooks too.

### 3.3 Passing results from one play to the next

A variable created with `register:` belongs to the host that ran the task and survives into later plays **for that same host**. The guided exercise uses this to fetch a web page in one play and write it to a file in the next.

### 3.4 Command modules and idempotency

| Module | Runs through | Shell features (pipes, `>`, `$VAR`) | When to use |
|---|---|---|---|
| `ansible.builtin.command` | Python, no shell | No | A program with no dedicated module |
| `ansible.builtin.shell` | `/bin/sh` | Yes | You genuinely need pipes or redirection |
| `ansible.builtin.raw` | SSH directly, no Python | Yes | Hosts without Python, or to install Python |

All three report `changed` on every run, because Ansible cannot know what the command did. Make them honest:

```yaml
- name: Database is initialized once
  ansible.builtin.command:
    cmd: /opt/app/bin/init-db
    creates: /var/lib/app/db.initialized     # skip when this file exists

- name: Temporary import file is processed once
  ansible.builtin.command:
    cmd: /opt/app/bin/import /tmp/import.csv
    removes: /tmp/import.csv                 # skip when this file is gone
```

Better still, use a module that knows the desired state:

| Non idempotent | Result of repeated runs | Idempotent replacement |
|---|---|---|
| `shell: echo "line" >> /etc/motd` | The line is appended again every run | `lineinfile: path=/etc/motd line="line"` |
| `shell: echo "nameserver 192.168.250.254" > /etc/resolv.conf` | File rewritten, `changed` every run | `copy: content="nameserver 192.168.250.254\n" dest=/etc/resolv.conf` |
| `command: useradd deploy` | Fails on the second run | `user: name=deploy state=present` |
| `command: systemctl enable --now httpd` | `changed` every run | `systemd_service: name=httpd state=started enabled=true` |

(The replacements are written in shorthand here to fit the table. In playbooks, always use the expanded YAML form.)

### 3.5 YAML strings in playbooks

**Block scalars** keep long text readable:

```yaml
content: |            # literal: every newline kept
  search lab.example.com
  nameserver 192.168.250.254

cmd: >                # folded: newlines become spaces, one command line
  ansible-galaxy collection install
  -p collections ansible.posix
```

`|` produces text that ends with a newline, which is what configuration files need. `>` joins lines with spaces, handy for long commands.

**Inline forms** exist but are harder to read; avoid them except where a convention requires them:

```yaml
hosts: [servera, serverb]                     # inline list
vars: {port: 80, docroot: /var/www/html}      # inline dictionary
```

**Obsolete shorthand** such as `ansible.builtin.service: name=httpd state=started` still runs, but it is not real YAML, breaks editor completion, and lint reports it (`no-free-form`). Always expand arguments one per line.

---

## 4. Troubleshooting

### 4.1 A fixed order of diagnosis

Work from cheap checks to expensive ones and fix one fault at a time:

| Step | Command | Finds |
|---|---|---|
| 1. Parse | `ansible-navigator run PLAY.yml --syntax-check` | YAML and keyword errors |
| 2. Lint | `ansible-lint PLAY.yml` | Bad practice that often hides real bugs |
| 3. Targets | `ansible-navigator run PLAY.yml --list-hosts` or `ansible-inventory --graph` | Empty or wrong host sets |
| 4. Reach | `ansible HOST -m ansible.builtin.ping` | DNS, network, SSH, Python |
| 5. Privilege | `ansible HOST -b -m ansible.builtin.command -a id` | sudo configuration |
| 6. Dry run | `ansible-navigator run PLAY.yml --check --diff` | Logic and content |
| 7. Run and read | `ansible-navigator run PLAY.yml -vvv`, then `ansible.log` | Everything else |

### 4.2 Error catalog

| Message (abbreviated) | Cause | Fix |
|---|---|---|
| `Colons in unquoted values must be followed by a non-space character` or `mapping values are not allowed in this context` | A `: ` inside an unquoted value, or a missing space after a key's colon | Quote the value; write `key: value` with a space |
| `found character that cannot start any token` | Tab character used for indentation | Replace tabs with spaces |
| `conflicting action statements` | Two modules in one task, usually an indentation slip | Indent module arguments under the module |
| `couldn't resolve module/action 'ansible.posix.firewalld'` | Collection not installed where this run looks | `ansible-galaxy collection list`; check `collections_path` or the EE |
| `Could not find or access 'NAME'` | `src` file missing, misspelled, or not in `files/` or `templates/` | Fix the name or location |
| `provided hosts list is empty` | No inventory, or a pattern matching nothing | `ansible --version`, `ansible-inventory --graph` |
| `UNREACHABLE ... Could not resolve hostname` or `Name or service not known` | Misspelled host or DNS problem | Fix the inventory; test with `getent hosts NAME` |
| `UNREACHABLE ... Permission denied (publickey...)` | Wrong login user, or no key for that user | Check `remote_user` and `ansible_user`; test `ssh USER@HOST` |
| `Missing sudo password` | sudo requires a password | `become_ask_pass = true` or `-K`, or a NOPASSWD sudoers rule |
| `This command has to be run under the root user` or `Permission denied` on a system file | `become` not enabled | `become: true` on the play or task |
| `Could not find the requested service NAME` | Wrong unit name | `systemctl list-unit-files \| grep NAME` on the host |
| `Failed to set permissions on the temporary files` | `become_user` is unprivileged and `acl` is missing | Install `acl` on the managed host |
| `/usr/bin/python3: not found` | No Python on the managed host | Install it with `ansible.builtin.raw` |

### 4.3 Seeing values with `debug`

```yaml
- name: Show free memory
  ansible.builtin.debug:
    msg: "Free memory: {{ ansible_facts['memfree_mb'] }} MB"

- name: Show the whole registered result, only with -vv or more
  ansible.builtin.debug:
    var: probe
    verbosity: 2
```

`msg` prints a sentence you compose; `var` prints a variable and its structure. `verbosity: N` keeps diagnostic tasks silent unless you run with at least N `-v` options, so they can stay in the playbook.

### 4.4 Controlling what runs

```bash
ansible-navigator run site.yml --list-tasks
ansible-navigator run site.yml --start-at-task "Httpd is running and starts at boot"
ansible-navigator run site.yml --step -m stdout --pae false
```

`--step` asks `(N)o/(y)es/(c)ontinue` before each task. Because it prompts, it needs stdout mode and disabled artifacts, exactly like password prompts.

### 4.5 ansible-lint

`ansible-lint` checks playbooks against rules. The ones you meet first:

| Rule | Triggered by | Fix |
|---|---|---|
| `name[play]` | A play without `name:` | Name it |
| `name[casing]` | A name starting with a lowercase letter | Capitalize |
| `fqcn[action-core]` | `dnf:` instead of `ansible.builtin.dnf:` | Use the FQCN |
| `yaml[truthy]` | `yes`, `no`, `True` | `true`, `false` |
| `yaml[octal-values]` | `mode: 0644` unquoted | `mode: "0644"` |
| `yaml[trailing-spaces]` | Spaces at the end of a line | Delete them |
| `yaml[empty-lines]` | Too many blank lines, especially at the end | Delete them |
| `no-changed-when` | `command` or `shell` without `changed_when`, `creates`, or `removes` | Add one, or use a real module |
| `no-free-form` | `module: key=value` shorthand | Expand the arguments |

```bash
ansible-lint site.yml            # one file
ansible-lint                     # every playbook in the project
ansible-lint --offline -q site.yml   # no network lookups, compact output
```

Project level settings live in `.ansible-lint` (or `.config/ansible-lint.yml`): `skip_list` silences rules, `warn_list` downgrades them to warnings. When the linter runs through navigator, point to the file with `ansible-lint: config: .ansible-lint` in `ansible-navigator.yml`. In VS Code, lint results appear as underlines and in the Problems panel; set the file's language mode to **Ansible** (lower right corner) if nothing is underlined.

A syntax error stops lint before any rule runs, so fix syntax first.

### 4.6 Logging

```ini
[defaults]
log_path = ./ansible.log
```

or `export ANSIBLE_LOG_PATH=~/ansible.log`; the environment variable wins over the file. The log records the same output as the screen, with timestamps and the user and process ID, which makes it the place to search after a long run (`grep -n -i fatal ansible.log`). Logs in `/var/log` need a `logrotate` rule.

### 4.7 Connection problems

| Symptom | Check |
|---|---|
| Wrong account in the error (`developer@host: Permission denied`) | The user before `@` is the login user; trace it through `ansible_user`, play `remote_user`, `ansible.cfg` |
| Right account, still denied | `ssh -i KEY USER@HOST`; is the public key in that user's `authorized_keys`? |
| Host has several addresses | Set `ansible_host=ADDRESS` for that host in the inventory |
| Works with `ansible-playbook`, fails in navigator | Login user default differs (root in the EE); your `~/.ssh` is shared with the EE, but `~/.ansible.cfg` is not |

### 4.8 Ad hoc commands

An ad hoc command runs one module once, without a playbook:

```bash
ansible PATTERN -m MODULE -a 'ARGUMENTS' [-i INVENTORY] [-b] [-u USER] [-o]
```

```bash
ansible all -m ansible.builtin.ping
ansible web -m ansible.builtin.command -a 'uptime' -o
ansible serverd.lab.example.com -b -m ansible.builtin.dnf -a 'name=tree state=present'
ansible all -b -m ansible.builtin.copy -a 'content="Managed host\n" dest=/etc/motd'
ansible db -b -m ansible.builtin.user -a 'name=backup uid=2001 state=present'
ansible servera.lab.example.com -m ansible.builtin.setup -a 'filter=ansible_default_ipv4'
ansible 'web:!prod' --list-hosts
```

Without `-m` the `command` module is used; always name the module anyway. `-o` prints one line per host. Ad hoc commands are for checks and one time fixes; anything you run twice belongs in a playbook.

---

## 5. Chapter Checklist

* [ ] Write an INI inventory with groups, `:children`, ranges, host variables, and `:vars`, and prove it with `--graph` and `--host`.
* [ ] Convert it to YAML and show both produce the same graph.
* [ ] Select hosts with union, intersection, and exclusion patterns.
* [ ] Write a playbook from a blank file with correct indentation and FQCNs.
* [ ] Find any module's arguments with `ansible-doc -s` or `ansible-navigator doc -s`.
* [ ] Use `--syntax-check`, `--check --diff`, `--list-hosts`, and `--list-tasks`.
* [ ] Control login user and effective user per play.
* [ ] Replace a non idempotent `shell` task with the right module.
* [ ] Diagnose a failure in the seven step order and name its cause from the error message.
* [ ] Clear every `ansible-lint` finding in a playbook.
* [ ] Run the common ad hoc commands from memory.

## 6. Exam Rules From This Chapter

1. Query every inventory you write: `ansible-inventory --graph`.
2. Use underscores in group names.
3. Quote values that contain `: `, start with `{{`, or are file modes.
4. Name every play and task; start names with a capital letter.
5. Run `--syntax-check` after every edit and `ansible-lint` before you call a playbook finished.
6. Rerun every playbook; anything but `changed=0` needs a reason.
7. Prefer modules to `command` and `shell`; if you must use them, add `creates`, `removes`, or `changed_when`.
8. Read the user before `@` in every `Permission denied` message.
9. Keep `-vvv` for connection problems and `debug` with `verbosity` for logic problems.
10. Use ad hoc commands to verify results quickly, never as the deliverable when a playbook is requested.

**Next:** Chapter 3 builds on these playbooks.

<!-- navfoot:start -->

---

← Previous: [Chapter 01 Lab Solution: `intro_review`](../01_introduction/05_lab_solution.md) | Next: [Guided Exercise: Build and Query a Static Inventory](01_guided_exercise_develop_inventory.md) →

<!-- navfoot:end -->
