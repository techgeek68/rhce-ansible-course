<!-- nav:start -->
[Course home](../README.md) › [Chapter 06: Automation at Scale](README.md) › Quiz (4 of 6)
<!-- nav:end -->

# Chapter 06 Quiz: Imports, Includes, and Host Patterns

Answer every question before opening any answer. Target: 11 of 12.

---

**1.** A task file name must be built from `ansible_facts['distribution']`. Which statement works?

* A. `ansible.builtin.import_tasks: "tasks/{{ ansible_facts['distribution'] }}.yml"`
* B. `ansible.builtin.include_tasks: "tasks/{{ ansible_facts['distribution'] }}.yml"`
* C. `ansible.builtin.import_playbook: "tasks/{{ ansible_facts['distribution'] }}.yml"`
* D. None; file names cannot contain variables.

<details><summary>Answer</summary>

**B.** Facts exist only at run time; imports are resolved at parse time. (README section 2.1)
</details>

---

**2.** Which statement can take a `loop`?

* A. `import_tasks`
* B. `include_tasks`
* C. `import_playbook`
* D. All three

<details><summary>Answer</summary>

**B.** (Section 2.1)
</details>

---

**3.** A task file sets `setup_done: true` in its first task. It is brought in with `when: setup_done is not defined`. With `import_tasks`, what happens to its second task?

* A. It runs.
* B. It is skipped, because the copied condition is evaluated again for each task and is now false.
* C. The play fails.
* D. It runs twice.

<details><summary>Answer</summary>

**B.** With `include_tasks` the condition is evaluated once and both tasks run. (Section 2.5)
</details>

---

**4.** `tasks/broken.yml` contains a YAML error. Which statement makes `--syntax-check` report it?

* A. `include_tasks: tasks/broken.yml`
* B. `import_tasks: tasks/broken.yml`
* C. Both
* D. Neither

<details><summary>Answer</summary>

**B.** Imports are parsed up front; an include is read only when reached during the run. (Section 2.1)
</details>

---

**5.** Where may `ansible.builtin.import_playbook` appear?

* A. Inside `tasks:`
* B. Inside `handlers:`
* C. At the top level of a playbook, beside plays
* D. In a task file

<details><summary>Answer</summary>

**C.** (Section 2.2)
</details>

---

**6.** An included task file uses `loop` with `item`. The include itself loops over services. What should you add to the include?

* A. `loop_control: label: ...`
* B. `loop_control: loop_var: svc_name`, and use `svc_name` in the file
* C. `with_items`
* D. Nothing

<details><summary>Answer</summary>

**B.** Two loops sharing `item` overwrite each other. (Section 2.4)
</details>

---

**7.** `--tags hardening` runs a tagged `include_tasks`, but no task inside the file runs. What is missing?

* A. `apply: tags: [hardening]` on the include
* B. `import: true`
* C. Tags cannot be used with includes.
* D. `--list-tags`

<details><summary>Answer</summary>

**A.** Tags on an include apply only to the include task itself. (Section 2.6)
</details>

---

**8.** Which pattern selects hosts that are in `frontend` and also in `east`?

* A. `frontend,east`
* B. `'frontend,&east'`
* C. `'frontend,!east'`
* D. `frontend:east`

<details><summary>Answer</summary>

**B.** A and D are unions; C is an exclusion. (Section 3.1)
</details>

---

**9.** The inventory has groups `db` and `datacenter` and hosts `db1.east.example.com`, `web1.east.example.com`. What does `'d*'` select?

* A. Only `db1.east.example.com`
* B. Every host in the groups `db` and `datacenter`, because wildcards match group names too
* C. Nothing; wildcards need a domain.
* D. Only groups, no hosts

<details><summary>Answer</summary>

**B.** (Section 3.2)
</details>

---

**10.** `portal.lab.example.com ansible_host=192.168.250.10` is in the inventory. Which pattern selects it?

* A. `'192.168.250.*'`
* B. `'portal*'`
* C. `192.168.250.10`
* D. All of them

<details><summary>Answer</summary>

**B.** Patterns match inventory names; `ansible_host` only changes where Ansible connects. (Section 3.5)
</details>

---

**11.** A play says `hosts: web`. You run it with `--limit db`. What happens?

* A. It runs on web and db hosts.
* B. It runs on db hosts only.
* C. No hosts match, because `--limit` can only narrow `hosts:`.
* D. It fails with a syntax error.

<details><summary>Answer</summary>

**C.** Only hosts in both web and db would run. (Section 3.4)
</details>

---

**12.** Which pattern selects only the first host of group `web`, in inventory order?

* A. `web[1]`
* B. `'web[0]'`
* C. `web:first`
* D. `'web[-0]'`

<details><summary>Answer</summary>

**B.** Subscripts start at 0; `web[-1]` is the last host. (Section 3.1)
</details>

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Select Exactly the Right Hosts](02_guided_exercise_scale_hosts.md) | Next: [Chapter 06 Lab: Refactor an Inherited Playbook](04_lab.md) →

<!-- navfoot:end -->
