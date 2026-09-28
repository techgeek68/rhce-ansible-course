<!-- nav:start -->
[Course home](../README.md) › [Chapter 08: Automating Linux Administration](README.md) › Quiz (8 of 10)
<!-- nav:end -->

# Chapter 08 Quiz: Linux Administration with Ansible

Answer every question before opening any answer. Target: 13 of 15.

---

**1.** The selinux system role fails with `selinux_reboot_required` set to true. What does the recommended play structure do?

* A. Ignores the error with `ignore_errors: true`.
* B. In `rescue`: fail unless a reboot is required, reboot, then run the role again.
* C. Sets `selinux_state: disabled`.
* D. Nothing; the role reboots by itself.

<details><summary>Answer</summary>

**B.** The role never reboots on its own. (README section 1.3)
</details>

---

**2.** Which task installs three packages in a single transaction?

* A. `dnf` with `name: "{{ item }}"` and a three item loop
* B. `dnf` with `name: [httpd, mod_ssl, httpd-tools]`
* C. Three separate `dnf` tasks
* D. `package_facts` with a list

<details><summary>Answer</summary>

**B.** (Section 2.1)
</details>

---

**3.** A play gathers package facts, installs `lab-agent`, then checks `'lab-agent' in ansible_facts['packages']`. The check is false. Why?

* A. The installation failed.
* B. Facts are a snapshot; run `package_facts` again after installing.
* C. Package names in facts are upper case.
* D. `package_facts` only lists packages from Red Hat.

<details><summary>Answer</summary>

**B.** (Section 2.2)
</details>

---

**4.** `yum_repository` has `gpgcheck: true` but no `gpgkey`, and no `rpm_key` task ran. What happens at install time?

* A. The package installs unsigned.
* B. dnf refuses: the public key is not installed.
* C. dnf downloads the key automatically from the base URL.
* D. The repository is disabled.

<details><summary>Answer</summary>

**B.** Import the key with `rpm_key` or set `gpgkey`. (Section 2.3)
</details>

---

**5.** Why does a `user` task with `password: "{{ pw | password_hash('sha512') }}"` report `changed` on every run?

* A. The user module always reports changed.
* B. A random salt produces a different hash each time; pass a fixed salt or use `update_password: on_create`.
* C. SHA-512 is not supported.
* D. The password is stored in plain text.

<details><summary>Answer</summary>

**B.** (Section 3.1)
</details>

---

**6.** alice is in groups `wheel` and `webadmin`. A task sets `groups: auditors` without `append`. Afterward alice is in:

* A. wheel, webadmin, and auditors
* B. only auditors (plus her primary group)
* C. unchanged
* D. no groups at all

<details><summary>Answer</summary>

**B.** Without `append: true` the list replaces the supplementary groups. (Section 3.1)
</details>

---

**7.** Which line in `/etc/sudoers.d/ops` lets members of group ops run every command as any user without a password?

* A. `ops ALL=(ALL) NOPASSWD: ALL`
* B. `%ops ALL=(ALL) NOPASSWD: ALL`
* C. `@ops ALL NOPASSWD`
* D. `group ops ALL=(ALL) ALL`

<details><summary>Answer</summary>

**B.** `%` marks a group; A applies to a user named ops. (Section 3.3)
</details>

---

**8.** What makes the `cron` module find an existing job to update or remove?

* A. The `job` command text
* B. The `name`, stored as an `#Ansible:` comment, together with `user` and `cron_file`
* C. The time fields
* D. A job ID returned when it was created

<details><summary>Answer</summary>

**B.** Renaming a job therefore creates a duplicate. (Section 4.1)
</details>

---

**9.** A `cron` task uses `cron_file: backups`. Which parameter is then required?

* A. `special_time`
* B. `user`
* C. `env`
* D. `weekday`

<details><summary>Answer</summary>

**B.** Lines in `/etc/cron.d/` include the user field. (Section 4.1)
</details>

---

**10.** You deploy `lab-report.timer` with `copy` and start it with `systemd_service`. It fails with `Unit lab-report.timer not found`. What is missing?

* A. `enabled: true`
* B. `daemon_reload: true`
* C. `masked: false`
* D. `scope: user`

<details><summary>Answer</summary>

**B.** systemd must reread unit files. (Section 4.3)
</details>

---

**11.** Which `ansible.posix.mount` state adds the fstab entry **and** mounts the file system now?

* A. `present`
* B. `mounted`
* C. `ephemeral`
* D. `remounted`

<details><summary>Answer</summary>

**B.** `present` only writes fstab; `ephemeral` only mounts. (Section 5.2)
</details>

---

**12.** A storage role volume was created with `size: 512m`. The next run says `size: 768m`. What happens?

* A. The role refuses because the volume exists.
* B. The volume and its XFS file system grow to 768 MiB.
* C. The volume is recreated, destroying the data.
* D. A second volume is created.

<details><summary>Answer</summary>

**B.** Shrinking XFS would fail; safe mode prevents destructive changes. (Section 5.1)
</details>

---

**13.** Which storage role entry creates and enables a swap volume?

* A. `{name: swap_lv, size: 256m, fs_type: swap}` inside a pool's `volumes`
* B. `{name: swap_lv, size: 256m, mount_point: swap}`
* C. `storage_swap: 256m`
* D. `{name: swap_lv, type: swap}` in `storage_pools`

<details><summary>Answer</summary>

**A.** No mount point; the role writes fstab and runs `swapon`. (Section 5.1)
</details>

---

**14.** Why must you not list the host's existing primary connection in `network_connections` with only a new address?

* A. The role ignores existing profiles.
* B. The role applies the listed profile completely, replacing the settings you left out, which can cut Ansible's own connection.
* C. Only bridges can have addresses.
* D. NetworkManager refuses duplicate names.

<details><summary>Answer</summary>

**B.** (Section 6.1)
</details>

---

**15.** Which fact gives the name of the interface that holds the default route?

* A. `ansible_facts['interfaces'][0]`
* B. `ansible_facts['default_ipv4']['interface']`
* C. `ansible_facts['fqdn']`
* D. `ansible_host`

<details><summary>Answer</summary>

**B.** `interfaces` is an unordered list. (Section 6.3)
</details>

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Network Connections with the Network Role](06_guided_exercise_system_network.md) | Next: [Chapter 08 Lab: Build an Application Host](08_lab.md) →

<!-- navfoot:end -->
