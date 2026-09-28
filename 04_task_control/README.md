<!-- nav:start -->
[Course home](../README.md) › [Chapter 04: Task Control](README.md) › Lesson (1 of 7)

**Pages in this chapter, in study order:**

1. Lesson: this page
2. Guided exercise: [Guided Exercise: Apply a Baseline with Loops and Conditions](01_guided_exercise_control_flow.md)
3. Guided exercise: [Guided Exercise: React to Changes with Handlers](02_guided_exercise_control_handlers.md)
4. Guided exercise: [Guided Exercise: Decide What Failure Means](03_guided_exercise_control_errors.md)
5. Quiz: [Chapter 04 Quiz: Loops, Conditionals, Handlers, and Failures](04_quiz.md)
6. Graded lab: [Chapter 04 Lab: Central Logging with Task Control](05_lab.md)
7. Lab solution: [Chapter 04 Lab Solution: `control_review`](06_lab_solution.md)
<!-- nav:end -->

# Chapter 04: Task Control

| | |
|---|---|
| **Goal** | Repeat tasks over data with loops, run tasks only when conditions hold, react to changes with handlers, and decide what failure means and what happens next |
| **Study time** | About 6 hours including exercises |
| **Activities** | [04_quiz.md](04_quiz.md), three guided exercises, [05_lab.md](05_lab.md) (graded) |
| **Lab prerequisite** | Chapter 03 complete |

---

## 0. Chapter Map

| Section | After it you can | Practice |
|---|---|---|
| 1. Loops | Iterate over lists, dictionaries, ranges, and registered results, and keep the output readable | [01_guided_exercise_control_flow.md](01_guided_exercise_control_flow.md) |
| 2. Conditionals | Write correct `when` expressions with facts, variables, group membership, and results | [01_guided_exercise_control_flow.md](01_guided_exercise_control_flow.md) |
| 3. Handlers | Restart or reload services only after real changes, in a safe order | [02_guided_exercise_control_handlers.md](02_guided_exercise_control_handlers.md) |
| 4. Failure Handling | Tolerate, redefine, validate, and recover from failures | [03_guided_exercise_control_errors.md](03_guided_exercise_control_errors.md) |
| Review | Everything together | [05_lab.md](05_lab.md) |

**EX294 objectives this chapter supports** (verify against the current list):

* Use conditionals to control play execution.
* Configure error handling.
* Create playbooks to configure systems to a specified state, using loops and handlers.
* Use variables to retrieve the results of running a command.

---

## 1. Loops

### 1.1 One task, many items

```yaml
- name: Scheduler and logger run and start at boot
  ansible.builtin.systemd_service:
    name: "{{ item }}"
    state: started
    enabled: true
  loop:
    - atd
    - rsyslog
```

`loop` takes a list; the task runs once per element, with the element in `item`. The list can come from a variable: `loop: "{{ services }}"`.

Before looping, check whether the module accepts a list itself. `dnf` does:

```yaml
- name: Tools are installed in one transaction
  ansible.builtin.dnf:
    name: "{{ tool_pkgs }}"      # one dnf run for all packages
    state: present
```

One transaction is much faster than a loop that starts dnf once per package, and it resolves dependencies together. `systemd_service`, `user`, `file`, and `firewalld` accept one item per call, so those need `loop`.

### 1.2 Lists of dictionaries

```yaml
site_users:
  - name: ana
    groups: [ops]
    state: present
  - name: lee
    groups: [audit]
    state: absent
```

```yaml
- name: Site users are in their declared state
  ansible.builtin.user:
    name: "{{ item['name'] }}"
    groups: "{{ item['groups'] }}"
    append: true
    state: "{{ item['state'] }}"
  loop: "{{ site_users }}"
```

Each `item` is one dictionary. This is the most common loop shape on the exam: users, directories with modes, firewall ports with zones.

### 1.3 Looping over a dictionary

A dictionary is not a list, so convert it with `dict2items`:

```yaml
db_kernel_params:
  vm.swappiness: 10
  net.ipv4.tcp_keepalive_time: 600
```

```yaml
- name: Kernel parameters are set
  ansible.posix.sysctl:
    name: "{{ item['key'] }}"
    value: "{{ item['value'] }}"
    sysctl_file: /etc/sysctl.d/90-db.conf
  loop: "{{ db_kernel_params | dict2items }}"
```

`dict2items` turns each entry into `{key: ..., value: ...}`; `items2dict` goes the other way.

### 1.4 Controlling the loop with `loop_control`

| Option | Purpose | Example |
|---|---|---|
| `label` | Print a short label instead of the whole item | `label: "{{ item['name'] }}"` |
| `loop_var` | Rename `item`, needed when loops are nested through includes | `loop_var: user` |
| `index_var` | Expose the position (0 based) | `index_var: idx` |
| `pause` | Seconds to wait between items | `pause: 2` |
| `extended` | Adds `ansible_loop.first`, `.last`, `.index`, `.length` | `extended: true` |

`label` matters more than it looks: without it, every line of output repeats the whole dictionary, including any secret stored in it.

### 1.5 Other things to loop over

| Need | Expression |
|---|---|
| Numbers 1 to 5 | `loop: "{{ range(1, 6) \| list }}"` |
| Files on the control node | `loop: "{{ lookup('ansible.builtin.fileglob', 'files/*.conf', wantlist=True) }}"` |
| Each user with each of their keys | `loop: "{{ users \| subelements('ssh_keys') }}"` (then `item[0]`, `item[1]`) |
| Nested lists as one flat list | `loop: "{{ list_of_lists \| flatten }}"` |
| Every combination of two lists | `loop: "{{ hosts_list \| product(ports) \| list }}"` |

### 1.6 Old `with_` loops

You will meet the pre 2.5 syntax in existing playbooks. Convert it when you touch a file:

| Old | Modern equivalent |
|---|---|
| `with_items: "{{ x }}"` | `loop: "{{ x \| flatten(levels=1) }}"` (plain `loop` if `x` is not nested) |
| `with_dict: "{{ d }}"` | `loop: "{{ d \| dict2items }}"` |
| `with_sequence: start=1 end=5` | `loop: "{{ range(1, 6) \| list }}"` |
| `with_fileglob: files/*` | `loop: "{{ lookup('ansible.builtin.fileglob', 'files/*', wantlist=True) }}"` |
| `with_subelements` | `loop: "{{ x \| subelements('key') }}"` |
| `with_nested` | `loop: "{{ a \| product(b) \| list }}"` |

### 1.7 Registering a loop

When a looping task registers a variable, the per item results sit in the `results` list, and each result carries its `item`:

```yaml
- name: Look up every site user
  ansible.builtin.command: getent passwd {{ item['name'] }}
  loop: "{{ site_users }}"
  register: lookups
  changed_when: false
  failed_when: lookups['rc'] not in [0, 2]     # evaluated per item

- name: Report accounts that do not exist
  ansible.builtin.debug:
    msg: "{{ item['item']['name'] }} is absent"
  loop: "{{ lookups['results'] }}"
  when: item['rc'] == 2
```

Inside `failed_when` and `changed_when` of a looping task, the registered name refers to the **current item's** result. After the task, it refers to the whole structure: `lookups['results'][0]['rc']`.

### 1.8 Traps

| Trap | Symptom |
|---|---|
| Looping `dnf` over packages | Slow runs, one transaction per package |
| Loop over a dictionary without `dict2items` | `Invalid data passed to 'loop', it requires a list` |
| No `label` on a list of large dictionaries | Unreadable output, possible secret leaks |
| Reading `result['rc']` after a loop | Undefined: use `result['results']` |

---

## 2. Conditionals

### 2.1 `when`

```yaml
- name: Monitoring tools on hosts with enough memory
  ansible.builtin.dnf:
    name: sysstat
    state: present
  when: ansible_facts['memtotal_mb'] >= monitor_min_ram_mb
```

`when` is a task keyword (same indentation as the module name), and its value is already a Jinja2 expression: **no `{{ }}`**. Ansible warns when you add them. Place `when` consistently; this course puts it after the module arguments, and either position works.

A task skipped by `when` shows `skipping`, counts under `skipped` in the recap, and never notifies handlers.

### 2.2 Operators and tests

| Question | Expression |
|---|---|
| Equal / not equal | `ansible_facts['distribution'] == "RedHat"`, `!= "Fedora"` |
| Numeric comparison | `ansible_facts['memtotal_mb'] >= 1024` |
| Member of a list | `ansible_facts['distribution'] in supported_distros` |
| Not in a list | `install_package not in valid_packages` |
| Variable exists | `app_port is defined` / `is not defined` |
| Boolean | `run_backup` / `not run_backup` / `run_backup \| bool` |
| String contains / starts with | `'Relabeled' in relabel['stdout']`, `name is match('web')` |
| Regular expression anywhere | `output is search('ERROR [0-9]+')` |
| Version comparison | `ansible_facts['distribution_version'] is version('9.4', '>=')` |
| Registered result state | `result is failed`, `is succeeded`, `is changed`, `is skipped` |
| Host in a group | `'db' in group_names`, `inventory_hostname in groups['web']` |
| Package or service present | `'httpd' in ansible_facts['packages']` (after `package_facts`), `'httpd.service' in ansible_facts['services']` (after `service_facts`) |

### 2.3 Combining conditions

```yaml
when: ansible_facts['distribution'] == "RedHat" or ansible_facts['distribution'] == "Fedora"

when:                                          # a list means AND
  - ansible_facts['memtotal_mb'] >= 1024
  - ansible_facts['distribution_major_version'] | int >= 9

when: >
  (ansible_facts['distribution'] == "RedHat" and ansible_facts['distribution_major_version'] == "9")
  or
  (ansible_facts['distribution'] == "Fedora" and ansible_facts['distribution_major_version'] | int >= 40)
```

Use parentheses whenever `and` and `or` are mixed; do not rely on operator precedence in a playbook someone else must read.

### 2.4 Types decide comparisons

Many values are strings even when they look like numbers: `distribution_major_version` (`"9"`), values from `-e key=value`, INI custom facts. String comparison is alphabetical, so `"10" > "9"` is **false**. Convert first:

```yaml
when: ansible_facts['distribution_major_version'] | int >= 9
when: log_min_ram_mb | int <= ansible_facts['memtotal_mb']
```

Undefined variables stop the play with an error. Guard optional ones with `is defined` or give them a default: `when: enable_backup | default(false) | bool`.

### 2.5 Conditions with loops and results

With a loop, `when` is evaluated **per item**, so it can filter items:

```yaml
- name: Report the root file system when space is short
  ansible.builtin.debug:
    msg: "{{ item['mount'] }} has {{ item['size_available'] }} bytes free"
  loop: "{{ ansible_facts['mounts'] }}"
  loop_control:
    label: "{{ item['mount'] }}"
  when:
    - item['mount'] == "/"
    - item['size_available'] < 2000000000
```

A registered result of a task that was **skipped** has no `rc` or `stdout`; test it with `is skipped` or `is defined` before reading those keys.

### 2.6 Traps

| Trap | Symptom |
|---|---|
| `when: "{{ x }} == 1"` | Warning about templating delimiters; sometimes wrong results |
| Comparing a string number with an integer | Condition silently wrong or type error |
| `when` indented under the module | Parsed as a module argument: `Unsupported parameters ... when` |
| Undefined optional variable in `when` | Play fails instead of skipping |

---

## 3. Handlers

### 3.1 The problem handlers solve

A service must be restarted when its configuration changes, but restarting it on **every** run interrupts users for nothing. A handler is a task that runs only when another task reports `changed` and **notifies** it.

```yaml
  tasks:
    - name: Status page configuration is installed
      ansible.builtin.copy:
        src: files/status.conf
        dest: /etc/httpd/conf.d/status.conf
        mode: "0644"
      notify: Reload httpd

  handlers:
    - name: Reload httpd
      ansible.builtin.systemd_service:
        name: httpd
        state: reloaded
```

### 3.2 The rules

| Rule | Consequence |
|---|---|
| Only a `changed` result notifies | `ok`, `skipped`, and `failed` tasks never trigger handlers |
| Handlers run at the end of the **play**, after all tasks | Not after each task, and not at the end of the playbook |
| A handler runs **once** per play and host, however many tasks notified it | Three config changes, one restart |
| Handlers run in the order of the `handlers:` section | The order of `notify` lines is irrelevant |
| `notify` matches the handler name exactly | A typo in the name fails the play with `handler ... not found` |
| Handler names must be unique within a play | With duplicates only the first runs |

### 3.3 Several handlers and topics

`notify` accepts a list. For groups of handlers that always go together, use a **topic** with `listen`:

```yaml
      notify: Web config changed

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
```

Because handlers run in section order, the check runs before the reload. If the configuration is broken, the check fails, the reload never runs, and httpd keeps serving with the last good configuration. That ordering is a safety net, not a style choice.

An even earlier safety net is the `validate` argument of `copy`, `template`, and `lineinfile`, which tests the new file before it replaces the old one: `validate: /usr/sbin/visudo -cf %s` for sudoers files.

### 3.4 Reload or restart

| Action | Effect | Use for |
|---|---|---|
| `state: reloaded` | Rereads configuration, keeps connections | Configuration file changes |
| `state: restarted` | Stops and starts the service | Package upgrades, module changes, changes a reload does not pick up |

### 3.5 Running handlers earlier

```yaml
    - name: Pending handlers run now
      ansible.builtin.meta: flush_handlers

    - name: Status page answers locally
      ansible.builtin.uri:
        url: http://localhost/server-status?auto
```

`meta: flush_handlers` runs every handler notified so far, at that point in the play. Use it when a later task depends on the restarted service.

### 3.6 Handlers and failures

If a task fails on a host after a handler was notified, the play stops for that host **and the handler does not run**. On the next run, the task that notified it reports `ok` (the file is already changed), so the handler is never notified again: the change is on disk but never applied. This is the lost notification trap.

Solutions:

* `force_handlers: true` on the play (or `--force-handlers` on the command line) runs already notified handlers even when a later task fails;
* `flush_handlers` directly after the critical change;
* a `block` with `rescue` that handles the failure.

### 3.7 Making commands notify honestly

A `command` task always reports `changed`, so it would notify on every run. Tie its `changed` status to its output:

```yaml
- name: SELinux labels are correct
  ansible.builtin.command: restorecon -Rv /srv/drop
  register: relabel
  changed_when: "'Relabeled' in relabel['stdout']"
  notify: Restart app
```

---

## 4. Failure Handling

### 4.1 Default behavior

A failed task removes that host from the rest of the play (other hosts continue) and marks the play as failed. The recap counts `failed`; the exit code of `ansible-playbook` or `ansible-navigator` is nonzero.

### 4.2 Tolerating a failure: `ignore_errors`

```yaml
- name: Optional agent is installed when available
  ansible.builtin.dnf:
    name: telemetry-agent
    state: present
  ignore_errors: true
```

The failure is printed with `...ignoring`, counted under `ignored`, and the play continues. Use it only when failure truly does not matter: ignoring a failed required package makes the play report success on a broken host. ansible-lint flags it (`ignore-errors`); `# noqa: ignore-errors` documents that it is intentional. `ignore_errors` does not cover connection failures; `ignore_unreachable: true` does.

### 4.3 Redefining failure and change

| Keyword | Meaning | Example |
|---|---|---|
| `failed_when: EXPRESSION` | Fail when the expression is true, regardless of return code | `failed_when: root_fs['stdout'] not in ['xfs', 'ext4']` |
| `failed_when: false` | Never fail (use the result later) | Probes and checks |
| `changed_when: EXPRESSION` | Report `changed` only when true | `changed_when: "'Relabeled' in relabel['stdout']"` |
| `changed_when: false` | Never report changed | Read only commands such as `date`, `findmnt`, `getent` |

Several conditions in a list are combined with AND, exactly like `when`.

### 4.4 Failing on purpose: `fail` and `assert`

```yaml
- name: Log host meets the requirements
  ansible.builtin.assert:
    that:
      - ansible_facts['memtotal_mb'] >= log_min_ram_mb | int
      - ansible_facts['distribution'] == 'RedHat'
    fail_msg: "{{ inventory_hostname }} does not meet the log server requirements"
    success_msg: "{{ inventory_hostname }} meets the log server requirements"

- name: Stop when the package choice is invalid
  ansible.builtin.fail:
    msg: "install_package must be one of {{ valid_packages }}"
  when: install_package is not defined or install_package not in valid_packages
```

`assert` states the condition that must be **true** and fails otherwise; `fail` needs a `when` describing the **bad** case. `assert` is usually clearer. Both put validation at the start of a play (fail fast), before anything changes.

### 4.5 Blocks

A `block` groups tasks. Keywords set on the block (`when`, `become`, `vars`, `tags`) apply to every task in it. With `rescue` and `always`, a block becomes a try, recover, finally structure:

```yaml
- name: Configuration comes from the central source when possible
  block:
    - name: Central configuration is downloaded
      ansible.builtin.get_url:
        url: "{{ config_url }}"
        dest: /etc/labapp/labapp.conf
        mode: "0644"
  rescue:
    - name: Explain the failure
      ansible.builtin.debug:
        msg: "{{ ansible_failed_task['name'] }} failed: {{ ansible_failed_result['msg'] }}"
    - name: Default configuration is written instead
      ansible.builtin.copy:
        content: "listen_port = 8080\n"
        dest: /etc/labapp/labapp.conf
        mode: "0644"
  always:
    - name: Status file is written in every case
      ansible.builtin.copy:
        content: "deployed\n"
        dest: /etc/labapp/status
        mode: "0644"
```

| Section | Runs when |
|---|---|
| `block` | Always, first |
| `rescue` | Only if a task in `block` failed |
| `always` | After `block` and `rescue`, whatever happened |

If `rescue` succeeds, the host is **not** failed: the recap counts it under `rescued` and the play continues. Inside `rescue`, `ansible_failed_task` and `ansible_failed_result` describe what went wrong. If `rescue` itself fails, or there is no `rescue`, `always` still runs and then the host fails.

### 4.6 Play level controls

| Keyword | Effect |
|---|---|
| `force_handlers: true` | Notified handlers run even after a failure |
| `any_errors_fatal: true` | A failure on any host stops the play for all hosts |
| `max_fail_percentage: 20` | Stop the play when more than 20 percent of hosts fail |
| `ignore_unreachable: true` | Continue past hosts that cannot be reached |

### 4.7 Traps

| Trap | Symptom |
|---|---|
| `ignore_errors` on a required task | Green recap, broken host |
| Handler notified, later task fails, rerun | Change never applied (lost notification) |
| `failed_when` referring to a key the module did not return | Template error instead of a clean failure |
| Reading `ansible_failed_result` outside `rescue` | Undefined |
| Expecting `rescue` to run for a skipped task | Skipped is not failed |

---

## 5. Chapter Checklist

* [ ] Loop over a list, a list of dictionaries, and a dictionary.
* [ ] Know which modules take a list directly and which need `loop`.
* [ ] Shorten loop output with `label`; register a loop and read `results`.
* [ ] Convert any `with_` loop to `loop`.
* [ ] Write `when` with facts, group membership, lists, `in`, `is defined`, and version tests.
* [ ] Convert strings with `| int` before numeric comparisons.
* [ ] Use `notify`, `listen`, and `flush_handlers`, and predict handler order.
* [ ] Explain and avoid the lost notification trap.
* [ ] Use `changed_when` and `failed_when` to make commands honest.
* [ ] Validate input with `assert` and stop with `fail`.
* [ ] Build `block`, `rescue`, `always` and read `ansible_failed_result`.

## 6. Exam Rules From This Chapter

1. Pass lists to `dnf` instead of looping it.
2. `when` never contains `{{ }}`.
3. Convert with `| int` before comparing numbers you did not type yourself.
4. Every read only `command` gets `changed_when: false`.
5. Every configuration change that needs a restart notifies a handler; nothing else restarts services.
6. Handler names in `notify` are copied, not retyped.
7. Put `flush_handlers` before tasks that test a restarted service.
8. Validate prerequisites with `assert` at the start of the play.
9. Use `ignore_errors` only where a failure is genuinely harmless.
10. After any run with a failure, check whether a handler was notified and never ran.

**Next:** Chapter 5 builds on these task control features.

<!-- navfoot:start -->

---

← Previous: [Chapter 03 Lab Solution: `variables_review`](../03_variables/06_lab_solution.md) | Next: [Guided Exercise: Apply a Baseline with Loops and Conditions](01_guided_exercise_control_flow.md) →

<!-- navfoot:end -->
