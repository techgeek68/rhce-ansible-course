<!-- nav:start -->
[Course home](../README.md) › [Chapter 03: Variables, Facts, and Secrets](README.md) › Guided exercise (4 of 7)
<!-- nav:end -->

# Guided Exercise: Protect Secrets with Ansible Vault

| | |
|---|---|
| **Exercise name** | `variables_vault` |
| **Time** | 45 minutes |
| **Covers** | README section 3 |
| **You will** | Encrypt a file that must arrive decrypted on the hosts, keep development and production secrets under separate vault IDs, encrypt a single value, and finally run everything without prompts while keeping passwords out of Git |

Passwords used in this exercise:

| Purpose | Vault ID | Password |
|---|---|---|
| Reporting token file (Part A) | none, then `prod` | `T0kenVault` |
| Development secrets | `dev` | `D3vVault!` |
| Production secrets | `prod` | `Pr0dVault!` |

---

## Before You Begin

```bash
lab start variables_vault
```

Start creates `~/variables_vault` with `files/app_token.conf` (plain text), `deploy_token.yml`, `create_logins.yml`, `group_vars/dev/vars.yml`, `group_vars/prod/vars.yml`, and `solutions/`. It removes the logins and token used here from all four hosts.

Open the project in the dev container or a workstation terminal. The project's `ansible-navigator.yml` already sets `mode: stdout` and disables artifacts, which vault prompts require.

---

## Part A: A file that travels encrypted

### Step 1: Encrypt the token file

```bash
cat files/app_token.conf
ansible-vault encrypt files/app_token.conf        # password T0kenVault, twice
head -n1 files/app_token.conf
cat files/app_token.conf
```

The header is `$ANSIBLE_VAULT;1.1;AES256`: no vault ID. The rest is unreadable hexadecimal text.

```bash
ansible-vault view files/app_token.conf           # read without changing
```

### Step 2: Deploy it decrypted

```bash
cat deploy_token.yml
ansible-navigator run deploy_token.yml
```

Without a password the run stops with `Attempting to decrypt but no vault secrets found`. Supply it:

```bash
ansible-navigator run deploy_token.yml --ask-vault-pass
ssh devops@servera.lab.example.com sudo cat /etc/reporting/token.conf
```

The file on servera is plain text with mode 0600: the `copy` module decrypted it on the way (`decrypt: true`, which is also the default).

---

## Part B: Separate development and production secrets

`create_logins.yml` creates one login per host. The login **name** comes from the plain `group_vars/*/vars.yml`; the password **hash** must come from an encrypted `vault.yml` next to it.

### Step 3: Create the development vault

```bash
ansible-vault create --vault-id dev@prompt group_vars/dev/vault.yml    # password D3vVault!
```

In the editor, enter exactly (paste it; this is a SHA512 hash of the login password `redhat`):

```yaml
---
team_password_hash: "$6$Lab3DevS4lt$3vtrKE4r0V8aMPAt8oozRN0XZ94sn1mavKbGtjLUsZHwufWVbuNwwLTwyKerJvglZFUzt/9rdoOpQjkFADyha0"
```

Save and quit (`:wq` in vi).

### Step 4: Create the production vault

Write the file in plain text first, then encrypt it, to practice the second way:

```bash
cat > group_vars/prod/vault.yml <<'EOF'
---
team_password_hash: "$6$Lab3PrdS4lt$cktjpoar2OgMMU1ivAkWzpSMGvx5MPk8pxdZsDVQXTB8E3gMhF4OIyLOyFEYz.Pm1WuABmpCQO5xrXrDgCMsV/"
EOF
ansible-vault encrypt --vault-id prod@prompt group_vars/prod/vault.yml    # password Pr0dVault!
head -qn1 group_vars/dev/vault.yml group_vars/prod/vault.yml
```

```
$ANSIBLE_VAULT;1.2;AES256;dev
$ANSIBLE_VAULT;1.2;AES256;prod
```

Hashes are generated with `openssl passwd -6 PASSWORD` or the `password_hash` filter. Even a hash deserves encryption: it can be attacked offline.

### Step 5: Run with two prompts

```bash
ansible-navigator run create_logins.yml -v --vault-id dev@prompt --vault-id prod@prompt
```

Enter each password when its label is shown. Even at `-v`, every result reads `the output has been hidden due to the fact that 'no_log: true' was specified`.

Test the logins with the password `redhat`:

```bash
ssh -o PreferredAuthentications=password dev_ops1@servera.lab.example.com hostname
ssh -o PreferredAuthentications=password prod_ops1@serverc.lab.example.com hostname
```

### Step 6: See what a missing password does

```bash
ansible-navigator run create_logins.yml --vault-id dev@prompt
```

Only the dev password is supplied: the run fails for the prod hosts with a decryption error. Every host whose variables include an encrypted file needs a working password, even if the play would not use that secret.

---

## Part C: One encrypted value in a readable file

### Step 7: Encrypt a single variable

```bash
ansible-vault encrypt_string --vault-id prod@prompt --stdin-name report_api_key >> group_vars/prod/vars.yml
```

Type the vault password `Pr0dVault!` twice, then the value `k3y-2026-prod`, press Enter, then Ctrl+D twice.

```bash
cat group_vars/prod/vars.yml
```

`team_login` stays readable; `report_api_key` is a `!vault |` block. Reviewers see which secrets exist without seeing their values. Show the value to prove it decrypts:

```bash
ansible serverc.lab.example.com -m ansible.builtin.debug -a var=report_api_key --vault-id prod@prompt
```

`--stdin-name` kept the value out of your shell history; `encrypt_string VALUE --name report_api_key` would have stored it there.

---

## Part D: No more prompts, no leaks

### Step 8: Password files, protected and ignored

```bash
printf 'D3vVault!\n'  > .vault_dev
printf 'Pr0dVault!\n' > .vault_prod
chmod 0600 .vault_dev .vault_prod
echo '.vault_*' >> .gitignore
ls -l .vault_*
```

`printf` avoids the trailing space mistakes that happen when typing into an editor.

### Step 9: Reference them in `ansible.cfg`

Add to `[defaults]`:

```ini
vault_identity_list = dev@.vault_dev,prod@.vault_prod
vault_id_match = true
```

```bash
ansible-navigator run create_logins.yml
```

No options, no prompts, `changed=0` on all hosts.

### Step 10: Bring the legacy file under a vault ID

```bash
ansible-navigator run deploy_token.yml
```

It fails with `Decryption failed (no vault secrets were found that could decrypt)`: none of the configured passwords opens the token file. Adding `T0kenVault` under some other label would not help either, because with `vault_id_match = true` a legacy `1.1` file accepts only a password labeled `default`. Rekey it to the prod label and prod password:

```bash
ansible-vault rekey --vault-id default@prompt --new-vault-id prod@.vault_prod files/app_token.conf
head -n1 files/app_token.conf
ansible-navigator run deploy_token.yml
```

Enter `T0kenVault` for the old password. The header now reads `$ANSIBLE_VAULT;1.2;AES256;prod`, and the playbook runs without prompts.

### Step 11: Final hygiene check

```bash
git init -q && git add -A && git status --short | grep -E 'vault_|app_token'
```

`.vault_dev` and `.vault_prod` are absent from the list; `files/app_token.conf` and both `vault.yml` files are present, safely encrypted. Remove the throwaway repository with `rm -rf .git`.

Close the dev container.

---

## Finish

```bash
lab finish variables_vault
```

Finish removes the logins and the token from the hosts. `solutions/README.md` lists the plain text of every value you encrypted, and `solutions/ansible.cfg` shows the final configuration.

## Troubleshooting

| Symptom | Fix |
|---|---|
| navigator waits forever after `--ask-vault-pass` | Artifacts enabled or interactive mode: add `-m stdout --pae false` |
| `Decryption failed` with the right password | Password file has trailing spaces or Windows line endings; recreate it with `printf` |
| `input is already encrypted` | The file is already encrypted; use `edit` or `rekey` |
| Login test asks for the password repeatedly | Hash pasted incompletely; `ansible-vault edit` the file and compare with `solutions/README.md` |
| `The vault-ids dev,prod are available to encrypt. Specify the vault-id to encrypt with --encrypt-vault-id` | After Step 9 several passwords are configured; add `--encrypt-vault-id prod` (or `dev`) to `encrypt`, `create`, and `encrypt_string` |
| `encrypt_string` block breaks YAML | The `>>` appended to the end of the file: check that `report_api_key:` starts at column 1 |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Drive Automation from Facts](02_guided_exercise_variables_facts.md) | Next: [Chapter 03 Quiz: Variables, Facts, and Vault](04_quiz.md) →

<!-- navfoot:end -->
