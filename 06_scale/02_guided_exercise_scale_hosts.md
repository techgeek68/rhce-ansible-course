<!-- nav:start -->
[Course home](../README.md) › [Chapter 06: Automation at Scale](README.md) › Guided exercise (3 of 6)
<!-- nav:end -->

# Guided Exercise: Select Exactly the Right Hosts

| | |
|---|---|
| **Exercise name** | `scale_hosts` |
| **Time** | 30 minutes |
| **Covers** | README section 3 |
| **You will** | Predict and verify fifteen host patterns against a twelve host inventory, narrow runs with `--limit`, and connect to real lab machines through inventory names that DNS does not know |

Most hosts in this inventory are fictional, so every play here uses `gather_facts: false` and the `debug` module, which never connects. Only the `lab` group points at real machines.

---

## Before You Begin

```bash
lab start scale_hosts
```

Start creates `~/scale_hosts` with `inventory` and `host_patterns.yml`. Open the project in the dev container or a workstation terminal.

---

## Step 1: Read the inventory as a graph

```bash
ansible-navigator inventory -m stdout --graph
```

| Group | Members |
|---|---|
| ungrouped | 192.168.250.200, 192.168.250.201 |
| web, api, db, cache | one `.east` and one `.west` host each |
| east, west | the four hosts of each site |
| frontend | children web and api |
| datacenter | children east and west |
| lab | `portal.lab.example.com` (connects to 192.168.250.10) and `admin.lab.example.com` (connects to serverb) |

```bash
cat host_patterns.yml
```

The play targets `all` and prints each selected host with the address it would connect to.

---

## Step 2: Preview before running

```bash
ansible-navigator run host_patterns.yml --list-hosts
```

`hosts (12)`. This is the habit to build: see the selection, then run.

---

## Step 3: Predict, then verify

For each pattern, write down your prediction, then check it. `ansible PATTERN --list-hosts` is the fastest check; the quotes matter.

| # | Pattern | Expected hosts |
|---|---|---|
| 1 | `ungrouped` | 192.168.250.200, 192.168.250.201 |
| 2 | `'192.168.250.*'` | The same two. **Not** portal, although it connects to 192.168.250.10 |
| 3 | `'*.east.example.com'` | web1, api1, db1, cache1 (east) |
| 4 | `frontend` | web1, web2, api1, api2 |
| 5 | `'frontend,&east'` | web1, api1 |
| 6 | `'datacenter,!db'` | the six datacenter hosts that are not db |
| 7 | `'!db,datacenter'` | the same six: order does not matter |
| 8 | `web,db` | web1, web2, db1, db2 |
| 9 | `'web[0]'` | web1 |
| 10 | `'web[-1]'` | web2 |
| 11 | `'east[1:2]'` | api1, db1 (second and third east host, both ends included) |
| 12 | `'~(web\|api)1\..*'` | web1, api1 |
| 13 | `'*lab*'` | portal, admin |
| 14 | `'d*'` | **eight** hosts: `d*` matches the groups `db` and `datacenter` too |
| 15 | `lab` | portal, admin |

```bash
ansible ungrouped --list-hosts
ansible '192.168.250.*' --list-hosts
ansible 'frontend,&east' --list-hosts
ansible 'datacenter,!db' --list-hosts
ansible 'east[1:2]' --list-hosts
ansible '~(web|api)1\..*' --list-hosts
ansible 'd*' --list-hosts
```

(In the regular expression the shell sees `|` inside single quotes, so no escaping is needed on the command line. The backslash in the table only protects the table formatting.)

Pattern 14 is the lesson of this exercise: a short wildcard like `d*` meant for `db` hosts selects the whole datacenter. Anchor wildcards on the domain.

---

## Step 4: Narrow a broad play with `--limit`

```bash
ansible-navigator run host_patterns.yml --limit 'web[0]'
ansible-navigator run host_patterns.yml --limit 'datacenter,!cache'
```

The playbook still says `hosts: all`; `--limit` narrows it for this run only.

Now try to widen it. Change the play to `hosts: web`, then:

```bash
ansible-navigator run host_patterns.yml --limit db --list-hosts
```

`hosts (0)`: `--limit` can only remove hosts from what the play allows. Change the play back to `hosts: all`.

---

## Step 5: Limit from a file

Change windows often come as host lists:

```bash
printf 'web1.east.example.com\napi2.west.example.com\n' > change_window.txt
ansible-navigator run host_patterns.yml --limit @change_window.txt
```

Only the two listed hosts run.

---

## Step 6: Break the YAML with an unquoted pattern

Change the play's host line to:

```yaml
  hosts: !db,datacenter
```

```bash
ansible-navigator run host_patterns.yml --syntax-check
```

YAML reads `!db` as a tag and the playbook fails to load. Quote it:

```yaml
  hosts: '!db,datacenter'
```

Run again: six hosts. Restore `hosts: all`.

---

## Step 7: Inventory names that DNS does not know

`portal.lab.example.com` and `admin.lab.example.com` exist only in this inventory:

```bash
getent hosts portal.lab.example.com || echo "not in DNS"
ansible lab -m ansible.builtin.ping
ansible lab -m ansible.builtin.command -a 'hostname'
```

Both pings succeed: portal reaches servera through `ansible_host=192.168.250.10`, admin reaches serverb through `ansible_host=serverb.lab.example.com`. The `hostname` output shows the real machines.

Contrast with a fictional host:

```bash
ansible web1.east.example.com -m ansible.builtin.ping
```

`UNREACHABLE ... Could not resolve hostname`: the pattern selected it, and nothing tells Ansible where it is. This is exactly why patterns deserve a `--list-hosts` preview before any real run.

Close the dev container.

---

## Finish

```bash
lab finish scale_hosts
```

## What You Proved

| Rule | Step |
|---|---|
| Patterns match inventory names, not connection addresses | 3 (#2), 7 |
| Set operators ignore their position | 3 (#6, #7) |
| Wildcards match group names | 3 (#14) |
| `--limit` narrows, never widens | 4 |
| Unquoted `!` breaks YAML | 6 |
| `ansible_host` separates name from address | 7 |

<!-- navfoot:start -->

---

← Previous: [Guided Exercise: Assemble a Playbook from Reusable Files](01_guided_exercise_scale_files.md) | Next: [Chapter 06 Quiz: Imports, Includes, and Host Patterns](03_quiz.md) →

<!-- navfoot:end -->
