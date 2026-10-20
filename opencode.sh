cat > $PREFIX/bin/oc-install <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# oc-install [--update]   (OC_VERSION=x.y.z de ghim ban)
P=${PREFIX:-/data/data/com.termux/files/usr}; D=$HOME/.opencode; B=$D/bin/opencode; L=$P/glibc/lib/ld-linux-aarch64.so.1
die(){ echo "!! $*" >&2; exit 1; }
cl(){ env -u LD_PRELOAD -u LD_LIBRARY_PATH "$@"; }
ok(){ o=$(cl timeout 30 "$1" --version 2>&1) && echo "$o" | grep -Eq '[0-9]+\.[0-9]+'; }
stamp(){ [ "$(cl patchelf --print-interpreter $B 2>/dev/null)" = "$L" ] && stat -c '%s %Y' $B > $D/.patched; }
undo(){ [ -f $B.prev ] && mv -f $B.prev $B && stamp; }

if [ ! -x $L ] || ! command -v patchelf >/dev/null || ! curl --version >/dev/null 2>&1; then
  A="env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confnew"
  $A update && $A full-upgrade && $A install glibc-repo && $A update && $A install glibc-runner patchelf curl tar || die "apt loi (thu: termux-change-repo)"
fi
if [ "$1" = --update ] || [ ! -f $B ]; then
  [ -f $B ] && cp -p $B $B.prev
  S=$P/tmp/oc-shim; mkdir -p $S; printf '#!%s/bin/sh\ncommand -v "$@"\n' $P > $S/which; chmod +x $S/which
  curl -fsSL https://opencode.ai/v2/install -o $S/i.sh || die "khong tai duoc installer"
  set -- --no-modify-path; [ -n "$OC_VERSION" ] && set -- "$@" --version "$OC_VERSION"
  PATH=$S:$PATH bash $S/i.sh "$@" || { rm -rf $S; undo; die "installer loi (giu ban cu)"; }
  rm -rf $S $D/.patched
fi
if [ "$(cl patchelf --print-interpreter $B 2>/dev/null)" != "$L" ]; then
  cp -f $B $B.new && cl patchelf --set-interpreter $L $B.new && chmod 755 $B.new && ok $B.new && mv -f $B.new $B \
    || { rm -f $B.new; undo; die "va that bai (opencode van chay tam qua loader)"; }
elif ! ok $B; then undo; die "binary hong, thu: oc-install --update"; fi
stamp && rm -f $B.prev || die "khong ghi duoc dau va"

sed -i '/alias opencode/d;/\.opencode\/bin/d' ~/.bashrc 2>/dev/null
cat > $P/bin/opencode <<'W'
#!/data/data/com.termux/files/usr/bin/sh
P=${PREFIX:-/data/data/com.termux/files/usr}; D=$HOME/.opencode; B=$D/bin/opencode; L=$P/glibc/lib/ld-linux-aarch64.so.1
case $1 in upgrade|update) exec oc-install --update;; esac
export OPENCODE_DISABLE_AUTOUPDATE=1; unset LD_PRELOAD LD_LIBRARY_PATH
[ -x $B ] && [ -x $L ] || { echo "opencode: thieu binary/loader, chay: oc-install" >&2; exit 127; }
[ "$(cat $D/.patched 2>/dev/null)" = "$(stat -c '%s %Y' $B)" ] || { echo "opencode: chua va, chay: oc-install (chay tam)" >&2; exec $L --library-path $P/glibc/lib $B "$@"; }
exec $B "$@"
W
chmod +x $P/bin/opencode; hash -r; sh $P/bin/opencode --version && echo "Xong"
EOF
chmod +x $PREFIX/bin/oc-install
hash -r
oc-install
