# Shared setup of the bats suite. Every key here is a throwaway key that
# the test makes and deletes. No test reads a secret key of the project.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
export CHECK="$REPO/bin/check-keys"

setup() {
    TMP="$(mktemp -d)"
    export GNUPGHOME="$TMP/gnupg"
    mkdir -m 700 "$GNUPGHOME"
    TREE="$TMP/tree"
    mkdir -p "$TREE/keys"
    : > "$TREE/FINGERPRINTS"
}

teardown() {
    rm -rf "$TMP"
}

# make_role ROLE [SUBKEY_EXPIRY]: a throwaway certify-only primary with 1
# signing subkey, exported as $TREE/keys/keel-trixie-ROLE.asc and listed in
# $TREE/FINGERPRINTS. Echoes the primary fingerprint.
make_role() {
    local role="$1" expiry="${2:-3y}" fpr
    gpg --batch --quiet --passphrase '' --pinentry-mode loopback \
        --quick-generate-key "Test $role <$role@example.invalid>" ed25519 cert never 2> /dev/null
    fpr="$(gpg --batch --with-colons --list-keys "$role@example.invalid" | awk -F: '$1 == "fpr" { print $10; exit }')"
    gpg --batch --quiet --passphrase '' --pinentry-mode loopback \
        --quick-add-key "$fpr" ed25519 sign "$expiry" 2> /dev/null
    gpg --batch --armor --export "$fpr" > "$TREE/keys/keel-trixie-$role.asc" 2> /dev/null
    printf '%s %s\n' "$role" "$fpr" >> "$TREE/FINGERPRINTS"
    printf '%s\n' "$fpr"
}
