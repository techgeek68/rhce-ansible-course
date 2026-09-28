<!-- nav:start -->
[Course home](../README.md) › [Chapter 06: Automation at Scale](README.md) › Lesson (1 of 6)

**Pages in this chapter, in study order:**

1. Lesson: this page
2. Guided exercise: [Guided Exercise: Assemble a Playbook from Reusable Files](01_guided_exercise_scale_files.md)
3. Guided exercise: [Guided Exercise: Select Exactly the Right Hosts](02_guided_exercise_scale_hosts.md)
4. Quiz: [Chapter 06 Quiz: Imports, Includes, and Host Patterns](03_quiz.md)
5. Graded lab: [Chapter 06 Lab: Refactor an Inherited Playbook](04_lab.md)
6. Lab solution: [Chapter 06 Lab Solution: `scale_review`](05_lab_solution.md)
<!-- nav:end -->

# Chapter 06: Automation at Scale

| | |
|---|---|
| **Goal** | Split growing projects into reusable playbook and task files, choose correctly between static imports and dynamic includes, and target exactly the right hosts with host patterns |
| **Study time** | About 4 hours including exercises |
| **Activities** | [03_quiz.md](03_quiz.md), two guided exercises, [04_lab.md](04_lab.md) (graded) |
| **Lab prerequisite** | Chapter 05 complete |

---

## 0. Chapter Map

| Section | After it you can | Practice |
|---|---|---|
| 1. Structuring a Project | Lay out playbooks, task files, variable files, and verification plays so each piece has one job | [01_guided_exercise_scale_files.md](01_guided_exercise_scale_files.md) |
| 2. Importing and Including | Predict how imports and includes treat conditions, loops, tags, errors, and handlers | [01_guided_exercise_scale_files.md](01_guided_exercise_scale_files.md) |
| 3. Host Patterns at Scale | Select hosts by name, group, wildcard, regular expression, position, set logic, and file; connect through `ansible_host` | [02_guided_exercise_scale_hosts.md](02_guided_exercise_scale_hosts.md) |
| Review | Refactor an inherited monolithic playbook | [04_lab.md](04_lab.md) |

**EX294 objectives this chapter supports** (verify against the current list):

* Create playbooks to configure systems to a specified state, reusing task files and playbooks.
* Create and use static inventories to define groups of hosts, and select hosts with patterns.
* Use variables and facts, including variable files loaded at run time.

---

## 1. Structuring a Project

A single playbook that configures packages, services, firewall, content, users, and tests for four roles quickly reaches hundreds of lines. Split it by **responsibility**:

```
project/
    site.yml                  entry point: plays that only import or include
    tasks/
        packages.yml          one job each, parameterized with variables
        service.yml
        firewall.yml
        profiles/
            basic.yml         alternatives chosen at run time
            health.yml
    vars/
        RedHat.yml            platform specific values
        default.yml
    plays/
        verify.yml            reusable complete plays
```

| Benefit | Why |
|---|---|
| Readability | `site.yml` becomes a table of contents |
| Reuse | One `service.yml` serves httpd, firewalld, and any future service |
| Safer changes | A fix in one task file reaches every playbook that uses it |
| Parallel work | Teams edit different files; fewer merge conflicts |

A reusable task file documents its **parameters** in a comment at the top and never hard codes the values that callers should choose.

The next step after task files is **roles**, a standard directory layout that packages tasks, handlers, templates, defaults, and variables together. Everything in this chapter carries over to roles.

---

## 2. Importing and Including

### 2.1 The two families

| | Import (static) | Include (dynamic) |
|---|---|---|
| Modules | `ansible.builtin.import_playbook`, `ansible.builtin.import_tasks` | `ansible.builtin.include_tasks`, `ansible.builtin.include_vars` |
| Processed | When the playbook is parsed, before anything runs | When execution reaches the task |
| Missing file or syntax error | Fails immediately, even with `--syntax-check` | Fails only when the include is reached |
| Variable in the file name | Only if known at parse time (play vars, `-e`, vars files) | Anything, including facts and registered results |
| `loop` | Not allowed | Allowed |
| `when` on the statement | Copied to **every** imported task, evaluated per task | Evaluated **once**, decides whether the file is loaded |
| Tags on the statement | Inherited by every imported task | Apply to the include task only (use `apply:` to pass them on) |
| `--list-tasks`, `--start-at-task` | See the individual tasks | See only the include task |
| Notifying a handler defined in the file | By the handler's own name | Only by the include's name |

Choose **import** by default: it is predictable, fully visible to tooling, and fails early. Choose **include** when you need something only known at run time: a loop, a file name built from facts, or a file that should not even be read on some hosts.

`include` (without `_tasks`) is the old combined keyword; it was deprecated in 2.4 and removed in later versions. Convert it when you meet it.

### 2.2 Importing playbooks

```yaml
---
- name: Web tier
  ansible.builtin.import_playbook: plays/web.yml

- name: Database tier
  ansible.builtin.import_playbook: plays/db.yml

- name: Verification
  ansible.builtin.import_playbook: plays/verify.yml
```

`import_playbook` sits at the **top level**, beside plays, never inside a play. The imported plays run in the order they appear, and normal plays can be mixed in between. The entry playbook of a large project often contains nothing else.

### 2.3 Importing and including tasks

```yaml
  tasks:
    - name: Packages are installed
      ansible.builtin.import_tasks: tasks/packages.yml
      vars:
        pkgs:
          - httpd
          - firewalld

    - name: Profile specific content is deployed
      ansible.builtin.include_tasks: "tasks/profiles/{{ web_profile }}.yml"
```

A task file is a plain YAML **list of tasks**: no `hosts`, no `tasks:` key. Relative paths are resolved from the directory of the file that contains the import, then from the playbook directory, so `tasks/web_tasks.yml` can import `install_and_enable.yml` sitting beside it.

`vars:` on the import or include statement passes parameters. Inside the task file, give optional parameters defaults: `state: "{{ pkg_state | default('present') }}"`.

### 2.4 Looping over a task file

```yaml
    - name: Services run and start at boot
      ansible.builtin.include_tasks: tasks/service.yml
      loop:
        - httpd
        - firewalld
      loop_control:
        loop_var: svc_name
```

Only includes can loop. Rename the loop variable with `loop_var`: if the included file has its own `loop`, both loops would otherwise fight over `item`, and Ansible warns that the outer value is overwritten.

### 2.5 Conditions: the classic surprise

`tasks/once.yml`:

```yaml
- name: Record that setup ran
  ansible.builtin.set_fact:
    setup_done: true

- name: Second task of the file
  ansible.builtin.debug:
    msg: The second task ran
```

| Statement | Result |
|---|---|
| `import_tasks: tasks/once.yml` with `when: setup_done is not defined` | Task 1 runs and defines `setup_done`; task 2 inherits the same `when`, now false, and is **skipped** |
| `include_tasks: tasks/once.yml` with `when: setup_done is not defined` | Condition checked once before loading; **both** tasks run |

Whenever a task file changes the facts its own condition depends on, use `include_tasks`.

### 2.6 Tags and other keywords on includes

```yaml
- name: Hardening tasks, run as root and tagged
  ansible.builtin.include_tasks:
    file: tasks/hardening.yml
    apply:
      become: true
      tags:
        - hardening
  tags:
    - hardening
```

The `tags` on the statement make the include itself run when `--tags hardening` is used; `apply` pushes `become` and the tag into every task inside. With `import_tasks` neither step is needed: keywords are copied to each task automatically.

### 2.7 Loading variables at run time

```yaml
- name: Platform specific variables are loaded
  ansible.builtin.include_vars:
    file: "{{ lookup('ansible.builtin.first_found', platform_files) }}"
  vars:
    platform_files:
      files:
        - "{{ ansible_facts['distribution'] }}-{{ ansible_facts['distribution_major_version'] }}.yml"
        - "{{ ansible_facts['distribution'] }}.yml"
        - default.yml
      paths:
        - vars
```

`first_found` returns the first file that exists: most specific first, a safe default last. `include_vars` values sit high in precedence (above play `vars` and `vars_files`), so they reliably win over generic defaults.

### 2.8 Traps

| Trap | Symptom |
|---|---|
| `import_tasks` with a file name from a fact | `Could not find or access` or undefined variable at parse time |
| `loop` on `import_tasks` | `You cannot use loops on 'import_tasks' statements` |
| Included file with its own `loop`, no `loop_var` on the include | Warning about `item` already in use; wrong values |
| `when` on an import where the tasks change the tested value | Later tasks of the file silently skipped |
| `--start-at-task` naming a task inside an include | The task is never found |
| Tagged include without `apply` | `--tags` runs the include but none of its tasks |
| `import_playbook` indented inside a play | `'ansible.builtin.import_playbook' is not a valid attribute for a Play` or unknown task error |

---

## 3. Host Patterns at Scale

Chapter 2 introduced patterns; this section covers everything the exam and real inventories need.

### 3.1 Reference

| Pattern | Selects |
|---|---|
| `all`, `'*'` | Every host |
| `web` | Group members, including hosts of child groups |
| `ungrouped` | Hosts only in `all` |
| `web1.east.example.com`, `192.168.250.200` | That inventory entry (IP addresses only if written as such in the inventory) |
| `'*.east.example.com'`, `'192.168.250.*'` | Wildcard over **inventory names and group names** |
| `web,db` (or `web:db`) | Union |
| `'frontend,&east'` | Intersection: in frontend **and** in east |
| `'datacenter,!db'` | Exclusion: in datacenter but not in db |
| `'~(web\|api)1\..*'` | Regular expression (starts with `~`) |
| `'web[0]'`, `'web[-1]'`, `'east[1:2]'` | Position within a group, in inventory order; slices include both ends |
| `--limit @limit.txt` | Hosts listed one per line in a file |

Set operators apply in a fixed order: all unions first, then every `&`, then every `!`, wherever they appear in the list. `'!db,datacenter'` means the same as `'datacenter,!db'`.

Commas are preferred over colons as separators, because colons also appear in IPv6 addresses.

### 3.2 Wildcards also match groups

The pattern `'d*'` matches the host `db1...` **and** the groups `db` and `datacenter`, and therefore every host inside them. Wildcards do not know whether a name belongs to a host, an IP entry, or a group. Anchor wildcards on something only hostnames contain, such as the domain: `'*.lab.example.com'`.

### 3.3 Quoting

YAML treats `*` (alias), `&` (anchor), and `!` (tag) specially at the start of a value; the shell treats `*`, `!`, `&`, `~`, and brackets specially. Quote every pattern that contains them, in playbooks and on the command line:

```yaml
hosts: '!legacy,all'
```

```bash
ansible-navigator run site.yml --limit 'east,&web'
```

### 3.4 `hosts` versus `--limit`

`hosts:` defines the maximum set a play may touch; `--limit` narrows it for one run and can never widen it. A common safe design: `hosts: all` (or a broad group) in the playbook, and `--limit` for staged rollouts:

```bash
ansible-navigator run site.yml --limit 'web[0]'       # canary: first web server only
ansible-navigator run site.yml --limit web             # then the rest
```

Always preview the selection first:

```bash
ansible-navigator run site.yml --list-hosts --limit 'datacenter,!db'
ansible 'datacenter,!db' --list-hosts                  # quicker with plain ansible
```

### 3.5 Inventory names versus connection addresses

The inventory name is a label; connection variables decide where Ansible actually connects:

```ini
[lab]
portal.lab.example.com ansible_host=192.168.250.10
admin.lab.example.com  ansible_host=serverb.lab.example.com ansible_port=22
```

| Variable | Purpose |
|---|---|
| `ansible_host` | Address or DNS name to connect to |
| `ansible_port` | SSH port (default 22) |
| `ansible_user` | Login user for this host |

Patterns always match the **inventory name**: `'192.168.250.*'` does not select `portal.lab.example.com`, although it connects to 192.168.250.10. Use `ansible_host` when DNS does not resolve the name you want to use, when a host has several addresses, or when a firewall requires a specific one; keep it in `host_vars/NAME.yml` in larger projects.

### 3.6 Traps

| Trap | Symptom |
|---|---|
| Unquoted pattern starting with `*`, `&`, or `!` in YAML | `found undefined alias`, anchor, or tag errors |
| Wildcard catching a group name | More hosts than expected; check with `--list-hosts` |
| IP pattern for a host listed by name | No hosts matched |
| Expecting `--limit` to add hosts | It only narrows `hosts:` |
| Subscripts on groups whose order changed | Different hosts selected; subscripts follow inventory order |

---

## 4. Chapter Checklist

* [ ] Split a playbook into an entry file, task files, variable files, and a verification play.
* [ ] Pass parameters to task files with `vars:`, and give optional ones defaults.
* [ ] Explain for each keyword (`when`, `loop`, tags, file name variables) how import and include differ.
* [ ] Loop over an included task file with a custom `loop_var`.
* [ ] Load platform specific variables with `include_vars` and `first_found`.
* [ ] Write patterns with unions, intersections, exclusions, wildcards, regular expressions, and subscripts.
* [ ] Preview every pattern with `--list-hosts`.
* [ ] Connect to hosts through `ansible_host` and `ansible_port`.

## 5. Exam Rules From This Chapter

1. `import_playbook` only at the top level.
2. Import by default; include for loops, run time file names, and conditions that must be evaluated once.
3. Every reusable task file names its parameters in a comment.
4. Use `loop_var` whenever you loop over an include.
5. Quote host patterns containing `*`, `&`, `!`, `~`, or brackets.
6. Anchor wildcards on the domain, not on short prefixes that match group names.
7. Run `--list-hosts` before running any playbook with a new pattern.
8. Narrow with `--limit`; never edit `hosts:` for a one off run.

**Next:** Chapter 7 builds on this structure.

<!-- navfoot:start -->

---

← Previous: [Chapter 05 Lab Solution: `files_review`](../05_deploying_files/05_lab_solution.md) | Next: [Guided Exercise: Assemble a Playbook from Reusable Files](01_guided_exercise_scale_files.md) →

<!-- navfoot:end -->
