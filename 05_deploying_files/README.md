<!-- nav:start -->
[Course home](../README.md) › [Chapter 05: Deploying and Managing Files](README.md) › Lesson (1 of 6)

**Pages in this chapter, in study order:**

1. Lesson: this page
2. Guided exercise: [Guided Exercise: Manage Files, Lines, Blocks, and Links](01_guided_exercise_files_manage.md)
3. Guided exercise: [Guided Exercise: Render Host Specific Files with Jinja2](02_guided_exercise_files_templates.md)
4. Quiz: [Chapter 05 Quiz: Files and Templates](03_quiz.md)
5. Graded lab: [Chapter 05 Lab: Node Profiles, Login Banners, and Cleanup](04_lab.md)
6. Lab solution: [Chapter 05 Lab Solution: `files_review`](05_lab_solution.md)
<!-- nav:end -->

# Chapter 05: Deploying and Managing Files

| | |
|---|---|
| **Goal** | Create, copy, edit, link, inspect, find, and collect files on managed hosts, and generate host specific files from Jinja2 templates |
| **Study time** | About 5 hours including exercises |
| **Activities** | [03_quiz.md](03_quiz.md), two guided exercises, [04_lab.md](04_lab.md) (graded) |
| **Lab prerequisite** | Chapter 04 complete |

---

## 0. Chapter Map

| Section | After it you can | Practice |
|---|---|---|
| 1. File Modules | Choose the right module for every file job and use each one idempotently | [01_guided_exercise_files_manage.md](01_guided_exercise_files_manage.md) |
| 2. Jinja2 Templates and Filters | Render complete files per host with variables, facts, loops, conditions, and filters | [02_guided_exercise_files_templates.md](02_guided_exercise_files_templates.md) |
| Review | Everything together | [04_lab.md](04_lab.md) |

**EX294 objectives this chapter supports** (verify against the current list):

* Use Ansible modules for system administration tasks that work with file contents.
* Create and use templates to create customized configuration files.
* Use variables and facts in templates.

---

## 1. File Modules

### 1.1 Which module for which job

| Job | Module |
|---|---|
| Put a whole file from the project on the host | `ansible.builtin.copy` |
| Put a whole file generated per host | `ansible.builtin.template` |
| Write short text directly | `ansible.builtin.copy` with `content:` |
| Create directories and links, set owner, mode, SELinux type, delete | `ansible.builtin.file` |
| Ensure one line is present, absent, or replaced | `ansible.builtin.lineinfile` |
| Manage a multi line section inside a file | `ansible.builtin.blockinfile` |
| Replace every match of a pattern | `ansible.builtin.replace` |
| Read properties of a file | `ansible.builtin.stat` |
| Search for files by name, age, size, content | `ansible.builtin.find` |
| Bring files from the host back to the control side | `ansible.builtin.fetch` |
| Mirror directory trees efficiently | `ansible.posix.synchronize` |
| Download from a URL | `ansible.builtin.get_url` |
| Unpack archives | `ansible.builtin.unarchive` |

**Rule of thumb:** own the whole file with `copy` or `template` whenever you can. Use `lineinfile` and `blockinfile` only for files you share with the operating system or other tools, such as `sshd_config` or `/etc/hosts`.

### 1.2 `copy`

```yaml
- name: Instructions file is in the drop directory
  ansible.builtin.copy:
    src: files/README.txt           # relative to the project (or playbook) directory
    dest: /srv/reports/             # trailing slash: into this directory
    owner: root
    group: reports
    mode: "0640"
```

| Argument | Effect |
|---|---|
| `src` + `dest` | Copy from the control side; idempotent by SHA1 checksum, not timestamps |
| `content` | Write this text instead of a source file |
| `src: dir/` (trailing slash) | Copy the directory's **contents** |
| `src: dir` (no slash) | Copy the directory **itself** into `dest` |
| `force: false` | Only create the file if it does not exist; never overwrite |
| `remote_src: true` | `src` is a path on the managed host (copy from host to host locally) |
| `backup: true` | Keep a timestamped copy of the replaced file on the host |
| `validate: 'CMD %s'` | Test the new file before it replaces the old one; `%s` is the temporary file |
| `owner`, `group`, `mode`, `setype` | Enforced on every run |

With `ansible-navigator`, the "control side" is the execution environment container. Your project is mounted into it, so relative paths such as `files/README.txt` work; absolute paths on workstation outside the project do not.

### 1.3 `file`

| `state` | Result |
|---|---|
| `file` | The path must already be a regular file; only attributes are managed |
| `directory` | Directory exists (parents are created) |
| `link` / `hard` | Symbolic / hard link from `dest` (or `path`) to `src` |
| `touch` | Create empty file if missing; otherwise update timestamps (reports `changed` every run unless `modification_time: preserve` and `access_time: preserve`) |
| `absent` | Remove file, link, or whole directory tree |

```yaml
- name: Drop directory keeps group ownership on new files
  ansible.builtin.file:
    path: /srv/reports
    state: directory
    owner: root
    group: reports
    mode: "2770"            # 2 = setgid on a directory: new files inherit the group

- name: Network banner links to the local banner
  ansible.builtin.file:
    src: /etc/issue
    dest: /etc/issue.net
    state: link
    force: true             # replace an existing regular file with the link
```

Notes that cost points:

* Modes may be octal strings (`"0644"`) or symbolic (`u=rw,g=r,o=r`). An unquoted `0644` is read by YAML as an octal number and works, but lint flags it; an unquoted `644` is the decimal number 644 (octal 1204) and produces wrong permissions.
* Creating a link where a **regular file** already exists fails unless `force: true`.
* `recurse: true` with `state: directory` applies owner and mode to everything below.
* `setype`, `seuser`, `serole`, `selevel` set the SELinux label directly, like `chcon`. A later `restorecon` reverts it. For permanent labels, add a policy rule (`community.general.sefcontext`, or the `redhat.rhel_system_roles.selinux` role, covered later) and let `restorecon` apply it.

### 1.4 `lineinfile`

```yaml
- name: SSH allows at most three authentication attempts
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#?MaxAuthTries'
    line: MaxAuthTries 3
    backup: true
    validate: /usr/sbin/sshd -t -f %s
  notify: Reload sshd
```

| Argument | Behavior |
|---|---|
| `line` only | Append the line if the exact line is missing |
| `regexp` + `line` | Replace the **last** line matching `regexp`; append if none matches |
| `regexp` + `state: absent` | Remove every matching line |
| `insertafter` / `insertbefore` | Where a new line goes: a regular expression, `EOF`, or `BOF` |
| `create: true` | Create the file if it is missing |
| `backrefs: true` | Use groups from `regexp` in `line`; do nothing if no match |

**Idempotency rule:** the `regexp` must match both the old line **and** the new `line`. `regexp: '^#MaxAuthTries'` matches the commented default the first time, but not `MaxAuthTries 3` afterwards, so the second run appends a duplicate. `'^#?MaxAuthTries'` matches both.

`validate` protects services from broken configuration: if `sshd -t` rejects the new file, the task fails and the old file stays in place.

### 1.5 `blockinfile`

```yaml
- name: Storage settings block
  ansible.builtin.blockinfile:
    path: /etc/sysconfig/reports
    create: true
    mode: "0644"
    marker: "# {mark} STORAGE SETTINGS"
    block: |
      REPORT_DIR=/srv/reports
      REPORT_GROUP=reports
```

The module writes the block between `# BEGIN STORAGE SETTINGS` and `# END STORAGE SETTINGS` and finds it again on later runs through these markers, so the block is updated, never duplicated.

| Need | How |
|---|---|
| Several independent blocks in one file | A different `marker` for each |
| Custom begin and end words | `marker_begin: START`, `marker_end: STOP` |
| A file with another comment syntax | `marker: "<!-- {mark} WEB -->"` for HTML, `marker: "; {mark} APP"` for INI files using `;` |
| Remove one block | Same `marker`, `state: absent` |
| Position | `insertafter` / `insertbefore`, like `lineinfile` |

Changing the marker text after deployment leaves the old block in place and adds a new one: the module can only find blocks by their current markers.

### 1.6 `replace`

`ansible.builtin.replace` substitutes **every** match of `regexp` with `replace`, anywhere in the file, including inside lines. Use it for renaming a value throughout a file; use `lineinfile` for single settings.

### 1.7 `stat`

```yaml
- name: Status of the SSH server configuration
  ansible.builtin.stat:
    path: /etc/ssh/sshd_config
    checksum_algorithm: sha256
  register: sshd_stat
```

| Key under `sshd_stat['stat']` | Meaning |
|---|---|
| `exists` | Always present; test it first |
| `isdir`, `isreg`, `islnk`, `lnk_source` | Type, and link target |
| `pw_name`, `gr_name`, `mode` | Owner, group, `"0644"` style mode |
| `size`, `mtime` | Size in bytes, modification time |
| `checksum` | SHA1 by default, or the chosen algorithm |

`get_checksum: false` skips the checksum for large files. Every key except `exists` is missing when the file does not exist, so guard with `when: sshd_stat['stat']['exists']`.

### 1.8 `find`

```yaml
- name: Find cache files older than seven days
  ansible.builtin.find:
    paths: /var/tmp/labcache
    patterns: "*.tmp"
    age: 7d
  register: stale_cache

- name: Stale cache files are removed
  ansible.builtin.file:
    path: "{{ item['path'] }}"
    state: absent
  loop: "{{ stale_cache['files'] }}"
  loop_control:
    label: "{{ item['path'] }}"
```

| Argument | Meaning |
|---|---|
| `paths` | One or more directories |
| `patterns` | Shell globs (or regular expressions with `use_regex: true`) matched against the **file name** |
| `excludes` | Names to skip |
| `contains` | Regular expression the content must match |
| `age` | `7d` = older than 7 days; `-7d` = changed within 7 days (`s`, `m`, `h`, `d`, `w`) |
| `size` | `10k` = at least 10 KiB; `-10k` = at most |
| `file_type` | `file` (default), `directory`, `link`, `any` |
| `recurse`, `hidden` | Descend into subdirectories; include dot files |

Results are in `result['files']`, a list of dictionaries with `path`, `size`, `mode`, owner, and times. `find` never changes anything; pair it with `file`, `fetch`, or `copy` in a loop.

### 1.9 `fetch`

```yaml
- name: Collect the logs into the project
  ansible.builtin.fetch:
    src: "{{ item['path'] }}"
    dest: "{{ playbook_dir }}/collected/"
  loop: "{{ found_logs['files'] }}"
```

Without `flat`, the file lands in `collected/HOSTNAME/full/source/path`, which keeps files from different hosts apart. With `flat: true`, `dest` is the exact file name (or a directory ending in `/`), so include the host name yourself when several hosts are involved:

```yaml
dest: "{{ playbook_dir }}/profiles/{{ inventory_hostname }}.conf"
flat: true
```

Using `playbook_dir` makes the destination correct both with `ansible-playbook` and inside navigator's container. `fetch` needs read access to the source: fetching root only files requires `become`.

### 1.10 `synchronize`

`ansible.posix.synchronize` wraps `rsync`: fast for large or frequently changing trees, only transfers differences, can delete extra files (`delete: true`), and can pull (`mode: pull`). `rsync` must be installed on both ends. The control end is the execution environment when you use navigator, so confirm the image contains `rsync` before relying on it; `copy` works everywhere.

### 1.11 Traps

| Trap | Symptom |
|---|---|
| `lineinfile` regexp that does not match the new line | Duplicate lines on every run |
| Unquoted `644` mode | Permissions `--w----r-T` (octal 1204) |
| Link over an existing regular file | `refusing to convert from file to symlink` without `force: true` |
| `file: state=touch` in a baseline | Never idempotent |
| `stat` keys used without checking `exists` | Undefined variable error on hosts without the file |
| `fetch` of many hosts with `flat: true` and a fixed name | Every host overwrites the same file |
| `setype` expected to survive `restorecon` | Label reverts |

---

## 2. Jinja2 Templates and Filters

### 2.1 Why templates

`lineinfile` and `blockinfile` patch files; a template **is** the file. You write the complete file once, with placeholders and logic, and the `template` module renders a different, complete result for each host. Idempotency comes free: the rendered text is compared with the current file, and nothing changes when they match.

```yaml
- name: Login banner describes the host
  ansible.builtin.template:
    src: motd.j2                 # found in templates/ automatically
    dest: /etc/motd
    owner: root
    group: root
    mode: "0644"
```

`template` accepts the same `owner`, `group`, `mode`, `setype`, `backup`, and `validate` arguments as `copy`. Templates end in `.j2` by convention only.

### 2.2 Delimiters

| Syntax | Purpose | Example |
|---|---|---|
| `{{ ... }}` | Insert the value of an expression | `{{ ansible_facts['fqdn'] }}`, `{{ port + 10 }}` |
| `{% ... %}` | Logic: `for`, `if`, `set` | `{% if 'web' in group_names %}` |
| `{# ... #}` | Comment that never reaches the rendered file | `{# rendered per host #}` |

Mark generated files so nobody edits them by hand. `ansible_managed` inserts a configurable string; write the file's comment character in front of it:

```jinja
# {{ ansible_managed }}
```

In ansible-core 2.16 (the version in the course's execution environment and in RHEL 9) the text comes from `ansible_managed = ...` in `[defaults]` of `ansible.cfg`. Newer ansible-core releases deprecate that setting; there you define `ansible_managed` as an ordinary variable, for example in `group_vars/all.yml`, and templates stay unchanged.

### 2.3 Loops and conditions

```jinja
{% if 'web' in group_names %}
Role:    web server. Report issues to {{ support['web'] }}
{% elif 'db' in group_names %}
Role:    database server. Report issues to {{ support['db'] }}
{% else %}
Role:    unassigned
{% endif %}
Addresses:
{% for addr in ansible_facts['all_ipv4_addresses'] | sort %}
  {{ loop.index }}. {{ addr }}
{% endfor %}
```

| Inside a `for` | Value |
|---|---|
| `loop.index` / `loop.index0` | Position starting at 1 / at 0 |
| `loop.first`, `loop.last` | Booleans for the first and last item |
| `loop.length` | Number of items |
| `{% for u in users if u != 'root' %}` | Filter items inline |
| `{% for k, v in settings \| dictsort %}` | Iterate a dictionary by sorted key |
| `{% else %}` inside `for` | Rendered when the list is empty |

Every `if` needs `{% endif %}`, every `for` needs `{% endfor %}`. Jinja2 logic works in **templates**; in playbooks use `loop` and `when`, although `{{ }}` expressions with filters work in both.

### 2.4 Whitespace

The `template` module enables `trim_blocks` by default: the newline right after a `{% %}` or `{# #}` tag is removed, so logic lines leave no empty lines. Indentation before a tag is kept unless you set `lstrip_blocks: true` on the task or use a dash inside the tag:

| Syntax | Removes |
|---|---|
| `{%- ... %}` | Whitespace and newlines **before** the tag |
| `{% ... -%}` | Whitespace and newlines **after** the tag |
| `lstrip_blocks: true` (task argument) | Spaces and tabs before block tags on their line |

When a rendered file has unexpected blank lines or joined lines, whitespace control is the reason nine times out of ten.

### 2.5 Data from other hosts

```jinja
{% for host in groups['all'] | sort %}
{{ hostvars[host]['ansible_facts']['default_ipv4']['address'] }} {{ host }}{{ '  # this host' if host == inventory_hostname else '' }}
{% endfor %}
```

This works only when facts were gathered for every host in `groups['all']` during this run. The simplest guarantee is a play targeting `all` with fact gathering on.

The inline `X if CONDITION else Y` expression keeps optional text on the same line without breaking whitespace.

### 2.6 Filters

A filter transforms a value: `{{ value | filter(arguments) }}`. Filters chain from left to right.

| Category | Filter | Example and result |
|---|---|---|
| Missing values | `default` | `{{ app_port \| default(8080) }}` gives 8080 when undefined |
| | `default(x, true)` | Also replaces empty strings and empty lists |
| | `mandatory` | Fails with a clear error when undefined |
| | `omit` | `mode: "{{ file_mode \| default(omit) }}"` leaves the argument out entirely |
| Strings | `lower`, `upper`, `capitalize`, `trim` | `{{ app_name \| lower }}` |
| | `replace` | `{{ path \| replace('/', '_') }}` |
| | `regex_replace`, `regex_search` | `{{ ver \| regex_replace('^v', '') }}` |
| | `basename`, `dirname` | `{{ '/etc/ssh/sshd_config' \| basename }}` gives `sshd_config` |
| Numbers | `int`, `float`, `round(1)`, `abs` | `{{ (memtotal_mb / 1024) \| round(1) }}` |
| Lists | `join(',')`, `sort`, `unique`, `length`, `first`, `last`, `min`, `max` | `{{ admins \| join(',') }}` |
| | `difference`, `union`, `intersect` | `{{ groups['all'] \| difference([inventory_hostname]) }}` |
| | `map(attribute='x')`, `selectattr('k', 'equalto', v)`, `reject` | `{{ users \| map(attribute='name') \| list }}` |
| | `flatten` | Nested lists into one |
| Dictionaries | `dict2items`, `items2dict`, `combine`, `dictsort` | `{{ defaults \| combine(overrides) }}` |
| Booleans | `bool`, `ternary('on', 'off')` | `{{ debug \| bool \| ternary('on', 'off') }}` |
| Data formats | `to_json`, `to_nice_json`, `to_yaml`, `to_nice_yaml` | Serialize a variable into a file |
| | `from_json`, `from_yaml` | Parse command output: `{{ out['stdout'] \| from_json }}` |
| Encoding | `b64encode`, `b64decode`, `hash('sha256')` | |
| Passwords | `password_hash('sha512')` | Hash for `user: password=` |

`map`, `select`, `selectattr`, and `reject` return generators in some contexts; add `| list` when you need an actual list.

### 2.7 Previewing a template

```bash
ansible-navigator run site_files.yml --check --diff          # shows the rendered differences
```

or render without deploying:

```yaml
- name: Preview the banner
  ansible.builtin.debug:
    msg: "{{ lookup('ansible.builtin.template', 'motd.j2') }}"
```

### 2.8 Template or edit?

| Situation | Use |
|---|---|
| You own the whole file | `template` |
| The file belongs to a package and receives upstream updates | `lineinfile` / `blockinfile`, or a drop in file in a `.d` directory rendered with `template` |
| One setting in a large vendor file | `lineinfile` with `validate` |
| A section you add to a shared file | `blockinfile` with its own marker |

### 2.9 Traps

| Trap | Symptom |
|---|---|
| `{{ ansible_managed }}` without a comment character | Configuration syntax error in the rendered file |
| `hostvars[...]['ansible_facts']` for hosts outside the play | Undefined facts |
| Missing `{% endif %}` / `{% endfor %}` | `Unexpected end of template` |
| Blank lines around logic | Whitespace control, see 2.4 |
| `default` on a variable that exists but is empty | Empty value kept unless `default(x, true)` |
| Unquoted `{{` at the start of a YAML value in the playbook | YAML error (only playbooks; inside `.j2` files quoting is not needed) |

---

## 3. Chapter Checklist

* [ ] Copy files, directories, and inline content with owner, mode, and `validate`.
* [ ] Create directories, symbolic links (including over existing files), and setgid directories.
* [ ] Change one setting with `lineinfile` so that reruns report `ok`.
* [ ] Manage two independent blocks in one file and remove one of them.
* [ ] Read file properties with `stat` safely.
* [ ] Find files by pattern, age, and size, then act on the results.
* [ ] Fetch files into a tree and into flat per host names.
* [ ] Write a template with `ansible_managed`, facts, `if`, and `for`.
* [ ] Build output from other hosts' facts with `hostvars`.
* [ ] Apply `default`, `join`, `round`, `difference`, `ternary`, `to_nice_yaml`, and `from_json`.
* [ ] Control whitespace in rendered files.

## 4. Exam Rules From This Chapter

1. Quote every file mode.
2. Prefer `template` or `copy` for whole files; use `lineinfile` for single settings in vendor files.
3. A `lineinfile` regexp must match the line it writes.
4. Add `validate` when a broken file could lock you out (`sshd`, `sudoers`).
5. Use `force: true` to turn an existing file into a link.
6. Guard `stat` results with `exists`.
7. `find` age: positive is older than, negative is newer than.
8. Include the host name in `fetch` destinations when using `flat: true`.
9. Start templated configuration files with a comment containing `ansible_managed`.
10. Preview templates with `--check --diff` before the real run.

**Next:** Chapter 6 builds on these file skills.

<!-- navfoot:start -->

---

← Previous: [Chapter 04 Lab Solution: `control_review`](../04_task_control/06_lab_solution.md) | Next: [Guided Exercise: Manage Files, Lines, Blocks, and Links](01_guided_exercise_files_manage.md) →

<!-- navfoot:end -->
