<!-- nav:start -->
[Course home](../README.md) › [Chapter 03: Variables, Facts, and Secrets](README.md) › Quiz (5 of 7)
<!-- nav:end -->

# Chapter 03 Quiz: Variables, Facts, and Vault

Answer every question before opening any answer. Target: 11 of 12.

---

**1.** `motd_banner` is defined in `group_vars/all.yml`, in `group_vars/prod.yml`, in `host_vars/serverd.lab.example.com.yml`, and in the play's `vars:`. serverd is in group prod. Which value does serverd use?

* A. group_vars/all.yml
* B. group_vars/prod.yml
* C. host_vars/serverd.lab.example.com.yml
* D. The play's vars

<details><summary>Answer</summary>

**D.** Play `vars` outrank every inventory source, including `host_vars`. Only `-e` would beat them. (README section 1.4)
</details>

---

**2.** The inventory lists `serverd.lab.example.com`. Which file does Ansible read for its host variables?

* A. `host_vars/serverd.yml`
* B. `host_vars/serverd.lab.example.com.yml`
* C. `host_vars/serverd.lab.example.com.vars`
* D. `vars/serverd.lab.example.com.yml`

<details><summary>Answer</summary>

**B.** The file name must match the inventory name exactly, plus `.yml` (or a directory with that name). (Section 1.3)
</details>

---

**3.** Which task line is a YAML error?

* A. `name: "{{ pkg }}"`
* B. `dest: /srv/{{ app }}/conf`
* C. `name: {{ pkg }}`
* D. `msg: Installing {{ pkg }}`

<details><summary>Answer</summary>

**C.** A value that starts with `{{` must be quoted, otherwise YAML reads a dictionary. B and D start with other characters. (Section 1.5)
</details>

---

**4.** Why prefer `data['items']` over `data.items`?

* A. Dot notation is slower.
* B. `items` is also a Python dictionary method, so dot notation can return the method instead of your value.
* C. Dot notation is not allowed in templates.
* D. There is no difference.

<details><summary>Answer</summary>

**B.** (Section 1.7)
</details>

---

**5.** You run `ansible-navigator run users.yml -e uid=7010`. What is the type of `uid` inside the play?

* A. Integer
* B. String
* C. Float
* D. It depends on the module

<details><summary>Answer</summary>

**B.** `key=value` extra vars are strings. Use JSON (`-e '{"uid": 7010}'`) to keep types. (Section 1.6)
</details>

---

**6.** In an ad hoc `setup` result you see `ansible_default_ipv4`. How do you write that value in a playbook in the recommended form?

* A. `ansible_default_ipv4.address`
* B. `ansible_facts['ansible_default_ipv4']['address']`
* C. `ansible_facts['default_ipv4']['address']`
* D. `facts['default_ipv4']['address']`

<details><summary>Answer</summary>

**C.** Inside `ansible_facts` the `ansible_` prefix is dropped. A still works while `inject_facts_as_vars` is true, but it is the old style. (Sections 2.2, 2.3)
</details>

---

**7.** A play first copies `/etc/ansible/facts.d/app.fact` to a host and then, in the next task, uses `ansible_facts['ansible_local']['app']`. It fails with an undefined variable. Why?

* A. Custom facts must be JSON.
* B. Facts were gathered at the start of the play, before the file existed; run `setup` again.
* C. The file must be executable.
* D. Custom facts only work with `ansible-playbook`.

<details><summary>Answer</summary>

**B.** Add a `setup` task with `filter: ansible_local` after creating the file. (Section 2.5)
</details>

---

**8.** A static INI custom fact contains `enabled = true`. What does `ansible_facts['ansible_local']['app']['deploy']['enabled']` hold?

* A. The boolean `true`
* B. The string `"true"`
* C. The integer `1`
* D. Nothing; INI values are ignored

<details><summary>Answer</summary>

**B.** INI fact values are strings. (Section 2.5)
</details>

---

**9.** A play on servera reads `hostvars['serverb.lab.example.com']['ansible_facts']['default_ipv4']['address']` and fails, although serverb is in the inventory. What is the most likely cause?

* A. `hostvars` only works for the current host.
* B. No play in this run has gathered facts from serverb yet.
* C. Host names in `hostvars` must be short.
* D. `default_ipv4` does not exist.

<details><summary>Answer</summary>

**B.** `hostvars` holds another host's facts only after they were gathered in the same run. (Section 2.7)
</details>

---

**10.** An encrypted file starts with `$ANSIBLE_VAULT;1.2;AES256;prod`. Which statement is true?

* A. It was encrypted without a vault ID.
* B. It was encrypted with the vault ID label prod.
* C. Its password is prod.
* D. It uses a different cipher than 1.1 files.

<details><summary>Answer</summary>

**B.** Version 1.2 headers carry the label; the password is never stored. (Section 3.3)
</details>

---

**11.** With `ansible-navigator`, which combination lets `--ask-vault-pass` prompt you?

* A. `-m interactive`
* B. `-m stdout --pae false`
* C. `--pae true`
* D. `--ee false` only

<details><summary>Answer</summary>

**B.** Prompts need stdout mode and disabled playbook artifacts. (Section 3.4)
</details>

---

**12.** Which set of settings runs a project with two vault IDs and no prompts, while making each password apply only to its own label?

* A. `vault_password_file = .vault_dev` and `.vault_prod`
* B. `vault_identity_list = dev@.vault_dev,prod@.vault_prod` and `vault_id_match = true`
* C. `ANSIBLE_VAULT_PASSWORD_FILE=.vault_dev,.vault_prod`
* D. `--ask-vault-pass` twice

<details><summary>Answer</summary>

**B.** The identity list supplies both passwords; `vault_id_match` restricts each to its label. (Sections 3.4, 3.5)
</details>

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Protect Secrets with Ansible Vault](03_guided_exercise_variables_vault.md) | Next: [Chapter 03 Lab: A Login Protected Portal Built from Variables, Facts, and Vault](05_lab.md) →

<!-- navfoot:end -->
