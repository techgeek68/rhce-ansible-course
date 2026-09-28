# Maintaining and Publishing the Course

This page is for the course author. Students never need it.

---

## 1. How the Course Is Organized

| Rule | Why |
|---|---|
| Top level directories named `NN_name/` are chapters, in number order | Study order is visible in the GitHub file list |
| Each chapter has a `README.md` lesson | GitHub renders it when a student opens the directory |
| Other pages are `NN_*.md`, numbered in study order: guided exercises, then quiz, lab, lab solution | The file list reads like a table of contents |
| Every page's first `# ` heading is its title | Navigation and the contents table use it |
| Navigation blocks between `<!-- nav:... -->` markers and the contents table between `<!-- toc:... -->` markers are generated | Never edit them by hand |
| Exercise names (`lab start NAME`) stay without numbers, in `lab_framework/exercises/NAME/` | Page numbers can change; exercise names are what students type |

---

## 2. One Time Setup on Your Computer

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
```

Authentication to GitHub, choose one:

| Method | Setup |
|---|---|
| SSH key (recommended) | `ssh-keygen -t ed25519 -C "you@example.com"`, add `~/.ssh/id_ed25519.pub` under GitHub **Settings → SSH and GPG keys**, test with `ssh -T git@github.com` |
| HTTPS with a token | GitHub **Settings → Developer settings → Personal access tokens → Fine-grained**, repository access to this repository, permission **Contents: Read and write**; use the token as the password when Git asks |
| GitHub CLI | `gh auth login`, then `gh` handles both |

---

## 3. First Publication

### 3.1 Create the empty repository on GitHub

On github.com: **New repository**. Name, for example, `rhce-ansible-course`. Visibility **Public** (students need no account to read). Do **not** add a README, `.gitignore`, or license there: the repository must be empty so the first push is accepted.

Or with the CLI (after step 3.2): `gh repo create rhce-ansible-course --public --source=. --push`.

### 3.2 Prepare and push the local copy

```bash
unzip rhce_ansible_course.zip
cd rhce_ansible_course

tools/set_repo_url.sh YOUR_GITHUB_ACCOUNT rhce-ansible-course   # fills in the download and clone URLs
python3 tools/build_nav.py                                      # refresh navigation
python3 tools/check_links.py                                    # must report 0 broken links

git init
git add .
git status                                                      # read the list before committing
git commit -m "Publish chapters 00 to 08"
git remote add origin git@github.com:YOUR_GITHUB_ACCOUNT/rhce-ansible-course.git
git push -u origin main
```

With HTTPS instead of SSH, the remote is `https://github.com/YOUR_GITHUB_ACCOUNT/rhce-ansible-course.git`.

Keep the executable bits: Git records them, and `lab_framework/bin/lab`, `install.sh`, `bastion_setup.sh`, and the `tools/` scripts must stay executable. If you prepared the files on Windows, run `git update-index --chmod=+x FILE` for each before committing; `.gitattributes` already forces Unix line endings.

### 3.3 Configure the repository page

| Setting | Where | Value |
|---|---|---|
| Description | **About** (gear icon) | Self study RHCE EX294 course with a local lab and graded exercises |
| Topics | **About** | `rhce`, `ex294`, `ansible`, `rhel`, `automation`, `self-study` |
| Issues | **Settings → General → Features** | On, so students can report problems |
| Discussions | same | On, for questions |
| License | **Add file → Create new file**, name `LICENSE`, **Choose a license template** | Your choice, for example CC BY-SA 4.0 for the text and MIT for the scripts; decide before sharing widely |
| Branch protection | **Settings → Branches** | Optional: require the **Course checks** workflow to pass before merging |

### 3.4 Confirm what students will see

* The repository front page shows `README.md` with the study path and the generated contents table.
* Open `01_introduction/`: the lesson renders with its page list; the **Next** link at the bottom leads to the first guided exercise.
* The **Actions** tab shows **Course checks** passing.
* On a lab VM, the clone command in Step 6.3 of `00_lab_setup/README.md` works.

---

## 4. Publishing Each New Chapter

```bash
cd rhce_ansible_course
git pull                                   # start from the published state
git switch -c chapter-09                   # work on a branch
```

1. Create `09_topic/README.md` (lesson) and the numbered pages: `01_guided_exercise_NAME.md` ..., `NN_quiz.md`, `NN_lab.md`, `NN_lab_solution.md`.
2. Add the exercises under `lab_framework/exercises/NAME/` and their lines to the `lab list` output in Step 6.3 of `00_lab_setup/README.md`.
3. Add the chapter to the **Progress Checklist** in the root `README.md`.
4. Refresh and check:

   ```bash
   python3 tools/build_nav.py
   python3 tools/check_links.py
   ```

5. Test every new exercise on the lab: `./install.sh`, then `lab start`, the steps, `lab grade` with the solution and with an empty project, `lab finish`.
6. Commit and publish:

   ```bash
   git add .
   git commit -m "Add chapter 09: TOPIC"
   git push -u origin chapter-09
   ```

   On GitHub, open the pull request, wait for **Course checks**, merge. Or, working alone without pull requests: `git switch main && git merge chapter-09 && git push`.

7. Tag the release so students can download a fixed version:

   ```bash
   git switch main && git pull
   git tag -a v0.9 -m "Chapters 00 to 09"
   git push origin v0.9
   ```

   On GitHub, **Releases → Draft a new release**, choose the tag, and describe what changed. GitHub attaches a source zip automatically.

Suggested version scheme: `v0.N` while chapters are being added (N = last chapter), `v1.0` when the course is complete and every exercise has been tested on real VMs.

---

## 5. Fixing a Page

Small corrections go straight to `main`:

```bash
git pull
# edit the page
python3 tools/build_nav.py && python3 tools/check_links.py
git commit -am "Fix step 4 of the storage guided exercise"
git push
```

If a heading changes, the navigation and contents table change with it; that is why `build_nav.py` runs before every commit. The workflow fails when someone forgets.

When a fix touches an exercise under `lab_framework/`, mention in the commit message and the release notes that students must run `git pull` and `./install.sh` again.

---

## 6. Renaming or Reordering Pages

1. Rename with Git so history follows the file: `git mv 08_linux_admin/03_guided_exercise_system_users.md 08_linux_admin/04_guided_exercise_system_users.md`.
2. Update links to the old name: `grep -rn 'OLD_NAME' --include='*.md' .`
3. `python3 tools/build_nav.py && python3 tools/check_links.py`.

Renaming breaks bookmarks, so prefer adding pages at the end of a chapter.

---

## 7. Checks Before Every Push

| Check | Command |
|---|---|
| Navigation current | `python3 tools/build_nav.py` then `git status` shows no unexpected changes |
| No broken links | `python3 tools/check_links.py` |
| Scripts parse | `bash -n lab_framework/bin/lab`, `bash -n 00_lab_setup/scripts/bastion_setup.sh` |
| Nothing secret committed | `git diff --cached --stat`; no keys, vault passwords, or `.lab/` directories |
| Placeholders gone | `grep -rln 'YOUR_ACCOUNT/YOUR_REPO' .` lists only `tools/set_repo_url.sh` and this page |

The **Course checks** workflow in `.github/workflows/checks.yml` repeats the first three on every push and pull request.
