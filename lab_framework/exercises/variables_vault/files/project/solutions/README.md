# Solution notes for variables_vault

Encrypted files cannot be shipped as solutions because they depend on the
passwords you chose. Plain text versions of what you encrypted:

group_vars/dev/vault.yml (vault ID dev, password D3vVault!)

    team_password_hash: "$6$Lab3DevS4lt$3vtrKE4r0V8aMPAt8oozRN0XZ94sn1mavKbGtjLUsZHwufWVbuNwwLTwyKerJvglZFUzt/9rdoOpQjkFADyha0"

group_vars/prod/vault.yml (vault ID prod, password Pr0dVault!)

    team_password_hash: "$6$Lab3PrdS4lt$cktjpoar2OgMMU1ivAkWzpSMGvx5MPk8pxdZsDVQXTB8E3gMhF4OIyLOyFEYz.Pm1WuABmpCQO5xrXrDgCMsV/"

Both hashes correspond to the login password redhat.
