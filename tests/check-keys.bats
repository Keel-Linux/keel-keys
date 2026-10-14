#!/usr/bin/env bats
# bin/check-keys: each key file agrees with FINGERPRINTS.

bats_require_minimum_version 1.5.0
load helpers

@test "the keys of this repository agree with FINGERPRINTS" {
    run "$CHECK"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    [ "${lines[0]}" = "main AD0964BE3F09DED469A3B6B2148E951314703180 ok" ]
}

@test "the 4 roles of decision 0055 are listed, each with its own file" {
    run awk '!/^#/ && NF { print $1 }' "$REPO/FINGERPRINTS"
    [ "$output" = "$(printf 'main\nimages\nsecurity\ntesting')" ]
    for role in main images security testing; do
        [ -f "$REPO/keys/keel-trixie-$role.asc" ]
    done
}

@test "a tree of throwaway keys passes, and comments and empty lines are skipped" {
    make_role main > /dev/null
    make_role images > /dev/null
    printf '# a comment\n\n' >> "$TREE/FINGERPRINTS"
    run "$CHECK" "$TREE"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "a fingerprint that is not the one of the key file fails" {
    make_role main > /dev/null
    printf 'main %s\n' "$(printf 'A%.0s' {1..40})" > "$TREE/FINGERPRINTS"
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FINGERPRINTS says"* ]]
}

@test "a file with 2 primary keys fails, so keys are never merged" {
    make_role main > /dev/null
    make_role images > /dev/null
    gpg --batch --armor --export > "$TREE/keys/keel-trixie-main.asc" 2> /dev/null
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"holds 2 primary keys"* ]]
}

@test "a file with secret key material fails" {
    fpr="$(make_role main)"
    gpg --batch --armor --pinentry-mode loopback --passphrase '' \
        --export-secret-keys "$fpr" > "$TREE/keys/keel-trixie-main.asc" 2> /dev/null
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not an armored public key block"* ]]
}

@test "a public block that carries a secret block after it fails" {
    fpr="$(make_role main)"
    gpg --batch --armor --pinentry-mode loopback --passphrase '' \
        --export-secret-keys "$fpr" >> "$TREE/keys/keel-trixie-main.asc" 2> /dev/null
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"holds secret key material"* ]]
}

@test "a binary key file fails" {
    fpr="$(make_role main)"
    gpg --batch --export "$fpr" > "$TREE/keys/keel-trixie-main.asc" 2> /dev/null
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not an armored public key block"* ]]
}

@test "a file that gpg cannot read fails as 0 primary keys" {
    make_role main > /dev/null
    printf -- '-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nAAAA\n-----END PGP PUBLIC KEY BLOCK-----\n' \
        > "$TREE/keys/keel-trixie-main.asc"
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"holds 0 primary keys"* ]]
}

@test "a key whose only signing subkey has expired fails" {
    fpr="$(make_role main)"
    sub="$(gpg --batch --with-colons --list-keys "$fpr" | awk -F: '$1 == "fpr" { n++ } n == 2 { print $10; exit }')"
    gpg --batch --quiet --pinentry-mode loopback --passphrase '' \
        --quick-set-expire "$fpr" seconds=1 "$sub" 2> /dev/null
    sleep 2
    gpg --batch --armor --export "$fpr" > "$TREE/keys/keel-trixie-main.asc" 2> /dev/null
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no signing subkey that is valid"* ]]
}

@test "a role without its key file fails" {
    make_role main > /dev/null
    rm "$TREE/keys/keel-trixie-main.asc"
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"is missing"* ]]
}

@test "a key file without its line in FINGERPRINTS fails" {
    make_role main > /dev/null
    make_role images > /dev/null
    sed -i '/^images /d' "$TREE/FINGERPRINTS"
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"keel-trixie-images.asc has no line in FINGERPRINTS"* ]]
}

@test "a role or a fingerprint that occurs 2 times fails" {
    fpr="$(make_role main)"
    printf 'main %s\nimages %s\n' "$fpr" "$fpr" >> "$TREE/FINGERPRINTS"
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"role main occurs 2 times"* ]]
    [[ "$output" == *"$fpr occurs 2 times"* ]]
}

@test "a line that is not ROLE FINGERPRINT fails" {
    make_role main > /dev/null
    printf 'Images abc\nmain %s extra\n' "$(printf 'A%.0s' {1..40})" >> "$TREE/FINGERPRINTS"
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [ "$(grep -c 'is not .ROLE FINGERPRINT' <<< "$output")" -eq 2 ]
}

@test "a FINGERPRINTS that names no role fails" {
    run "$CHECK" "$TREE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"names no role"* ]]
}

@test "a missing FINGERPRINTS and a bad usage exit 2" {
    rm "$TREE/FINGERPRINTS"
    run "$CHECK" "$TREE"
    [ "$status" -eq 2 ]
    run "$CHECK" a b
    [ "$status" -eq 2 ]
    run "$CHECK" --help
    [ "$status" -eq 2 ]
}
