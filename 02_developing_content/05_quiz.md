<!-- nav:start -->
[Course home](../README.md) › [Chapter 02: Developing Automation Content](README.md) › Quiz (6 of 8)
<!-- nav:end -->

# Chapter 02 Quiz: Inventories, Playbooks, and Troubleshooting

Answer every question before opening any answer. Target: 11 of 12.

---

**1.** Given this inventory, which hosts does `ansible 'web:&prod' --list-hosts` print?

```ini
[web]
server[a:c].lab.example.com

[prod]
serverc.lab.example.com
serverd.lab.example.com
```

* A. servera, serverb, serverc, serverd
* B. serverc
* C. servera, serverb
* D. serverd

<details><summary>Answer</summary>

**B.** `:&` is intersection: hosts in web **and** prod. Only serverc is in both. (README section 1.7)
</details>

---

**2.** An inventory contains `app[01:03].example.com`. Which command succeeds?

* A. `ansible-inventory -i inventory --host app1.example.com`
* B. `ansible-inventory -i inventory --host app01.example.com`
* C. `ansible-inventory -i inventory --host app[01].example.com`
* D. All of them

<details><summary>Answer</summary>

**B.** Leading zeros in the range are part of the generated names, so the hosts are app01, app02, app03. (Section 1.3)
</details>

---

**3.** servera is listed at the top of the inventory before any `[group]` header, and in no group. Which groups is it a member of?

* A. None
* B. `all` only
* C. `all` and `ungrouped`
* D. `ungrouped` only

<details><summary>Answer</summary>

**C.** Every host is in `all`; hosts in no other group are also in `ungrouped`. (Section 1.2)
</details>

---

**4.** Why does Ansible warn about the group name `db-servers`?

* A. Group names must be uppercase.
* B. Hyphens are invalid in group names because group names must also be usable as variable names.
* C. Group names cannot contain the word servers.
* D. It does not warn.

<details><summary>Answer</summary>

**B.** Use `db_servers`. (Section 1.2)
</details>

---

**5.** Which line causes a YAML syntax error?

* A. `msg: "Status: online"`
* B. `msg: Status online`
* C. `msg: Status: online`
* D. `msg: 'Status: online'`

<details><summary>Answer</summary>

**C.** A colon followed by a space inside an unquoted value looks like a new key. Quote the value. (Section 2.1)
</details>

---

**6.** You want to see which lines of `/etc/httpd/conf/httpd.conf` a template task would change, without changing anything. Which command?

* A. `ansible-navigator run site.yml --syntax-check`
* B. `ansible-navigator run site.yml --check --diff`
* C. `ansible-navigator run site.yml --list-tasks`
* D. `ansible-navigator run site.yml -vvv`

<details><summary>Answer</summary>

**B.** Check mode predicts changes; diff mode shows the content differences. (Section 2.5)
</details>

---

**7.** A play runs with `ansible-navigator`, has no `remote_user`, and `ansible.cfg` has no `remote_user`. The inventory sets `ansible_user=devops` for serverb. As whom does Ansible log in to serverb and to serverc?

* A. devops on both
* B. devops on serverb, root on serverc
* C. student on both
* D. root on both

<details><summary>Answer</summary>

**B.** The inventory variable applies only to serverb. With nothing else set, the execution environment default login user is root. (Section 3.2)
</details>

---

**8.** A play logs in as devops with `become: true` and `become_user: student`. It fails with `Failed to set permissions on the temporary files Ansible needs to create when becoming an unprivileged user`. What is missing on the managed host?

* A. The student account
* B. The `acl` package providing `setfacl`
* C. A sudoers rule for root
* D. Python

<details><summary>Answer</summary>

**B.** When becoming an unprivileged user, Ansible uses ACLs to share its temporary module files. (Section 3.2)
</details>

---

**9.** Which task stays `ok` on its second run?

* A. `ansible.builtin.shell: echo "banner" >> /etc/motd`
* B. `ansible.builtin.command: useradd deploy`
* C. `ansible.builtin.lineinfile: path=/etc/motd line=banner` (expanded form)
* D. `ansible.builtin.command: systemctl enable --now httpd`

<details><summary>Answer</summary>

**C.** `lineinfile` adds the line only if it is missing. A appends every run, B fails on the second run, D reports `changed` every run. (Section 3.4)
</details>

---

**10.** A `command` task must run only while `/tmp/import.csv` exists, because the command deletes it. Which argument?

* A. `creates: /tmp/import.csv`
* B. `removes: /tmp/import.csv`
* C. `changed_when: /tmp/import.csv`
* D. `chdir: /tmp`

<details><summary>Answer</summary>

**B.** `removes` skips the task when the file is already gone. `creates` is the opposite. (Section 3.4)
</details>

---

**11.** A playbook fails with `UNREACHABLE! ... developer@serverb: Permission denied (publickey)`. The project `ansible.cfg` says `remote_user = devops`. Where do you look first?

* A. The sudoers file on serverb
* B. A `remote_user: developer` in the play, or an `ansible_user=developer` inventory variable
* C. The firewall on serverb
* D. The Python interpreter on serverb

<details><summary>Answer</summary>

**B.** The name before `@` is the login user actually used. Something with higher precedence than `ansible.cfg` set it. Privilege and Python problems appear only after a successful login. (Sections 4.2 and 4.7)
</details>

---

**12.** Which ad hoc command installs `tree` on every host in group db with privilege escalation?

* A. `ansible db -m ansible.builtin.dnf -a 'name=tree state=present'`
* B. `ansible db -b -m ansible.builtin.dnf -a 'name=tree state=present'`
* C. `ansible db -b -a 'dnf install tree'`
* D. `ansible-playbook db -m dnf tree`

<details><summary>Answer</summary>

**B.** `-b` enables become. A lacks escalation; C uses the command module and is not idempotent; D is not valid syntax. (Section 4.8)
</details>

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Diagnose and Repair Broken Automation](04_guided_exercise_develop_troubleshoot.md) | Next: [Chapter 02 Lab: Inventory, Repair, Build, and Verify](06_lab.md) →

<!-- navfoot:end -->
