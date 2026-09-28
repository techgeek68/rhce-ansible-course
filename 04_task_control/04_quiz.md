<!-- nav:start -->
[Course home](../README.md) › [Chapter 04: Task Control](README.md) › Quiz (5 of 7)
<!-- nav:end -->

# Chapter 04 Quiz: Loops, Conditionals, Handlers, and Failures

Answer every question before opening any answer. Target: 11 of 12.

---

**1.** You must install ten packages. Which is best?

* A. Ten tasks, one per package
* B. One `dnf` task with `loop` over the ten names
* C. One `dnf` task with `name:` set to the list of ten names
* D. One `command` task running `dnf install -y` with the ten names

<details><summary>Answer</summary>

**C.** `dnf` accepts a list and installs everything in one transaction. B works but runs dnf ten times; D is not idempotent. (README section 1.1)
</details>

---

**2.** `params` is a dictionary. Which loop works?

* A. `loop: "{{ params }}"`
* B. `loop: "{{ params | dict2items }}"` with `item['key']` and `item['value']`
* C. `loop: "{{ params.items }}"`
* D. `with_items: "{{ params }}"`

<details><summary>Answer</summary>

**B.** `loop` needs a list; `dict2items` converts the dictionary into a list of key and value pairs. (Section 1.3)
</details>

---

**3.** A looping `command` task registers `lookups`. Where is the return code of the second item after the task?

* A. `lookups['rc'][1]`
* B. `lookups['results'][1]['rc']`
* C. `lookups[1]['rc']`
* D. `item['rc']`

<details><summary>Answer</summary>

**B.** Looping tasks store one result per item in `results`. (Section 1.7)
</details>

---

**4.** Which `when` is correct?

* A. `when: "{{ ansible_facts['memtotal_mb'] }} > 1024"`
* B. `when: ansible_facts['memtotal_mb'] > 1024`
* C. `when: {{ ansible_facts['memtotal_mb'] > 1024 }}`
* D. `when: ansible_facts[memtotal_mb] > 1024`

<details><summary>Answer</summary>

**B.** `when` is already an expression; no braces. D lacks quotes around the key. (Section 2.1)
</details>

---

**5.** `ansible_facts['distribution_major_version']` is `"10"`. What does `ansible_facts['distribution_major_version'] >= "9"` return?

* A. true
* B. false, because string comparison is alphabetical and "1" sorts before "9"
* C. An error
* D. It depends on the locale

<details><summary>Answer</summary>

**B.** Convert with `| int` before comparing numbers. (Section 2.4)
</details>

---

**6.** Which condition runs a task only on hosts that are members of group db?

* A. `when: inventory_hostname == 'db'`
* B. `when: "'db' in group_names"`
* C. `when: groups == 'db'`
* D. `when: db is defined`

<details><summary>Answer</summary>

**B.** `group_names` lists the current host's groups. (Section 2.2)
</details>

---

**7.** Three tasks in a play report `changed` and each notifies `Restart httpd`. How often does the handler run, and when?

* A. Three times, after each task
* B. Once, after the last task that notified it
* C. Once, after all tasks of the play have finished
* D. Once, at the end of the playbook

<details><summary>Answer</summary>

**C.** Handlers run once per play and host, after the task list, unless `flush_handlers` runs them earlier. (Section 3.2)
</details>

---

**8.** A handlers section lists `Check config` then `Reload service`, both with `listen: Config changed`. A task notifies `Config changed`, and the configuration is broken. What happens?

* A. Reload runs first, then the check fails.
* B. The check fails, and the reload does not run.
* C. Both run in parallel.
* D. Nothing runs because `listen` requires a `name` match.

<details><summary>Answer</summary>

**B.** Handlers run in section order; a failing handler stops the remaining handlers for that host. (Section 3.3)
</details>

---

**9.** A task changes a configuration file and notifies a handler. A later task fails. You fix the later task and rerun. The handler never runs. Why?

* A. Handlers only run on the first run.
* B. On the rerun, the configuration task reports `ok`, so nothing notifies the handler; the first notification was lost when the play stopped.
* C. The handler name is wrong.
* D. Handlers do not run after a rerun without `--check`.

<details><summary>Answer</summary>

**B.** Prevent it with `force_handlers: true`, `--force-handlers`, or `flush_handlers`. (Section 3.6)
</details>

---

**10.** Which keyword makes a read only command stop reporting `changed`?

* A. `failed_when: false`
* B. `changed_when: false`
* C. `ignore_errors: true`
* D. `check_mode: true`

<details><summary>Answer</summary>

**B.** (Section 4.3)
</details>

---

**11.** A task inside `block` fails, and the `rescue` tasks succeed. How does the host appear in the recap?

* A. `failed=1`
* B. `rescued=1` and `failed=0`; the play continues for that host
* C. `ignored=1`
* D. `unreachable=1`

<details><summary>Answer</summary>

**B.** A successful rescue clears the failure. (Section 4.5)
</details>

---

**12.** You must stop a play early when a host has less than 1024 MiB of RAM, with a clear message. Which is most direct?

* A. `ignore_errors: true` on a memory task
* B. `ansible.builtin.assert` with `that: ansible_facts['memtotal_mb'] >= 1024` and a `fail_msg`
* C. `changed_when: ansible_facts['memtotal_mb'] < 1024`
* D. `when: ansible_facts['memtotal_mb'] >= 1024` on every task

<details><summary>Answer</summary>

**B.** `assert` states the requirement and fails with your message when it does not hold. D silently skips work instead of failing. (Section 4.4)
</details>

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Decide What Failure Means](03_guided_exercise_control_errors.md) | Next: [Chapter 04 Lab: Central Logging with Task Control](05_lab.md) →

<!-- navfoot:end -->
