<!-- nav:start -->
[Course home](../README.md) › [Chapter 05: Deploying and Managing Files](README.md) › Quiz (4 of 6)
<!-- nav:end -->

# Chapter 05 Quiz: Files and Templates

Answer every question before opening any answer. Target: 11 of 12.

---

**1.** `copy` with `src: site/` and `dest: /var/www/html/`. What ends up on the host?

* A. `/var/www/html/site/` with the files inside
* B. The files from `site/` directly in `/var/www/html/`
* C. An error: directories need `synchronize`
* D. A single file named `site`

<details><summary>Answer</summary>

**B.** A trailing slash on `src` copies the directory's contents. Without it, the directory itself is created in `dest`. (README section 1.2)
</details>

---

**2.** This task adds a duplicate line on every run. Why?

```yaml
- ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#PermitRootLogin'
    line: PermitRootLogin no
```

* A. `lineinfile` is never idempotent.
* B. After the first run the commented line is gone, the regexp matches nothing, and the line is appended again.
* C. The path is wrong.
* D. `state: present` is missing.

<details><summary>Answer</summary>

**B.** Use `'^#?PermitRootLogin'` so the regexp matches both the old and the new line. (Section 1.4)
</details>

---

**3.** Two `blockinfile` tasks write to the same file with the default marker. What happens?

* A. Both blocks coexist.
* B. They overwrite each other on every run, because both find the same `ANSIBLE MANAGED BLOCK` markers.
* C. The second task fails.
* D. The file is duplicated.

<details><summary>Answer</summary>

**B.** Give each block its own `marker`. (Section 1.5)
</details>

---

**4.** `/etc/issue.net` is a regular file. A task uses `file` with `src: /etc/issue`, `dest: /etc/issue.net`, `state: link`. What happens?

* A. The link is created.
* B. The task fails unless `force: true` is added.
* C. The file is copied instead.
* D. A hard link is created.

<details><summary>Answer</summary>

**B.** (Section 1.3)
</details>

---

**5.** Which `mode` value produces `rw-r--r--`?

* A. `mode: 644`
* B. `mode: "0644"`
* C. `mode: "644"` in a YAML list
* D. `mode: 0o644`

<details><summary>Answer</summary>

**B.** Unquoted 644 is the decimal number 644. A quoted string, or the symbolic form `u=rw,g=r,o=r`, is safe. (Section 1.3)
</details>

---

**6.** You need files in `/var/log` whose content changed in the last three days. Which `find` argument?

* A. `age: 3d`
* B. `age: -3d`
* C. `size: 3d`
* D. `recurse: 3`

<details><summary>Answer</summary>

**B.** A negative age means newer than; a positive age means older than. (Section 1.8)
</details>

---

**7.** A playbook runs `fetch` with `flat: true` and `dest: collected/sshd_config` against four hosts. What is in `collected/` afterwards?

* A. Four files, one per host
* B. One file, from whichever host was written last
* C. Four directories named after the hosts
* D. Nothing; `flat` needs one host

<details><summary>Answer</summary>

**B.** Include `{{ inventory_hostname }}` in the name, or omit `flat` to get per host directories. (Section 1.9)
</details>

---

**8.** Where does the `template` module look for `src: motd.j2` when no path is given?

* A. `/etc/ansible/templates/`
* B. In the `templates/` directory next to the playbook, then the playbook directory itself
* C. Only in the current shell directory
* D. On the managed host

<details><summary>Answer</summary>

**B.** (Section 2.1)
</details>

---

**9.** Which line in `sshd_config.j2` correctly marks the rendered file as managed?

* A. `{{ ansible_managed }}`
* B. `# {{ ansible_managed }}`
* C. `{# ansible_managed #}`
* D. `{% ansible_managed %}`

<details><summary>Answer</summary>

**B.** The string needs the file's comment character. C is a Jinja2 comment and renders nothing. (Section 2.2)
</details>

---

**10.** A template loops over `groups['all']` and reads `hostvars[host]['ansible_facts']['default_ipv4']['address']`. The play targets only `web`. What happens for hosts outside `web`?

* A. Their addresses are read from DNS.
* B. The template fails, because no facts were gathered for those hosts in this run.
* C. They are silently skipped.
* D. Ansible gathers their facts automatically.

<details><summary>Answer</summary>

**B.** Gather facts for all hosts first, for example in a play targeting `all`. (Section 2.5)
</details>

---

**11.** What does `{{ app_port | default(8080) }}` render when `app_port` is defined as an empty string?

* A. 8080
* B. An empty string
* C. An error
* D. 0

<details><summary>Answer</summary>

**B.** `default` only replaces undefined values. `default(8080, true)` also replaces empty ones. (Section 2.6)
</details>

---

**12.** Which expression lists every other host in the inventory, sorted and comma separated?

* A. `{{ groups['all'] | join(',') }}`
* B. `{{ groups['all'] | difference([inventory_hostname]) | sort | join(',') }}`
* C. `{{ hostvars | join(',') }}`
* D. `{{ group_names | difference(inventory_hostname) }}`

<details><summary>Answer</summary>

**B.** `difference` removes the current host; `sort` and `join` format the rest. (Section 2.6)
</details>

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Render Host Specific Files with Jinja2](02_guided_exercise_files_templates.md) | Next: [Chapter 05 Lab: Node Profiles, Login Banners, and Cleanup](04_lab.md) →

<!-- navfoot:end -->
