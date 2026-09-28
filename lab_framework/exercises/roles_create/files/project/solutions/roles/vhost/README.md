vhost
=====

Creates one Apache virtual host per call: installs httpd and firewalld,
creates `vhost_root/vhost_name`, writes a home page, renders
`/etc/httpd/conf.d/vhost_name.conf`, and opens `vhost_port/tcp`.

Role variables
--------------

| Variable | Default | Meaning |
|---|---|---|
| `vhost_name` | required | Short site name |
| `vhost_port` | `80` | Listening port (SELinux must allow it for httpd) |
| `vhost_title` | `Welcome` | Home page text |
| `vhost_root` | `/var/www/sites` | Parent of all document roots |

Example
-------

    - name: Documentation site
      ansible.builtin.include_role:
        name: vhost
      vars:
        vhost_name: docs
        vhost_port: 8008
