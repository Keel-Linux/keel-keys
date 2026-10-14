#!/usr/bin/env bats
# The package build: 1 keyring file for each role, the fingerprint file of
# main unchanged, and a build that fails on a key nobody checked.
# dpkg-buildpackage runs with -d: the runner of the coverage job is not
# Debian, and the job "build / trixie" checks the build dependencies.

bats_require_minimum_version 1.5.0
load helpers

# build_tree: a copy of the repository, built as a binary package.
build_tree() {
    cp -a "$REPO" "$TMP/src"
    rm -rf "$TMP/src/.git" "$TMP/src/coverage"
    (cd "$TMP/src" && dpkg-buildpackage -us -uc -b -d > "$TMP/build.log" 2>&1) || { cat "$TMP/build.log"; return 1; }
}

@test "the package installs 1 keyring for each role and the fingerprint files" {
    command -v dpkg-buildpackage > /dev/null || skip "dpkg-buildpackage is not installed"
    build_tree
    deb="$(ls "$TMP"/keel-archive-keyring_*_all.deb)"
    dpkg-deb -x "$deb" "$TMP/x"
    for ring in archive images security testing; do
        run gpg --batch --with-colons --show-keys "$TMP/x/usr/share/keyrings/keel-$ring-keyring.gpg"
        [ "$(grep -c '^pub:' <<< "$output")" -eq 1 ]
    done
    [ -f "$TMP/x/usr/share/keyrings/keel-archive-keyring.asc" ]
    [ "$(cat "$TMP/x/usr/share/keel-archive-keyring/fingerprint")" = AD0964BE3F09DED469A3B6B2148E951314703180 ]
    run grep -c . "$TMP/x/usr/share/keel-archive-keyring/FINGERPRINTS"
    [ "$output" -eq 4 ]
    run gpg --batch --with-colons --show-keys "$TMP/x/usr/share/keyrings/keel-security-keyring.gpg"
    grep -q '^fpr:.*:D97E853FBDBB24492002067BA92969F1BF3B71C6:' <<< "$output"
}

@test "the build fails when FINGERPRINTS and debian/rules do not agree" {
    command -v dpkg-buildpackage > /dev/null || skip "dpkg-buildpackage is not installed"
    cp -a "$REPO" "$TMP/src"
    rm -rf "$TMP/src/.git" "$TMP/src/coverage"
    sed -i 's/^FPR_testing = .*/FPR_testing = 0000000000000000000000000000000000000000/' "$TMP/src/debian/rules"
    run bash -c "cd '$TMP/src' && dpkg-buildpackage -us -uc -b -d"
    [ "$status" -ne 0 ]
    run ls "$TMP"/keel-archive-keyring_*_all.deb
    [ "$status" -ne 0 ]
}
