# ponytail: fake nvm.sh for testing lazy-load wrappers, not real nvm.
# Sourced exactly like real nvm.sh: defines an `nvm` shell function and
# puts a fake node/npm on PATH, simulating "nvm use" already having run.
: "${NVM_FAKE_BIN:?NVM_FAKE_BIN not set}"
mkdir -p "$NVM_FAKE_BIN"

cat > "$NVM_FAKE_BIN/node" <<'EOF'
#!/usr/bin/env sh
echo "fake-node $*"
EOF
cat > "$NVM_FAKE_BIN/npm" <<'EOF'
#!/usr/bin/env sh
echo "fake-npm $*"
EOF
chmod +x "$NVM_FAKE_BIN/node" "$NVM_FAKE_BIN/npm"

export PATH="$NVM_FAKE_BIN:$PATH"

nvm() {
  echo "fake-nvm $*"
}
