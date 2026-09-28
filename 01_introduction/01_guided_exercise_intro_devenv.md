<!-- nav:start -->
[Course home](../README.md) › [Chapter 01: Introduction to Ansible](README.md) › Guided exercise (2 of 6)
<!-- nav:end -->

# Guided Exercise: Build Your Ansible Development Environment

| | |
|---|---|
| **Exercise name** | `intro_devenv` |
| **Time** | 35 minutes (the first dev container start adds a few minutes for the image pull) |
| **Covers** | README section 2 |
| **You will** | Clone a project from the lab Git server, configure the Ansible and Dev Containers extensions, open the project in a dev container, run a playbook inside an execution environment, and push the change |

Each step shows the VS Code action first and the terminal equivalent after it. Do the VS Code path; read the terminal path so you can do it without a GUI.

---

## Before You Begin

On workstation as `student`:

```bash
lab start intro_devenv
```

The start action checks that VS Code, Podman, Git, ansible-navigator, the lab registry, and Gitea are available, and recreates the `intro_devenv` repository on Gitea with starter content. It also deletes any earlier clone in `~/git-repos/intro_devenv`, so each attempt begins from the same point.

---

## Step 1: Give Git your identity

Git refuses to commit without a name and email. Set them once per machine:

```bash
git config --global user.name 'Student User'
git config --global user.email student@lab.example.com
git config --global init.defaultBranch main
git config --global --list
```

**Check:** the last command lists all three values. They are stored in `~/.gitconfig`.

---

## Step 2: Clone the project

**VS Code:**

1. Open VS Code from the Activities overview.
2. Click the **Source Control** icon in the Activity Bar (or press `Ctrl+Shift+G`), then **Clone Repository**.
3. Enter `http://utility.lab.example.com:3000/student/intro_devenv.git` and press Enter.
4. Choose `/home/student/git-repos` as the destination, then **Select as Repository Destination**.
5. Click **Open** when asked. If VS Code asks whether you trust the authors, trust the parent folder `git-repos`.

**Terminal equivalent:**

```bash
git clone http://utility.lab.example.com:3000/student/intro_devenv.git ~/git-repos/intro_devenv
code ~/git-repos/intro_devenv
```

The repository is public on the lab server, so cloning needs no password. Pushing later does (`student` / `Student@123`).

**Check:** the Explorer shows `README.md`, `ansible.cfg`, `inventory`, `hello.yml`, `.gitignore`, and `solutions/`.

---

## Step 3: Configure the Ansible extension for this workspace

**VS Code:**

1. Click the **Ansible** icon in the Activity Bar, then **Settings** under the LAUNCH section. If you cannot see LAUNCH, collapse the Lightspeed panels and scroll.
2. Select the **Workspace** tab. Workspace settings are saved inside the project, so they are shared through Git.
3. Under **Ansible, Validation**: make sure **Lint: Enabled** is selected.
4. Under **Ansible, Execution Environment**:
   * **Enabled**: selected
   * **Container Engine**: `podman`
   * **Image**: `utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest`
   * **Pull: Policy**: `missing`
   * **Pull: Arguments**: `--tls-verify=false`
5. Close the Settings tab.

**Check:** open `.vscode/settings.json` in the Explorer. It must contain these keys (order does not matter):

```json
{
  "ansible.validation.lint.enabled": true,
  "ansible.executionEnvironment.enabled": true,
  "ansible.executionEnvironment.containerEngine": "podman",
  "ansible.executionEnvironment.image": "utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest",
  "ansible.executionEnvironment.pull.policy": "missing",
  "ansible.executionEnvironment.pull.arguments": "--tls-verify=false"
}
```

**Terminal equivalent:** create `.vscode/settings.json` with exactly that content. A finished copy is in `solutions/.vscode/settings.json`.

---

## Step 4: Point the Dev Containers extension at Podman

The Dev Containers extension expects Docker by default. This setting belongs to you, not to the project, so it goes in the **User** scope.

**VS Code:**

1. Click **Extensions** in the Activity Bar. Under INSTALLED, right click **Dev Containers**, then **Settings**.
2. Select the **User** tab.
3. **Docker Path**: `podman`
4. **Docker Compose Path**: `podman-compose`
5. Close the Settings tab.

**Check:**

```bash
grep dev.containers ~/.config/Code/User/settings.json
```

Expected:

```
    "dev.containers.dockerPath": "podman",
    "dev.containers.dockerComposePath": "podman-compose"
```

---

## Step 5: Generate the dev container definition

**VS Code:**

1. Click the **Ansible** icon, then **Devcontainer** under the ADD section.
2. For **Container image**, choose **Downstream**, then click **Create**.
3. The button gives no visual feedback. Success is the log line `Created new devcontainer at /home/student/git-repos/intro_devenv` at the bottom of the page.
4. Close the tab and return to the Explorer.

The new directory `.devcontainer/` contains a definition per container engine. You use `.devcontainer/podman/devcontainer.json`.

---

## Step 6: Adapt the definition to the lab

Open `.devcontainer/podman/devcontainer.json` and make three changes.

**6.1** Replace the `image` value so it points at the lab registry instead of registry.redhat.io:

```json
  "image": "utility.lab.example.com:5000/ansible-automation-platform-26/ansible-dev-tools-rhel9:latest",
```

**6.2** Add these two entries at the top of the `runArgs` list:

```json
  "runArgs": [
    "--rm",
    "--tls-verify=false",
    ...existing entries stay...
```

`--rm` deletes the container when you disconnect, so every session starts clean. `--tls-verify=false` lets Podman pull from the plain HTTP lab registry.

**6.3** Add a `mounts` entry after the closing bracket of `runArgs` so the container can use your SSH key to reach the managed hosts (a local lab requirement; mind the comma after `]`):

```json
  "mounts": [
    "source=${localEnv:HOME}/.ssh,target=/root/.ssh,type=bind,readonly"
  ],
```

Save the file. Compare with `solutions/.devcontainer/podman/devcontainer.json` if VS Code underlines anything in red; a missing comma is the usual cause.

**Check:**

```bash
cd ~/git-repos/intro_devenv
python3 -m json.tool .devcontainer/podman/devcontainer.json > /dev/null && echo valid JSON
grep -E '"image"|--rm|--tls-verify|/root/.ssh' .devcontainer/podman/devcontainer.json
```

---

## Step 7: Reopen the project inside the container

1. Close VS Code completely, then reopen it. It reopens the same folder.
2. Click **Reopen in Container** in the notification at the lower right. If the notification does not appear, click the remote indicator `><` at the lower left and choose **Reopen in Container**.
3. Choose **ansible-dev-container-podman**.
4. The first start pulls the development tools image from the lab registry and takes a few minutes. Click **show log** in the notification to watch it.

**Check:** the lower left corner shows `Dev Container: ansible-dev-container-podman`. Open **Terminal, New Terminal** and run:

```bash
pwd                          # /workspaces/intro_devenv
ansible-navigator --version
ansible-lint --version
ls -l /root/.ssh             # your key and known_hosts, read only
```

---

## Step 8: Change the playbook

Open `hello.yml`. Change the message so it reports the managed host's real name instead of a fixed sentence. The finished file:

```yaml
---
- name: First contact with a managed host
  hosts: servera.lab.example.com
  tasks:
    - name: Report success
      ansible.builtin.debug:
        msg: "Ansible reached {{ ansible_facts['hostname'] }}"
```

`ansible_facts['hostname']` is collected automatically by the implicit "Gathering Facts" task at the start of the play. You will study facts in a later chapter; for now notice that the value comes from the managed host, not from the control node.

Save. The Ansible extension lints the file as you type; the Problems panel (`Ctrl+Shift+M`) must show no entries for `hello.yml`.

**Terminal check inside the container:**

```bash
ansible-lint hello.yml
```

The run must end with a `Passed` line and zero failures.

---

## Step 9: Run the playbook through the execution environment

**VS Code:** right click `hello.yml` in the Explorer, then **Run Ansible Playbook via**, then **Run playbook via 'ansible-navigator run'**.

**Terminal equivalent inside the container** (the project has no `ansible-navigator.yml` yet, so every setting is given as an option):

```bash
ansible-navigator run hello.yml -m stdout --pae false \
  --eei utility.lab.example.com:5000/ansible-automation-platform-26/ee-supported-rhel9:latest \
  --pp missing --pa=--tls-verify=false
```

Expected result:

```
PLAY [First contact with a managed host] ***************************************

TASK [Gathering Facts] *********************************************************
ok: [servera.lab.example.com]

TASK [Report success] **********************************************************
ok: [servera.lab.example.com] => {
    "msg": "Ansible reached servera"
}

PLAY RECAP *********************************************************************
servera.lab.example.com    : ok=2    changed=0    unreachable=0    failed=0 ...
```

Notice what ran where: VS Code talked to the dev tools container, which started the execution environment container, which connected over SSH as `devops` (from the project `ansible.cfg`) to servera.

---

## Step 10: Commit and push

**VS Code:**

1. The Source Control icon shows a number: files changed since the clone.
2. Open Source Control. Hover over **Changes** and click `+` to stage everything: `hello.yml` (M), `.vscode/settings.json` (A or U), and the `.devcontainer/` files (A or U). The editor settings and container definition belong in the repository so the next person gets the same environment.
3. Type the message `Report managed host name and add dev environment definition` and click **Commit**.
4. Open **More Actions** (`...`), then **Push**. Enter `student` / `Student@123` if prompted. Answer **No** if VS Code offers to run `git fetch` periodically.

**Terminal equivalent** (inside the container or on workstation, in the project directory):

```bash
git status -s
git add -A
git commit -m 'Report managed host name and add dev environment definition'
git push
```

**Check:**

```bash
git status -sb          # first line: ## main...origin/main   (no "ahead")
git log --oneline -3
```

Also open `http://utility.lab.example.com:3000/student/intro_devenv` in Firefox on workstation. Your commit is at the top with author `Student User`.

---

## Step 11: Leave the container

Click **File, Close Remote Connection**. Because of `--rm`, the container is deleted; your files remain on workstation because they live in the mounted project directory.

```bash
podman ps -a --filter label=devcontainer.local_folder     # no containers listed
```

---

## Finish

```bash
lab finish intro_devenv
```

Finish removes any leftover development containers. Your clone and the Gitea repository stay, so you can review your work later.

---

## What You Proved

| Skill | Evidence |
|---|---|
| Git round trip | Commit visible on Gitea with your identity |
| Workspace versus user settings | Ansible settings in `.vscode/settings.json`, Podman settings in `~/.config/Code/User/settings.json` |
| Dev container | Status bar showed the container; tools ran from `/workspaces` |
| Execution environment run | `Ansible reached servera` printed from inside the EE |

## Troubleshooting

| Symptom | Fix |
|---|---|
| Reopen in Container fails with `docker: command not found` | Step 4 was not saved in the **User** scope |
| Container build log shows `http: server gave HTTP response to HTTPS client` | `--tls-verify=false` missing from `runArgs`, or the image line still points to registry.redhat.io |
| Playbook `UNREACHABLE` with `Permission denied (publickey)` | The `mounts` entry from step 6.3 is missing, so the container has no SSH key |
| Playbook `UNREACHABLE` with `Host key verification failed` | `~/.ssh/known_hosts` on workstation lacks servera; run `ssh-keyscan servera.lab.example.com >> ~/.ssh/known_hosts` on workstation and reopen the container |
| Push rejected with 401 | Wrong credentials; VS Code may have cached them. Run `git push` in a terminal to be prompted again |
| JSON errors after editing | Compare with `solutions/.devcontainer/podman/devcontainer.json`; the usual cause is a missing comma after `]` |

<!-- navfoot:start -->

---

← Previous: [Chapter 01: Introduction to Ansible](README.md) | Next: [Guided Exercise: Configure Ansible and Automation Content Navigator](02_guided_exercise_intro_configure.md) →

<!-- navfoot:end -->
