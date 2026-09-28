labteam.shell_env
=================

Writes `/etc/profile.d/lab_shell.sh`, which every login shell reads.

Role variables
--------------

### `shell_env_prompt` (default: `'[\u@\h \W]\$ '`)

The `PS1` prompt. Bash escapes such as `\u` (user), `\h` (short host name),
and `\W` (current directory) are allowed. Quote the value in single quotes in YAML.

### `shell_env_history_size` (default: `5000`)

Number of commands kept in the shell history (`HISTSIZE`).

Example
-------

    - name: Team shell environment
      ansible.builtin.import_role:
        name: labteam.shell_env
      vars:
        shell_env_prompt: '[\u on \h in \W]\$ '
