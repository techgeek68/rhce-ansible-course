<!-- nav:start -->
[Course home](../README.md) › [Chapter 03: Variables, Facts, and Secrets](README.md) › Lesson (1 of 7)

**Pages in this chapter, in study order:**

1. Lesson: this page
2. Guided exercise: [Guided Exercise: Place Variables at the Right Scope](01_guided_exercise_variables_vars.md)
3. Guided exercise: [Guided Exercise: Drive Automation from Facts](02_guided_exercise_variables_facts.md)
4. Guided exercise: [Guided Exercise: Protect Secrets with Ansible Vault](03_guided_exercise_variables_vault.md)
5. Quiz: [Chapter 03 Quiz: Variables, Facts, and Vault](04_quiz.md)
6. Graded lab: [Chapter 03 Lab: A Login Protected Portal Built from Variables, Facts, and Vault](05_lab.md)
7. Lab solution: [Chapter 03 Lab Solution: `variables_review`](06_lab_solution.md)
<!-- nav:end -->

# Chapter 03: Variables, Facts, and Secrets

| | |
|---|---|
| **Goal** | Replace hard coded values with variables placed at the right scope, drive automation from host facts, and keep secrets encrypted with Ansible Vault |
| **Study time** | About 6 hours including exercises |
| **Activities** | [04_quiz.md](04_quiz.md), three guided exercises, [05_lab.md](05_lab.md) (graded) |
| **Lab prerequisite** | Chapter 02 complete |

---

## 0. Chapter Map

| Section | After it you can | Practice |
|---|---|---|
| 1. Variables | Define variables in plays, files, `group_vars`, `host_vars`, and on the command line, and predict which value wins | [01_guided_exercise_variables_vars.md](01_guided_exercise_variables_vars.md) |
| 2. Facts and Magic Variables | Read, limit, export, and extend facts, and use data from other hosts | [02_guided_exercise_variables_facts.md](02_guided_exercise_variables_facts.md) |
| 3. Ansible Vault | Encrypt files and single values, use several vault passwords, and run encrypted projects without prompts | [03_guided_exercise_variables_vault.md](03_guided_exercise_variables_vault.md) |
| Review | All of the above in one project | [05_lab.md](05_lab.md) |

**EX294 objectives this chapter supports** (verify against the current list):

* Create playbooks that use variables to retrieve the results of running a command.
* Use variables and facts in playbooks.
* Protect sensitive data using Ansible Vault; use vault in playbooks.
* Create and use static inventories to define groups of hosts (with `group_vars` and `host_vars`).

---

## 1. Variables

### 1.1 Why variables

A value typed into three tasks must be changed in three places, and one of them will be missed. A variable names the value once. More importantly, the **same playbook** can then behave differently per host or group, because the value can come from the inventory instead of the playbook.

### 1.2 Naming rules

| Rule | Invalid | Valid |
|---|---|---|
| Letters, digits, underscores only | `web-server`, `web.server`, `web server` | `web_server` |
| Must not start with a digit | `1st_user` | `user_1`, `_1st_user` |
| Must not be a Python keyword | `class`, `for`, `import` | `class_name` |
| Must not be a playbook keyword | `name`, `hosts`, `environment`, `tags` | `app_name`, `target_hosts` |
| Must not be a magic variable | `hostvars`, `groups`, `inventory_hostname` | `my_groups` |

Prefix variables with the component they belong to (`web_port`, `db_port`) so names stay globally unique; unique names make precedence irrelevant in everyday work.

### 1.3 Where variables can live

| Location | Applies to | Typical use |
|---|---|---|
| Inventory file, host line | One host | Connection details such as `ansible_host` |
| Inventory file, `[group:vars]` | A group | Quick, small projects |
| `group_vars/GROUP.yml` or `group_vars/GROUP/*.yml` | A group | The normal home of group settings |
| `host_vars/HOST.yml` or `host_vars/HOST/*.yml` | One host | Exceptions for a single host |
| Facts | One host | Discovered at run time |
| Play `vars:` | One play | Values that belong to that play's logic |
| Play `vars_files:` | One play | Longer lists, shared between playbooks, encrypted files |
| Task `vars:` | One task | Rare; local overrides |
| `register:` and `set_fact` | One host, rest of the run | Results and computed values |
| `-e` / `--extra-vars` | Everything | One off overrides |

`group_vars/` and `host_vars/` are found **next to the inventory** and **next to the playbook**. When both exist, the playbook side wins. File names must match group and host names exactly: a host listed as `serverd.lab.example.com` reads `host_vars/serverd.lab.example.com.yml`, never `host_vars/serverd.yml`.

Both layouts work, and the directory form is the one to use once a group has secrets:

```
group_vars/
    all.yml                     file form: variables for group all
    web/                        directory form: every file inside is loaded
        vars.yml
        vault.yml               encrypted
host_vars/
    serverd.lab.example.com.yml
```

### 1.4 Precedence

When a name is defined in several places, the highest entry wins. The full order, lowest first (entries in italics are covered in later chapters):

| # | Source |
|---|---|
| 1 | *Role defaults* |
| 2 | Inventory file group vars (`[group:vars]`) |
| 3 | Inventory `group_vars/all` |
| 4 | Playbook `group_vars/all` |
| 5 | Inventory `group_vars/*` |
| 6 | Playbook `group_vars/*` |
| 7 | Inventory file host vars (host line) |
| 8 | Inventory `host_vars/*` |
| 9 | Playbook `host_vars/*` |
| 10 | Host facts and cached `set_fact` |
| 11 | Play `vars` |
| 12 | Play `vars_prompt` |
| 13 | Play `vars_files` |
| 14 | *Role vars* |
| 15 | *Block vars* |
| 16 | Task vars |
| 17 | *`include_vars`* |
| 18 | `set_fact` and registered variables |
| 19 | *Role and include parameters* |
| 20 | Extra vars (`-e`): always win |

Three shortcuts cover almost every case:

1. **Host beats group.** Any host level source beats any group level source.
2. **Playbook beats inventory.** Play `vars` beat everything in the inventory, including `host_vars`.
3. **`-e` beats everything.**

Between groups at the same depth, a child group beats its parent, and `all` loses to every other group. When two unrelated groups set the same variable for one host, the group whose name sorts **later alphabetically** wins, unless you set `ansible_group_priority` on one of them.

Command line options such as `-u` and `-b` are not variables and do not appear in this table.

### 1.5 Using variables in a play

```yaml
- name: Scheduler is ready
  hosts: all
  vars:
    tool_pkgs:
      - at
      - tmux
    scheduler_svc: atd
  vars_files:
    - vars/common.yml
  tasks:
    - name: Tools are installed
      ansible.builtin.dnf:
        name: "{{ tool_pkgs }}"
        state: present

    - name: Scheduler runs and starts at boot {{ scheduler_svc }}
      ansible.builtin.systemd_service:
        name: "{{ scheduler_svc }}"
        state: started
        enabled: true
```

The quoting rule from Chapter 2 now bites constantly: a value that **starts** with `{{` must be quoted, otherwise YAML reads `{` as the start of a dictionary and Ansible answers with an error suggesting missing quotes. `path: /home/{{ user }}` needs no quotes; `path: "{{ home }}/bin"` does.

Put templates at the **end** of task names (`Scheduler runs ... {{ scheduler_svc }}`); ansible-lint (`name[template]`) reports templates in the middle of a name.

### 1.6 Extra variables

```bash
ansible-navigator run users.yml -e team_name=auditors                    # strings
ansible-navigator run users.yml -e '{"team_uid": 7010, "admin": true}'   # JSON keeps types
ansible-navigator run users.yml -e @vars/override.yml                    # a whole file
```

`key=value` pairs always arrive as **strings**. Most modules convert them, but comparisons in conditions (next chapter) do not, so use JSON or a file when types matter.

### 1.7 Dictionaries and lists

```yaml
team_user:                      # a dictionary
  name: devlead
  uid: 7001
  comment: Development lead

admins:                         # a list of dictionaries
  - name: alice
    uid: 8101
  - name: bob
    uid: 8102
```

| Expression | Value |
|---|---|
| `team_user['name']` | `devlead` |
| `team_user.name` | `devlead` (dot notation) |
| `admins[0]['name']` | `alice` |
| `admins[1]['uid']` | `8102` |
| `admins \| length` | `2` |

Use **bracket notation**. Dot notation breaks silently when a key collides with a Python method: `data.items`, `data.keys`, `data.copy` return the method, not your value. Lists are usually processed with loops (next chapter) rather than by index.

### 1.8 Registered variables

`register:` stores the complete result of a task for the current host:

```yaml
- name: Team account is present
  ansible.builtin.user:
    name: "{{ team_user['name'] }}"
    uid: "{{ team_user['uid'] }}"
  register: team_account

- name: Report the account
  ansible.builtin.debug:
    msg: "{{ team_account['name'] }} lives in {{ team_account['home'] }}"
```

| Key | Present for | Meaning |
|---|---|---|
| `changed`, `failed` | Every module | Task outcome |
| `rc`, `stdout`, `stdout_lines`, `stderr` | `command`, `shell` | Command result |
| `msg` | Many modules | Human readable message |
| Module specific (`uid`, `home`, `status`, `content`) | Documented in `RETURN VALUES` of `ansible-doc MODULE` | Module result |

To find what a module returns, print the whole result once with `debug: var=` and read it, or look at the `RETURN VALUES` section of `ansible-doc`.

`debug` has two modes: `msg` takes a sentence with `{{ }}` expressions; `var` takes a bare variable name without braces and prints the structure.

### 1.9 Finding out what a variable is

```bash
ansible-inventory --host serverd.lab.example.com          # all inventory level variables, merged
ansible serverd.lab.example.com -m ansible.builtin.debug -a var=motd_banner
grep -Rnw 'motd_banner:' .                                  # where is it defined (colon means definition)
```

`ansible-inventory --host` shows inventory and `group_vars`/`host_vars` results only. Play `vars`, facts, and `-e` values appear only while a playbook runs.

### 1.10 Traps

| Trap | Symptom |
|---|---|
| Unquoted value starting with `{{` | YAML error mentioning missing quotes |
| `host_vars/serverd.yml` for a host listed by FQDN | Variable silently undefined |
| Same variable in play `vars` and `host_vars` | Host specific value ignored; play wins |
| `-e uid=7001` compared with a number | String versus integer mismatch |
| Dot notation on keys like `items` | Wrong value or error |

---

## 2. Facts and Magic Variables

### 2.1 What facts are

At the start of every play (`Gathering Facts`), the `ansible.builtin.setup` module collects information from each host into the dictionary `ansible_facts`. Facts are variables like any other, only discovered instead of defined.

| Question | Fact |
|---|---|
| Short host name / full name | `ansible_facts['hostname']` / `ansible_facts['fqdn']` |
| Main IPv4 address | `ansible_facts['default_ipv4']['address']` |
| Every IPv4 address | `ansible_facts['all_ipv4_addresses']` |
| Interface names | `ansible_facts['interfaces']` |
| Distribution and version | `ansible_facts['distribution']`, `ansible_facts['distribution_version']`, `ansible_facts['distribution_major_version']` |
| OS family | `ansible_facts['os_family']` (RedHat, Debian, ...) |
| Kernel | `ansible_facts['kernel']` |
| Memory | `ansible_facts['memtotal_mb']`, `ansible_facts['memfree_mb']` |
| CPUs | `ansible_facts['processor_vcpus']`, `ansible_facts['processor_count']` |
| Disks and partitions | `ansible_facts['devices']` (keys are kernel names such as `vda`, `sdb`, `nvme0n1`) |
| Mounted file systems | `ansible_facts['mounts']` |
| Volume groups and logical volumes | `ansible_facts['lvm']` (when lvm2 is installed) |
| DNS servers | `ansible_facts['dns']['nameservers']` |
| Custom facts | `ansible_facts['ansible_local']` |

### 2.2 Exploring facts

```bash
ansible servera.lab.example.com -m ansible.builtin.setup | less
ansible servera.lab.example.com -m ansible.builtin.setup -a 'filter=ansible_default_ipv4'
ansible servera.lab.example.com -m ansible.builtin.setup -a 'filter=ansible_*_mb'
```

In an ad hoc `setup` result, fact names carry the `ansible_` prefix (`ansible_default_ipv4`); inside `ansible_facts` in a playbook the prefix is dropped (`ansible_facts['default_ipv4']`). The `filter` argument uses the prefixed names and accepts wildcards.

To keep facts for later analysis, write them to files on the control side:

```yaml
- name: One JSON file per host
  ansible.builtin.copy:
    content: "{{ ansible_facts | to_nice_json }}\n"
    dest: "{{ playbook_dir }}/facts/{{ inventory_hostname }}.json"
    mode: "0644"
  delegate_to: localhost
```

`delegate_to: localhost` runs the task where Ansible runs: on workstation with `ansible-playbook`, inside the execution environment with `ansible-navigator`. Writing under `playbook_dir` works in both cases because navigator mounts the project directory into the container. Such a task always reports `changed`, because facts like uptime change every second.

### 2.3 Old style fact variables

Before Ansible 2.5 facts were separate variables: `ansible_hostname`, `ansible_default_ipv4`. They still exist by default (`inject_facts_as_vars = true`), so old playbooks keep working. Prefer `ansible_facts['hostname']`:

* injected facts sit high in precedence and can silently replace your own variables that share a name;
* with `inject_facts_as_vars = false` in `ansible.cfg`, only the `ansible_facts[...]` form works.

| New form | Old form |
|---|---|
| `ansible_facts['hostname']` | `ansible_hostname` |
| `ansible_facts['default_ipv4']['address']` | `ansible_default_ipv4['address']` |
| `ansible_facts['dns']['nameservers']` | `ansible_dns['nameservers']` |

### 2.4 Controlling fact gathering

| Need | How |
|---|---|
| No facts, faster play | `gather_facts: false` on the play |
| Facts later in the play | A task with `ansible.builtin.setup:` |
| Only some facts | `setup` with `gather_subset: ["!all", "network"]` (`!all` keeps a minimal core) |
| Everything except hardware | `gather_subset: ["!hardware"]` (quote it: `!` cannot start a plain YAML value) |
| Only matching keys in the result | `setup` with `filter: ansible_local` |
| Reuse facts between runs | `gathering = smart` with `fact_caching = jsonfile` in `ansible.cfg` |

Special fact modules add more: `ansible.builtin.service_facts` fills `ansible_facts['services']`, `ansible.builtin.package_facts` fills `ansible_facts['packages']`.

### 2.5 Custom facts

A managed host can describe itself. Files in `/etc/ansible/facts.d/` ending in `.fact` are read by `setup` and appear under `ansible_facts['ansible_local']['FILENAME_WITHOUT_.fact']`.

| Kind | Content | Example file |
|---|---|---|
| Static INI | `[section]` then `key = value` | `app.fact` |
| Static JSON | A JSON object | `app.fact` |
| Dynamic | An **executable** program that prints JSON | `runtime.fact` with mode 0755 |

```ini
[deploy]
package = vsftpd
service = vsftpd
state = started
enabled = true
```

gives `ansible_facts['ansible_local']['app']['deploy']['package'] == 'vsftpd'`. Values from INI files are always **strings**: `enabled` is `"true"`, not `true`. Modules convert it; comparisons do not. YAML is not accepted in fact files.

The most common custom fact bug: a play creates a fact file and uses it in the same play. Facts were gathered **before** the file existed, so the value is undefined. Reload them first:

```yaml
- name: Local facts are reloaded after the change
  ansible.builtin.setup:
    filter: ansible_local
```

### 2.6 `set_fact`

`ansible.builtin.set_fact` creates or replaces a variable for the current host for the rest of the run:

```yaml
- name: Short name for the deployment facts
  ansible.builtin.set_fact:
    deploy: "{{ ansible_facts['ansible_local']['app']['deploy'] }}"
```

Later tasks write `deploy['package']` instead of the long path. `set_fact` values rank near the top of precedence (18), above play vars.

### 2.7 Magic variables

Ansible defines these itself; never use their names for your own variables.

| Variable | Contains |
|---|---|
| `inventory_hostname` | This host's name as written in the inventory |
| `inventory_hostname_short` | The same, up to the first dot |
| `group_names` | Groups this host belongs to (without `all`) |
| `groups` | Every group and its hosts: `groups['web']` |
| `hostvars` | Every host's variables: `hostvars['serverb.lab.example.com']['ansible_facts']['default_ipv4']['address']` |
| `ansible_play_hosts` | Hosts still active in the current play |
| `playbook_dir`, `inventory_dir` | Directories of the playbook and the inventory |
| `ansible_check_mode` | `true` when running with `--check` |
| `ansible_version` | Version of the running Ansible |

`hostvars` contains another host's **facts only if they were gathered in this run**, for example by an earlier play targeting that host. The guided exercise uses a first play that gathers network facts from all web hosts so that a second play can read them.

`inventory_hostname` and `ansible_facts['fqdn']` are different things: the first is whatever you typed in the inventory, the second is what the host reports about itself.

### 2.8 Traps

| Trap | Symptom |
|---|---|
| `gather_facts: false` and a task using facts | `'ansible_facts' ... has no attribute` |
| Using a custom fact in the play that created it | Undefined until `setup` runs again |
| INI fact compared with a boolean | Always false: the value is a string |
| `hostvars` of a host not targeted yet | Facts missing for that host |
| Hard coding `vda` in `ansible_facts['devices']` | Fails on hypervisors where the disk is `sdb` |

---

## 3. Ansible Vault

### 3.1 What vault protects

`ansible-vault` encrypts data **at rest** with AES256, using a key derived from a password. It protects:

* variable files (`group_vars`, `host_vars`, `vars_files`), which Ansible decrypts transparently when it loads them;
* any file used by `copy`, `template`, `unarchive`, `script`, or `assemble`, which Ansible decrypts on the way to the managed host;
* a single value inside an otherwise readable YAML file (`encrypt_string`).

Once decrypted during a run, the data is ordinary text: it can end up in output, logs, and artifacts unless you prevent that (section 3.7).

### 3.2 The `ansible-vault` command

| Task | Command |
|---|---|
| New encrypted file | `ansible-vault create FILE` |
| Encrypt existing files | `ansible-vault encrypt FILE [FILE...]` |
| Read without changing | `ansible-vault view FILE` |
| Change content | `ansible-vault edit FILE` (always rewrites the file) |
| Remove encryption | `ansible-vault decrypt FILE [--output NEW]` |
| Change password or vault ID | `ansible-vault rekey FILE` with `--new-vault-id` or `--new-vault-password-file` |
| Encrypt one value | `ansible-vault encrypt_string --stdin-name VAR` (then type the value, Ctrl+D) |

`create` and `edit` open `$EDITOR` (vi by default). `export EDITOR=nano` changes it. Never open an encrypted file in a normal editor and save it: that corrupts it or stores your changes unencrypted.

Typing a secret as a command argument (`encrypt_string S3cret --name x`) stores it in shell history; `--stdin-name` avoids that.

### 3.3 The file header

```
$ANSIBLE_VAULT;1.1;AES256                 no vault ID (legacy single password)
$ANSIBLE_VAULT;1.2;AES256;prod            vault ID "prod"
```

The header is plain text, so `head -n1 FILE` tells you whether and how a file is encrypted.

### 3.4 Supplying the password

| Method | Syntax | Notes |
|---|---|---|
| Prompt, single password | `--ask-vault-pass` (or `-J`) | Needs `-m stdout --pae false` with navigator |
| Password file | `--vault-password-file FILE` | File holds one line; mode 0600 |
| Vault ID, prompt | `--vault-id LABEL@prompt` | Repeat for several IDs |
| Vault ID, file | `--vault-id LABEL@FILE` | |
| Vault ID, script | `--vault-id LABEL@script.sh` | Executable prints the password, for secret managers |
| Configuration, single | `vault_password_file = FILE` in `[defaults]` | No options needed at run time |
| Configuration, several | `vault_identity_list = dev@.vault_dev,prod@.vault_prod` | |
| Environment | `ANSIBLE_VAULT_PASSWORD_FILE`, `ANSIBLE_VAULT_IDENTITY_LIST` | Reach navigator's container only when passed through (`--penv NAME`); prefer `ansible.cfg` |

Without a password, a run touching encrypted data stops with `Attempting to decrypt but no vault secrets found`. With a wrong one: `Decryption failed`.

### 3.5 Vault IDs

A vault ID is a **label** stored in the header that tells Ansible which of several passwords to try. Typical labels: `dev` and `prod`, so development engineers never hold the production password.

```bash
ansible-vault create --vault-id dev@prompt group_vars/dev/vault.yml
ansible-vault create --vault-id prod@prompt group_vars/prod/vault.yml
ansible-navigator run site.yml --vault-id dev@prompt --vault-id prod@prompt
```

Behaviors to know:

* By default Ansible tries **every** supplied password on every file until one works. `vault_id_match = true` restricts each password to files with the matching label: faster and stricter.
* Ansible does not remember which password belongs to a label. Encrypting two files with label `prod` but different passwords is possible and a common mistake; fix it with `rekey`.
* `--vault-id @prompt` without a label means the label `default`. Legacy `1.1` files count as `default` too, which matters with `vault_id_match = true`.

### 3.6 Project layout for secrets

```
group_vars/
    prod/
        vars.yml       plain:      db_user: app
                                   db_password: "{{ vault_db_password }}"
        vault.yml      encrypted:  vault_db_password: S3cret
```

Keeping a readable `vars.yml` that **refers** to `vault_` prefixed variables in the encrypted `vault.yml` means `grep` still finds every variable name, code review still shows which secrets exist, and only the values stay hidden. Load encrypted playbook level files with `vars_files`, exactly like plain ones.

### 3.7 Keeping decrypted data out of sight

```yaml
- name: Stage login account
  ansible.builtin.user:
    name: "{{ team_login }}"
    password: "{{ team_password_hash }}"
  no_log: true
```

`no_log: true` replaces the task result with a censored message, also at `-vvv` and also on failure. Use it only where secrets flow, because it hides error messages too. Other leaks to close: playbook artifacts (disable them), `log_path` files, `debug` tasks, and `-e` values in shell history.

### 3.8 Password file hygiene

* Mode `0600`, owned by you.
* Never committed: add the names to `.gitignore` **before** the first `git add`.
* Better outside the project (for example `~/.vault/prod`) in real work; inside the project is acceptable in the lab and on the exam when a task says so.
* A password file must not end up world readable in a shared directory; Ansible reads it as plain text.

### 3.9 Encrypted files with modules

```yaml
- name: Token file is decrypted on the host
  ansible.builtin.copy:
    src: files/app_token.conf        # vault encrypted in the project
    dest: /etc/reporting/token.conf
    mode: "0600"
    decrypt: true                    # the default; false would copy the ciphertext
```

### 3.10 Traps

| Trap | Symptom |
|---|---|
| Prompt with artifacts enabled or interactive mode | navigator hangs or refuses to prompt |
| `ansible-vault encrypt` on an encrypted file | `input is already encrypted` |
| `vault_id_match = true` with legacy `1.1` files | Those files no longer decrypt unless a `default` password is supplied |
| Password file with a trailing space typed by hand | `Decryption failed` although the password looks right |
| Secrets visible with `-v` | Missing `no_log: true` on the task |
| `.vault_*` files committed | Secret leaked permanently in Git history |
| Encrypting after `vault_identity_list` lists several IDs | `Specify the vault-id to encrypt with --encrypt-vault-id`; add `--encrypt-vault-id LABEL` |

---

## 4. Chapter Checklist

* [ ] Place a variable at the correct scope: play, group, host, extra.
* [ ] Predict the winner of a variable defined at five levels, then prove it.
* [ ] Use `group_vars` and `host_vars` in file and directory form with correct names.
* [ ] Access nested dictionaries and lists with bracket notation.
* [ ] Register a module result and print a chosen field.
* [ ] Find any fact with `setup` and `filter`, and write it with `ansible_facts[...]`.
* [ ] Limit fact gathering and gather facts on demand.
* [ ] Create static and dynamic custom facts, and reload them in the same play.
* [ ] Read another host's data through `hostvars` and `groups`.
* [ ] Create, view, edit, rekey, and decrypt vault files; encrypt a single string.
* [ ] Run a project with two vault IDs by prompt, by file, and through `ansible.cfg`.
* [ ] Hide secret values with `no_log` and keep password files out of Git.

## 5. Exam Rules From This Chapter

1. Quote every value that starts with `{{`.
2. Name `host_vars` files exactly like the inventory host name.
3. Use bracket notation: `ansible_facts['default_ipv4']['address']`.
4. Check variable results with `ansible-inventory --host` before running the play.
5. After creating a custom fact, run `setup` with `filter: ansible_local` before using it.
6. Use `--stdin-name` so secrets never enter shell history.
7. Store vault password files with mode 0600 and reference them in `ansible.cfg` when the task allows it.
8. With navigator, prompt only in stdout mode with artifacts disabled.
9. Put `no_log: true` on every task that handles a secret.
10. `head -n1` tells you if a file is encrypted and with which vault ID.

**Next:** Chapter 4 builds on these variables.

<!-- navfoot:start -->

---

← Previous: [Chapter 02 Lab Solution: `develop_review`](../02_developing_content/07_lab_solution.md) | Next: [Guided Exercise: Place Variables at the Right Scope](01_guided_exercise_variables_vars.md) →

<!-- navfoot:end -->
