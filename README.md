# keel-keys

This repository holds the public OpenPGP keys of Keel Linux. It is also
the source of the `keel-archive-keyring` Debian package. The model is the
`turnkey-keys` repository of TurnKey Linux. Handbook decision 0055 gives
the reasons.

## The roles

Keel Linux uses 4 signing roles. Each role has its own certificate, so a
key of one role cannot sign for another role.

| Role | Signs | Key file | Keyring that the package installs |
|---|---|---|---|
| main | the `Release` file of the `trixie` suite | `keys/keel-trixie-main.asc` | `/usr/share/keyrings/keel-archive-keyring.gpg` |
| security | the `Release` file of the `trixie-security` suite | `keys/keel-trixie-security.asc` | `/usr/share/keyrings/keel-security-keyring.gpg` |
| testing | the `Release` file of the `trixie-testing` suite | `keys/keel-trixie-testing.asc` | `/usr/share/keyrings/keel-testing-keyring.gpg` |
| images | the release `MANIFEST`, the layer `.hash` files and the Proxmox `aplinfo.dat.asc` | `keys/keel-trixie-images.asc` | `/usr/share/keyrings/keel-images-keyring.gpg` |

The main key is the key that installed appliances already trust. Its
keyring file keeps the name `keel-archive-keyring.gpg`.

`FINGERPRINTS` gives the primary key fingerprint of each role:

    main AD0964BE3F09DED469A3B6B2148E951314703180
    images E71DB9C3CA6AC18075395CC3ED3A709C4F3E2F3C
    security D97E853FBDBB24492002067BA92969F1BF3B71C6
    testing 9B3CFC527FAD0EA5298D84ED05B5A6FE7E3BA58A

## One keyring file for each role

Each apt source names the keyring file of its own role in `Signed-By`, and
no other file. Do not merge the keys into one keyring. `signed-by` trusts
every key in the file that it names. If you merge the keys, any role can
sign any suite.

An apt source for the main suite:

    Types: deb
    URIs: https://archive.keellinux.org
    Suites: trixie
    Components: main
    Signed-By: /usr/share/keyrings/keel-archive-keyring.gpg

## The keys

Each primary key only certifies keys, and it has no expiry. The maintainer
keeps the primary keys offline. Each role has 1 signing subkey, which
expires 3 years after it is made. The publisher of the archive stops with
the date when a signing subkey has less than 90 days left.

This repository holds public keys only. Secret keys and passphrases are
never put in this repository, in an issue or in a pull request.

## What the package installs

| File | Contents |
|---|---|
| `/usr/share/keyrings/keel-archive-keyring.gpg` | the main key, binary |
| `/usr/share/keyrings/keel-archive-keyring.asc` | the main key, armored |
| `/usr/share/keyrings/keel-images-keyring.gpg` | the images key, binary |
| `/usr/share/keyrings/keel-security-keyring.gpg` | the security key, binary |
| `/usr/share/keyrings/keel-testing-keyring.gpg` | the testing key, binary |
| `/usr/share/keel-archive-keyring/fingerprint` | the main primary key fingerprint, 1 line |
| `/usr/share/keel-archive-keyring/FINGERPRINTS` | 1 line for each role: the role and its fingerprint |

The package has no maintainer script. It does not add an apt source.

## The checks

`bin/check-keys` makes sure that each key file agrees with `FINGERPRINTS`.
It fails when:

- a key file holds more or less than 1 primary key;
- a key file holds secret key material, or is not armored;
- the fingerprint of a key file is not the fingerprint in `FINGERPRINTS`;
- a key has no signing subkey that is valid;
- a key file has no line in `FINGERPRINTS`, or a role has no key file.

The package build runs `bin/check-keys`. The build also compares
`FINGERPRINTS` with the fingerprints in `debian/rules`. So each
fingerprint has 3 sources that must agree: the key file, `FINGERPRINTS`
and `debian/rules`.

## How to change a key

1. Replace the key file in `keys/`.
2. If the primary key changes, change its line in `FINGERPRINTS` and its
   value in `debian/rules`.
3. Run `bin/check-keys` and `tests/coverage.sh`.
4. Add an entry to `debian/changelog` with a new version.

A new signing subkey under the same primary key changes the key file only.
A revocation also changes the key file only. The new package version
carries the revocation to each appliance.

## Tests

`tests/coverage.sh` runs the bats suite under kcov. The tests make
throwaway keys. No test reads a key of the project from a secret keyring.
CI builds the package on trixie, runs lintian and checks the keyring files.
