<!-- nav:start -->
[Course home](../README.md) › [Chapter 07: Roles and Content Collections](README.md) › Lesson (1 of 7)

**Pages in this chapter, in study order:**

1. Lesson: this page
2. Guided exercise: [Guided Exercise: Write a Reusable Role](01_guided_exercise_roles_create.md)
3. Guided exercise: [Guided Exercise: Install Pinned Roles from an Archive and from Git](02_guided_exercise_roles_external.md)
4. Guided exercise: [Guided Exercise: Install Collections and Use RHEL System Roles](03_guided_exercise_roles_collections.md)
5. Quiz: [Chapter 07 Quiz: Roles and Collections](04_quiz.md)
6. Graded lab: [Chapter 07 Lab: Team Development Portal from Roles and Collections](05_lab.md)
7. Lab solution: [Chapter 07 Lab Solution: `roles_review`](06_lab_solution.md)
<!-- nav:end -->

# Chapter 07: Roles and Content Collections

| | |
|---|---|
| **Goal** | Package automation as roles, consume roles and collections from archives, Git, and hubs, and use RHEL system roles |
| **Study time** | About 7 hours including exercises |
| **Activities** | [04_quiz.md](04_quiz.md), three guided exercises, [05_lab.md](05_lab.md) (graded) |
| **Lab prerequisite** | Chapter 06 complete; `community.general` and `ansible.posix` tarballs on materials.example.com ([lab build guide](../00_lab_setup/README.md) Step 6.2) |

---

## 0. Chapter Map

| Section | After it you can | Practice |
|---|---|---|
| 1. Role Anatomy | Name every role directory, what Ansible does with it, and how role variables rank | [04_quiz.md](04_quiz.md) |
| 2. Writing a Role | Create a role skeleton, fill it, validate its input, and call it several ways | [01_guided_exercise_roles_create.md](01_guided_exercise_roles_create.md) |
| 3. Roles from Archives and Git | Install pinned role versions with a requirements file and upgrade them deliberately | [02_guided_exercise_roles_external.md](02_guided_exercise_roles_external.md) |
| 4. Content Collections | Install collections from archives and hubs, understand search paths and shadowing, use modules and roles by FQCN | [03_guided_exercise_roles_collections.md](03_guided_exercise_roles_collections.md) |
| 5. RHEL System Roles | Find, read, and apply `redhat.rhel_system_roles` roles such as timesync and selinux | [03_guided_exercise_roles_collections.md](03_guided_exercise_roles_collections.md) |
| Review | Everything together | [05_lab.md](05_lab.md) |

**EX294 objectives this chapter supports** (verify against the current list):

* Create roles; download roles from an Ansible Galaxy compatible source and use them.
* Install and use content collections; use requirements files for roles and collections.
* Use RHEL system roles: install the RHEL system roles package and create playbooks that use them (timesync, selinux, and others).

---

## 1. Role Anatomy

### 1.1 What a role is

A role is a directory with a **fixed layout** that bundles everything one piece of automation needs: tasks, handlers, variables, defaults, files, templates, and metadata. Because the layout is fixed, Ansible knows where to find each part, and the role can move between projects, be versioned in its own Git repository, and be shared.

```
roles/vhost/
    defaults/main.yml       lowest precedence variables: the knobs users turn
    vars/main.yml           high precedence variables: internal constants
    tasks/main.yml          the entry point; may include other task files in tasks/
    handlers/main.yml       handlers available to the play once the role is loaded
    templates/              searched first by template tasks inside the role
    files/                  searched first by copy and script tasks inside the role
    meta/main.yml           author, license, platforms, dependencies
    meta/argument_specs.yml input validation and documentation of variables
    README.md               how to use the role
    tests/                  inventory and playbook for testing the role
```

Only the directories you use need to exist. Delete empty ones: they suggest behavior that is not there.

### 1.2 Role variables and precedence

| Location | Rank (Chapter 3 table) | Use for |
|---|---|---|
| `defaults/main.yml` | Lowest of all | Every value a caller may want to change |
| Inventory, `group_vars`, `host_vars` | Middle | Site specific values |
| Play `vars`, `vars_files` | Above inventory | Values for this play |
| `vars/main.yml` | Above play vars | Constants the role relies on (package names per platform) |
| Task `vars` on `include_role` / `import_role` | Above role vars | Values for this call |
| Role parameters in a `roles:` entry | Near the top | Values for this call |
| `-e` | Top | One off overrides |

The consequence people trip over: a value in `vars/main.yml` **silently beats** play vars and inventory. If users are meant to change something, it belongs in `defaults/main.yml`.

Prefix role variables with the role name (`vhost_port`, not `port`). Variables are global to the play, so short names collide between roles; `ansible-lint` enforces the prefix (`var-naming[no-role-prefix]`).

Never put secrets in a role. The caller passes them, typically from vault encrypted `group_vars`.

### 1.3 Three ways to call a role

```yaml
- name: Roles section, classic form
  hosts: web
  roles:
    - role: vhost
      vhost_name: main            # role parameter

- name: Static import as a task
  hosts: web
  tasks:
    - name: Main site
      ansible.builtin.import_role:
        name: vhost
      vars:
        vhost_name: main

- name: Dynamic include as a task
  hosts: web
  tasks:
    - name: Documentation site
      ansible.builtin.include_role:
        name: vhost
      vars:
        vhost_name: docs
        vhost_port: 8008
```

| | `roles:` | `import_role` | `include_role` |
|---|---|---|---|
| When processed | Parse time | Parse time | When reached |
| Runs | Before `tasks:`, whatever the file order | Where it is written | Where it is written |
| `when` | Copied to every role task | Copied to every role task | Evaluated once |
| `loop` | No | No | Yes |
| Role defaults and handlers visible to the rest of the play | Yes | Yes, even to earlier tasks | Only after the include ran (`public: true` to expose vars) |

Use `import_role` or `include_role` in `tasks:`: the order is exactly what you read. Reserve the `roles:` section for plays that consist only of roles.

A role listed twice in `roles:` with **identical** parameters runs once. Different parameters, or `allow_duplicates: true` in the role's `meta/main.yml`, run it again. Calls through `include_role` always run.

### 1.4 Play section order

When a play has everything, Ansible runs:

1. `pre_tasks`, then handlers they notified
2. `roles`
3. `tasks`, then handlers notified by roles and tasks
4. `post_tasks`, then handlers they notified

The order in the file does not matter; the guided exercise writes the sections backwards to prove it. If you find yourself needing `pre_tasks` and `post_tasks`, switch to `import_role` inside `tasks:` instead.

### 1.5 Dependencies

`meta/main.yml` can list roles that must run first:

```yaml
dependencies:
  - role: infra.httpd
    httpd_banner: Portal host
```

Dependencies run before the role that needs them, once per parameter set. For a dependency that must also be **installable** by `ansible-galaxy`, write it in requirements format (`name`, `src`, `scm`, `version`); Ansible uses `name` at run time. Keep dependency chains short: each level makes the role harder to reason about and test.

---

## 2. Writing a Role

### 2.1 The skeleton

```bash
ansible-galaxy role init roles/vhost
rm -rf roles/vhost/tests roles/vhost/files      # remove what you will not use
```

`role init` creates every standard directory with a `main.yml` and a `README.md`. The name you give is the directory name, and the directory name is the role name.

### 2.2 Content

Inside a role, relative `src:` paths resolve to the role's own `templates/` and `files/`, and `notify` finds the role's handlers:

```yaml
- name: Virtual host configuration for {{ vhost_name }}
  ansible.builtin.template:
    src: vhost.conf.j2                  # roles/vhost/templates/vhost.conf.j2
    dest: /etc/httpd/conf.d/{{ vhost_name }}.conf
    mode: "0644"
  notify: Restart httpd                 # roles/vhost/handlers/main.yml
```

Task names in the output are prefixed with the role name: `TASK [vhost : Virtual host configuration for docs]`.

### 2.3 Documenting and validating input

`meta/argument_specs.yml` describes each variable. Ansible validates the input **before** the role's tasks run, and `ansible-doc -t role` shows it as documentation:

```yaml
argument_specs:
  main:
    short_description: One Apache virtual host per call
    options:
      vhost_name:
        type: str
        required: true
        description: Short name of the site.
      vhost_port:
        type: int
        default: 80
        description: TCP port the virtual host listens on.
```

A call with `vhost_port: abc` fails immediately with `argument 'vhost_port' is of type str and we were unable to convert to int`, instead of producing a broken Apache configuration half way through.

`meta/main.yml` holds `galaxy_info` (author, description, license, platforms, `min_ansible_version` quoted as a string) and `dependencies`. Fill it: it is what people and tools read first.

### 2.4 Design rules

| Rule | Why |
|---|---|
| One purpose per role | Easier to reuse and test; combine small roles in playbooks |
| Every tunable in `defaults/main.yml` | Callers can override it anywhere |
| Constants in `vars/main.yml` | Protected from accidental override |
| Variables prefixed with the role name | No collisions in the global variable space |
| No secrets, no host names | The role stays shareable |
| One Git repository per role, tagged versions | Callers pin exact versions |
| `README.md` and `argument_specs.yml` kept current | The role documents itself |

---

## 3. Roles from Archives and Git

### 3.1 Where roles come from

| Source | Typical use | Trust |
|---|---|---|
| Your own Git server | Roles written by your organization | Yours to review |
| Private automation hub | Curated and certified content inside the organization | Recommended for production |
| Red Hat Ansible automation hub | Certified and validated collections | Supported by Red Hat and partners |
| Ansible Galaxy (galaxy.ansible.com) | Community roles and collections | Review before use; no support |
| Archive files | Air gapped transfers, exam style delivery | As trustworthy as their origin |

### 3.2 Where Ansible looks for roles

In order: a `roles/` directory next to the playbook, the directories in `roles_path` (default `~/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles`), then the playbook directory itself.

`ansible-galaxy role install` writes to the **first** directory of `roles_path` unless you pass `-p`. With `roles_path = ./roles` in `ansible.cfg`, installs land in the project, where `ansible-navigator` can see them. The default `~/.ansible/roles` is **not** mounted into the execution environment.

### 3.3 The requirements file

`roles/requirements.yml`:

```yaml
---
- name: labteam.shell_env               # local name of the role
  src: shell_env.tar                    # archive: relative path, file://, or http(s) URL

- name: labteam.motd
  src: http://utility.lab.example.com:3000/student/labteam.motd.git
  scm: git                              # required for Git sources
  version: v1.0.0                       # tag, branch, or commit hash

- name: somerole
  src: someauthor.somerole              # a Galaxy name
  version: "2.3.1"
```

```bash
ansible-galaxy role install -r roles/requirements.yml            # into roles_path[0]
ansible-galaxy role install -r roles/requirements.yml -p roles    # explicit target
ansible-galaxy role list
ansible-galaxy role remove labteam.motd
```

**Always pin `version` for Git roles.** Without it you get whatever the default branch contains today, and a colleague installing next week gets something else.

Changing `version` and running `install` again only warns that the role is already installed. Upgrades are explicit: add `--force`.

### 3.4 Reading a role before using it

Look at `README.md`, `defaults/main.yml` (every value you can override), `meta/argument_specs.yml`, `meta/main.yml` (dependencies, platforms), and the tasks. For third party roles, read the tasks fully: a role runs with the privileges you give the play.

---

## 4. Content Collections

### 4.1 What a collection contains

A collection packages modules, plugins (filters, lookups, inventory sources), roles, and documentation under a two part name `namespace.collection`. Everything inside is addressed by FQCN: module `community.general.timezone`, role `redhat.rhel_system_roles.timesync`, filter `ansible.utils.ipaddr`.

### 4.2 Installing

```bash
ansible-galaxy collection install community.general                         # from configured servers
ansible-galaxy collection install ./community-general-10.1.0.tar.gz -p collections
ansible-galaxy collection install http://materials.example.com/collections/ansible-posix-2.0.0.tar.gz -p collections
ansible-galaxy collection install git+https://git.example.com/org/coll.git,v1.2.0 -p collections
ansible-galaxy collection install -r collections/requirements.yml -p collections
ansible-galaxy collection list
```

`collections/requirements.yml`:

```yaml
---
collections:
  - name: http://materials.example.com/collections/community-general-10.1.0.tar.gz
  - name: ansible.posix
    version: ">=1.5.0"
  - name: git+https://git.example.com/org/coll.git
    version: main
```

A requirements file can list both kinds at once: top level keys `roles:` and `collections:`.

### 4.3 Search path and shadowing

```ini
[defaults]
collections_path = ./collections:/usr/share/ansible/collections
```

Directories are searched in order, and the **first** copy of a collection wins; later copies with the same name are shadowed. In this course the project `./collections` comes first, then the system and execution environment location. `ansible-navigator collections` shows both copies and marks the hidden one as shadowed, which is how you notice that your project runs a different version than the image contains.

Without `-p` or a `collections_path`, `ansible-galaxy` installs into `~/.ansible/collections`, which `ansible-navigator` does not mount into the execution environment: the collection works with `ansible-playbook` and is missing in navigator.

### 4.4 Choosing sources for `ansible-galaxy`

```ini
[galaxy]
server_list = private_hub, automation_hub, galaxy

[galaxy_server.private_hub]
url = https://hub.example.com/api/galaxy/content/published/

[galaxy_server.automation_hub]
url = https://console.redhat.com/api/automation-hub/content/published/
auth_url = https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token

[galaxy_server.galaxy]
url = https://galaxy.ansible.com/
```

Keep tokens out of the file: `export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN=...` (the server name in upper case, then the key).

### 4.5 Using collection content

Modules by FQCN, always:

```yaml
- name: Time zone is set
  community.general.timezone:
    name: America/New_York
```

Roles from collections through `import_role` or `include_role` with the FQCN, not in a `roles:` section with a short name:

```yaml
- name: Chrony uses the lab time server
  ansible.builtin.include_role:
    name: redhat.rhel_system_roles.timesync
```

Documentation:

```bash
ansible-doc community.general.timezone
ansible-doc -t role redhat.rhel_system_roles.timesync        # roles with argument specs
ansible-navigator collections                                # browse inside the EE
```

For production, the collections a project needs are usually built into a custom execution environment image with `ansible-builder`, so every run uses identical content; project local collections are the development and exam workflow.

---

## 5. RHEL System Roles

### 5.1 What they are

RHEL system roles are Red Hat supported roles for common operating system configuration: `timesync`, `selinux`, `firewall`, `network`, `storage`, `crypto_policies`, `sshd`, `logging`, `kdump`, `postfix`, `podman`, and more. They work the same on RHEL 8, 9, and 10, and they hide version differences (for example ntpd versus chrony).

| Delivery | Names | Location |
|---|---|---|
| `rhel-system-roles` RPM, collection form | `redhat.rhel_system_roles.timesync` | `/usr/share/ansible/collections/ansible_collections/redhat/rhel_system_roles/` |
| `rhel-system-roles` RPM, legacy role form | `rhel-system-roles.timesync` | `/usr/share/ansible/roles/` |
| Automation hub or the supported EE | `redhat.rhel_system_roles.timesync` | Inside the collection |

```bash
sudo dnf install rhel-system-roles
ls /usr/share/ansible/roles/
ls /usr/share/doc/rhel-system-roles/
ls /usr/share/doc/rhel-system-roles/timesync/
```

`/usr/share/doc/rhel-system-roles/ROLE/` holds each role's README and **example playbooks**: on an exam with no internet, this directory is your documentation. Copy an example and adapt it.

### 5.2 Using a system role

Variables go wherever you like (`group_vars` keeps them per host group), and the role reads them:

```yaml
# group_vars/all/timesync.yml
timesync_ntp_provider: chrony
timesync_ntp_servers:
  - hostname: bastion.lab.example.com
    iburst: true
```

```yaml
- name: Time synchronization
  hosts: web
  become: true
  tasks:
    - name: Chrony uses the lab time server
      ansible.builtin.include_role:
        name: redhat.rhel_system_roles.timesync
```

The selinux role in the same way:

```yaml
selinux_state: enforcing
selinux_policy: targeted
selinux_ports:
  - ports: ["8181", "8182"]
    proto: tcp
    setype: http_port_t
    state: present
selinux_fcontexts:
  - target: "/srv/sites(/.*)?"
    setype: httpd_sys_content_t
    state: present
selinux_booleans:
  - name: httpd_can_network_connect
    state: true
    persistent: true
```

These are exactly the tasks that otherwise need `semanage` commands and extra collections.

---

## 6. Traps

| Trap | Symptom |
|---|---|
| Tunable value in `vars/main.yml` | Play and inventory values ignored |
| Role variables without a prefix | Two roles overwrite each other's settings |
| `roles:` section plus `tasks:` in one play | Roles run first regardless of file order |
| Role installed into `~/.ansible/roles` | `the role 'x' was not found` in navigator |
| Git role without `version` | Different content on every install |
| Changed `version`, no `--force` | Old version stays installed |
| Collection installed without `-p` | Works with `ansible-playbook`, missing in navigator |
| Two copies of a collection | The first in `collections_path` wins; check which |
| Collection role called by short name | Ambiguous or not found; use FQCN with `include_role` |
| System role variables misspelled | Silently ignored; copy names from the README |

---

## 7. Chapter Checklist

* [ ] Create a role with `ansible-galaxy role init` and remove unused parts.
* [ ] Place variables correctly in `defaults` and `vars`, prefixed with the role name.
* [ ] Validate role input with `meta/argument_specs.yml`.
* [ ] Call a role with `roles:`, `import_role`, and `include_role`, with parameters.
* [ ] Predict play section order with `pre_tasks`, `roles`, `tasks`, `post_tasks`.
* [ ] Declare and install a role dependency.
* [ ] Install roles from an archive and from Git with a pinned version; upgrade with `--force`.
* [ ] Install collections from archives and requirements files into the project.
* [ ] Explain collection search order and shadowing.
* [ ] Find RHEL system role documentation and examples offline, and use timesync and selinux.

## 8. Exam Rules From This Chapter

1. Set `roles_path = ./roles` (or use `-p roles`) so roles land in the project.
2. Install collections with `-p collections`, and keep `./collections` first in `collections_path`.
3. Pin every Git role with `version`.
4. Tunables in `defaults/main.yml`, constants in `vars/main.yml`.
5. Call collection roles by FQCN through `include_role` or `import_role`.
6. Read `/usr/share/doc/rhel-system-roles/ROLE/` before writing variables for a system role.
7. Keep system role variables in `group_vars` for the target group.
8. After installing anything, `ansible-galaxy role list` and `ansible-galaxy collection list` prove where it went.

**Next:** Chapter 8 builds on these roles and collections.

<!-- navfoot:start -->

---

← Previous: [Chapter 06 Lab Solution: `scale_review`](../06_scale/05_lab_solution.md) | Next: [Guided Exercise: Write a Reusable Role](01_guided_exercise_roles_create.md) →

<!-- navfoot:end -->
