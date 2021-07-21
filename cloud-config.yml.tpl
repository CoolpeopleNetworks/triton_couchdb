## template: jinja
#cloud-config

apt:
  sources:
    apache:
      source: "deb https://apache.bintray.com/couchdb-deb stretch main"
      key: |
        -----BEGIN PGP PUBLIC KEY BLOCK-----
        Version: GnuPG v1

        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
        JESa2SNRfw==
        =EI0Z
        -----END PGP PUBLIC KEY BLOCK-----

# Aggressively update
package_update: true
package_upgrade: true
package_reboot_if_required: true

# Install needed packages
packages:
  - apt-transport-https
  - ca-certificates
  - couchdb
  - curl

runcmd:
  - echo More here.

fqdn: {{ds.meta_data.hostname}}.${dns_suffix}

disk_setup:

fs_setup:

mounts:
 - [ vdb, null ]

users:
  - default
  - name: johnt
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_import_id:
        - gh:john-terrell
