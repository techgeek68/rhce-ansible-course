<!-- nav:start -->
[Course home](../README.md) › [Chapter 02: Developing Automation Content](README.md) › Guided exercise (2 of 8)
<!-- nav:end -->

# Guided Exercise: Build and Query a Static Inventory

| | |
|---|---|
| **Exercise name** | `develop_inventory` |
| **Time** | 30 minutes |
| **Covers** | README section 1 |
| **You will** | Write an INI inventory with role, site, region, and stage groups, prove its structure, select hosts with patterns, and rewrite it in YAML |

---

## Before You Begin

```bash
lab start develop_inventory
```

This creates `~/develop_inventory` with `ansible.cfg` (pointing to `./inventory`, which does not exist yet), the navigator settings, the dev container definition, and `solutions/`.

Open the project in VS Code and choose **Reopen in Container** (as in Chapter 1), then open a terminal. Every command below also works in a plain workstation terminal inside `~/develop_inventory`.

---

## Step 1: Read the specification

| Host | Role | Site | Region | Stage | Extra data |
|---|---|---|---|---|---|
| servera.lab.example.com | web | nyc | americas | dev | |
| serverb.lab.example.com | web | nyc | americas | test | |
| serverc.lab.example.com | web | sfo | americas | prod | |
| serverd.lab.example.com | db | fra | emea | prod | `db_engine=mariadb` |

Additional rules:

* Regions are groups of site groups, not lists of hosts.
* Every host in stage prod shares the variable `change_window` with the value `Saturday 02:00 UTC`.
* The three web hosts are written with one range.

---

## Step 2: Write the inventory

Create `inventory` in the project root:

```ini
# Role groups
[web]
server[a:c].lab.example.com

[db]
serverd.lab.example.com db_engine=mariadb

# Site groups
[nyc]
servera.lab.example.com
serverb.lab.example.com

[sfo]
serverc.lab.example.com

[fra]
serverd.lab.example.com

# Region groups built from sites
[americas:children]
nyc
sfo

[emea:children]
fra

# Stage groups
[dev]
servera.lab.example.com

[test]
serverb.lab.example.com

[prod]
serverc.lab.example.com
serverd.lab.example.com

[prod:vars]
change_window="Saturday 02:00 UTC"
```

Notice what is **not** here: no group lists all four hosts, because `all` already does; no region lists hosts, because it inherits them from its sites.

---

## Step 3: Prove the structure

```bash
ansible-navigator inventory -i inventory -m stdout --graph americas
```

```
@americas:
  |--@nyc:
  |  |--servera.lab.example.com
  |  |--serverb.lab.example.com
  |--@sfo:
  |  |--serverc.lab.example.com
```

```bash
ansible-navigator inventory -i inventory -m stdout --graph ungrouped
```

`@ungrouped:` with nothing under it: every host belongs to a real group.

```bash
ansible-navigator inventory -i inventory -m stdout --host serverd.lab.example.com
```

```json
{
    "change_window": "Saturday 02:00 UTC",
    "db_engine": "mariadb"
}
```

serverd receives its own host variable and the group variable from `prod`. Now query serverc: it shows only `change_window`.

Try a name that is not in the inventory:

```bash
ansible-navigator inventory -i inventory -m stdout --host servera
```

It fails with `You must pass a single valid host to --host parameter`. Inventory names are literal strings; `servera` and `servera.lab.example.com` are different hosts to Ansible even though DNS resolves both.

---

## Step 4: Browse interactively

```bash
ansible-navigator inventory -i inventory -m interactive
```

Type `0` to browse groups, pick `prod`, look at its hosts and variables, `Esc` back, `1` to browse hosts, then `:q` to leave.

---

## Step 5: Select hosts with patterns

Predict each answer before you press Enter:

```bash
ansible 'americas:&prod' --list-hosts      # serverc
ansible 'web:!prod' --list-hosts           # servera, serverb
ansible 'nyc,fra' --list-hosts             # servera, serverb, serverd
ansible '~server[cd]\..*' --list-hosts     # serverc, serverd
ansible 'emea:db' --list-hosts             # serverd (listed once)
```

No `-i` is needed here because `ansible.cfg` sets `inventory = ./inventory`. Single quotes stop the shell from interpreting `!` and `&`.

---

## Step 6: Watch Ansible reject a bad group name

Add this temporary group at the end of `inventory`:

```ini
[db-servers]
serverd.lab.example.com
```

```bash
ansible-inventory --graph 2>&1 | head -3
```

A warning about invalid characters in group names appears. Delete the two lines again. Use underscores (`db_servers`) whenever you name a group.

---

## Step 7: Rewrite the inventory in YAML

Create `inventory.yml`:

```yaml
---
all:
  children:
    web:
      hosts:
        server[a:c].lab.example.com:
    db:
      hosts:
        serverd.lab.example.com:
          db_engine: mariadb
    americas:
      children:
        nyc:
          hosts:
            servera.lab.example.com:
            serverb.lab.example.com:
        sfo:
          hosts:
            serverc.lab.example.com:
    emea:
      children:
        fra:
          hosts:
            serverd.lab.example.com:
    dev:
      hosts:
        servera.lab.example.com:
    test:
      hosts:
        serverb.lab.example.com:
    prod:
      hosts:
        serverc.lab.example.com:
        serverd.lab.example.com:
      vars:
        change_window: Saturday 02:00 UTC
```

Prove that both files describe exactly the same inventory:

```bash
diff <(ansible-inventory -i inventory --list) <(ansible-inventory -i inventory.yml --list) && echo identical
```

Expected: `identical`. If `diff` prints lines, compare them; a missing colon after a host name in YAML is the usual cause.

---

## Step 8: Use the inventory for real

```bash
ansible prod -m ansible.builtin.ping
ansible web -m ansible.builtin.command -a 'hostname -s' -o
```

The first returns `pong` from serverc and serverd; the second prints one line per web host. Both use `remote_user = devops` from `ansible.cfg`.

Close the dev container with **File, Close Remote Connection**.

---

## Finish

```bash
lab finish develop_inventory
```

Your project stays in `~/develop_inventory`; compare it with `solutions/`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `--graph americas` shows hosts directly under americas | You wrote `[americas]` instead of `[americas:children]` |
| serverd lacks `change_window` | Section header must be `[prod:vars]` exactly |
| YAML version shows hosts as groups | Host keys belong under `hosts:`; groups under `children:` |
| `ansible` commands say the host list is empty | Run them from `~/develop_inventory` so `ansible.cfg` is found |

<!-- navfoot:start -->

---

← Previous: [Chapter 02: Developing Automation Content](README.md) | Next: [Guided Exercise: Write, Check, Run, and Replay a Single Play](02_guided_exercise_develop_singleplay.md) →

<!-- navfoot:end -->
