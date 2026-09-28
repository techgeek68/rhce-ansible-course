<!-- nav:start -->
[Course home](../README.md) › [Chapter 07: Roles and Content Collections](README.md) › Quiz (5 of 7)
<!-- nav:end -->

# Chapter 07 Quiz: Roles and Collections

Answer every question before opening any answer. Target: 11 of 12.

---

**1.** A role sets `vhost_port: 80` in `vars/main.yml`. The play sets `vars: vhost_port: 8008` and uses the role in a `roles:` section without parameters. Which port does the role use?

* A. 8008
* B. 80
* C. An error for the duplicate definition
* D. Whichever file was read last

<details><summary>Answer</summary>

**B.** Role `vars/main.yml` outranks play vars. Move tunables to `defaults/main.yml`. (README section 1.2)
</details>

---

**2.** Which file validates the types of the variables a role receives, before any role task runs?

* A. `meta/main.yml`
* B. `meta/argument_specs.yml`
* C. `defaults/main.yml`
* D. `tests/test.yml`

<details><summary>Answer</summary>

**B.** (Section 2.3)
</details>

---

**3.** A play contains `tasks:` first, then a `roles:` section below it. What runs first?

* A. The tasks, because they are written first
* B. The roles
* C. They run interleaved
* D. Ansible refuses the play

<details><summary>Answer</summary>

**B.** Order: pre_tasks, roles, tasks, post_tasks, regardless of file order. (Section 1.4)
</details>

---

**4.** You need to call the same role three times with a loop over sites. Which form works?

* A. `roles:` with `loop`
* B. `import_role` with `loop`
* C. `include_role` with `loop`
* D. `meta: dependencies` with `loop`

<details><summary>Answer</summary>

**C.** Only the dynamic include accepts a loop. (Section 1.3)
</details>

---

**5.** `ansible-galaxy role install -r roles/requirements.yml` without `-p` and without `roles_path` in `ansible.cfg`. Where do the roles go, and what is the consequence with navigator?

* A. `./roles`; everything works
* B. `~/.ansible/roles`; the execution environment cannot see them
* C. `/etc/ansible/roles`; needs root
* D. The current directory

<details><summary>Answer</summary>

**B.** Set `roles_path = ./roles` or use `-p roles`. (Section 3.2)
</details>

---

**6.** Which requirements entry installs tag `v1.0.0` of a role from a Git server?

* A. `- src: http://git.example.com/team/motd.git`
* B. `- src: http://git.example.com/team/motd.git` with `scm: git` and `version: v1.0.0`
* C. `- name: motd` with `version: v1.0.0`
* D. `- git: motd@v1.0.0`

<details><summary>Answer</summary>

**B.** Git sources need `scm: git`; `version` takes a tag, branch, or commit. (Section 3.3)
</details>

---

**7.** You change a pinned role from `v1.0.0` to `v1.1.0` in the requirements file and run the install again. It says the role is already installed. What next?

* A. Delete the requirements file.
* B. Run the install again with `--force`.
* C. Nothing; the new version is active.
* D. Rename the role.

<details><summary>Answer</summary>

**B.** (Section 3.3)
</details>

---

**8.** `collections_path = ./collections:/usr/share/ansible/collections`. Both directories contain `redhat.rhel_system_roles`, versions 1.108 and 1.95. Which is used?

* A. 1.108, from `./collections`, because it comes first in the path
* B. The newer version, always
* C. 1.95, because system content wins
* D. Ansible fails with a conflict

<details><summary>Answer</summary>

**A.** The first match in the path wins; the other copy is shadowed. (Section 4.3)
</details>

---

**9.** How should a playbook use the timesync role that comes with a collection?

* A. `roles: [timesync]`
* B. `ansible.builtin.include_role: name: redhat.rhel_system_roles.timesync`
* C. `redhat.rhel_system_roles.timesync:` as a module
* D. `import_playbook: timesync`

<details><summary>Answer</summary>

**B.** Collection roles are called by FQCN through `include_role` or `import_role`. (Section 4.5)
</details>

---

**10.** On a control node without internet access, where do you find example playbooks for the RHEL system roles?

* A. `/etc/ansible/examples/`
* B. `/usr/share/doc/rhel-system-roles/ROLE/`
* C. `~/.ansible/roles/`
* D. Only on the web

<details><summary>Answer</summary>

**B.** (Section 5.1)
</details>

---

**11.** Which variable set makes the selinux system role allow httpd to listen on TCP 8181?

* A. `selinux_booleans: [{name: http_port, state: 8181}]`
* B. `selinux_ports: [{ports: ["8181"], proto: tcp, setype: http_port_t, state: present}]`
* C. `selinux_fcontexts: [{target: 8181, setype: http_port_t}]`
* D. `selinux_state: permissive`

<details><summary>Answer</summary>

**B.** D would work only by weakening security, which is never the answer. (Section 5.2)
</details>

---

**12.** Why should a role called `vhost` name its variables `vhost_port` rather than `port`?

* A. Ansible requires it.
* B. Variables share one global namespace per play; prefixes prevent collisions between roles, and ansible-lint enforces them.
* C. Prefixed variables have higher precedence.
* D. It makes the role run faster.

<details><summary>Answer</summary>

**B.** (Section 1.2)
</details>

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Install Collections and Use RHEL System Roles](03_guided_exercise_roles_collections.md) | Next: [Chapter 07 Lab: Team Development Portal from Roles and Collections](05_lab.md) →

<!-- navfoot:end -->
