<!-- nav:start -->
[Course home](../README.md) › [Chapter 03: Variables, Facts, and Secrets](README.md) › Graded lab (6 of 7)
<!-- nav:end -->

# Chapter 03 Lab: A Login Protected Portal Built from Variables, Facts, and Vault

| | |
|---|---|
| **Exercise name** | `variables_review` |
| **Time limit** | 40 minutes |
| **Rules** | Work as `student` on workstation. Documentation tools (`ansible-doc`, `ansible-navigator doc`, man pages, `--help`) are allowed; the chapter is not |
| **Solution** | [06_lab_solution.md](06_lab_solution.md), after grading only |

```bash
lab start variables_review
```

Start creates `/home/student/variables_review` with `ansible.cfg` (privilege escalation off by default), an inventory (group `web`: serverb, serverc; group `probe`: servera), `files/portal.conf`, the navigator settings, and `ansible.posix` in `collections/`. It removes any earlier portal from serverb and serverc.

---

## Requirements

**1. Plain variables.**

* `group_vars/all/vars.yml` defines `portal_user` with the value `ops`.
* `group_vars/web/vars.yml` defines `web_pkgs` (the list `httpd`, `mod_ssl`, `firewalld`), `auth_dir` (`/etc/httpd/auth`), and `portal_owner` (`ops-team`).

**2. Secrets.** `group_vars/all/vault.yml` is encrypted with Ansible Vault using the vault ID label `portal` and the vault password `P0rtalVault`. It defines:

| Variable | Value |
|---|---|
| `portal_password` | `Ops2026` |
| `portal_htpasswd_hash` | `$apr1$PortaL26$2.RiV9gzOPgV7tK4ekV3s1` |

**3. No prompts.** The vault password is stored in `.portal_pass` in the project, readable and writable only by its owner, and `ansible.cfg` supplies it for the `portal` vault ID automatically.

**4. Playbook `portal.yml`.** Every value listed in requirements 1 and 2 is used through its variable, never typed literally.

Play 1 targets `web` with privilege escalation and ensures that:

* the packages in `web_pkgs` are installed;
* firewalld runs and starts at boot, and the `https` service is allowed permanently and immediately;
* directory `auth_dir` exists, owned by `root`, group `apache`, mode `0750`;
* `auth_dir/htpasswd` contains exactly one line, `portal_user`, a colon, and `portal_htpasswd_hash`; owner `root`, group `apache`, mode `0640`; the task that writes it never shows its data in the output;
* `files/portal.conf` is installed as `/etc/httpd/conf.d/portal.conf`;
* a custom fact file `/etc/ansible/facts.d/portal.fact` defines, in section `[portal]`, the key `owner` with the value of `portal_owner`;
* `/var/www/html/index.html` contains one line, built from facts: the host's fully qualified name, a space, its default IPv4 address in parentheses, then ` is run by ` and the `owner` value **read from the custom fact** (for serverb: `serverb.lab.example.com (192.168.250.11) is run by ops-team`);
* httpd runs and starts at boot.

Play 2 targets `web` without privilege escalation and saves each host's complete facts as JSON in `facts/HOSTNAME.json` inside the project, where `HOSTNAME` is the inventory name.

Play 3 targets `probe` without privilege escalation and uses `ansible.builtin.uri` to prove that:

* an anonymous request to `https://serverb.lab.example.com` returns status `401`;
* requests to serverb and serverc with `portal_user` and `portal_password` return status `200`.

The web servers use a self signed certificate.

**5. Run** `portal.yml` with `ansible-navigator` until every task succeeds.

---

## Grade

```bash
lab grade variables_review
```

| Area | Checks |
|---|---|
| Vault | Header shows ID `portal`; `.portal_pass` mode 0600; `ansible.cfg` supplies the portal password |
| Variables | `ansible-inventory --host serverb.lab.example.com` resolves every plain and vaulted value without prompting; `vars.yml` files are not encrypted |
| Playbook | `no_log: true` present; facts exported for both web hosts |
| serverb, serverc | mod_ssl installed, httpd running and enabled, https allowed; htpasswd ownership, mode, and content; custom fact value; anonymous access refused; correct page after login |

## Finish

```bash
lab finish variables_review
```

<!-- navfoot:start -->

---

← Previous: [Chapter 03 Quiz: Variables, Facts, and Vault](04_quiz.md) | Next: [Chapter 03 Lab Solution: `variables_review`](06_lab_solution.md) →

<!-- navfoot:end -->
