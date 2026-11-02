#!/usr/bin/env python3
"""Collect the runtime closure without bundling or replacing system glibc."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile

root = Path('/work/out/easygit-linux-x86_64')
prefix = Path('/opt/easygit-runtime')
if root.exists():
    shutil.rmtree(root)
(root / 'bin').mkdir(parents=True)
(root / 'lib').mkdir()
shutil.copy2('/work/src-tauri/target/release/easygit', root / 'bin/easygit')
for name in ('bin', 'lib', 'libexec', 'share'):
    if (prefix / name).exists():
        shutil.copytree(prefix / name, root / name, dirs_exist_ok=True, symlinks=False)
shutil.copy2('/usr/bin/bwrap', root / 'bin/bwrap')
# GTK needs its image loaders and MIME/schema databases in addition to ELF libraries.
for source, target in (
    ('/usr/lib64/gdk-pixbuf-2.0', 'lib/gdk-pixbuf-2.0'),
    ('/usr/lib64/gio/modules', 'lib/gio/modules'),
    ('/usr/share/glib-2.0/schemas', 'share/glib-2.0/schemas'),
    ('/usr/share/mime', 'share/mime'),
):
    if Path(source).exists():
        shutil.copytree(source, root / target, dirs_exist_ok=True, symlinks=False)
# These belong to the target's glibc and must never be mixed with our build host.
glibc = re.compile(r'^(ld-linux.*|lib(c|m|dl|pthread|rt|resolv|util|anl|nss_.*)\.so(?:\..*)?)$')
queue = [p for p in root.rglob('*') if p.is_file() and p.open('rb').read(4) == b'\x7fELF']
seen = set()
while queue:
    binary = queue.pop()
    if binary in seen:
        continue
    seen.add(binary)
    result = subprocess.run(['ldd', str(binary)], text=True, capture_output=True)
    if 'not found' in result.stdout:
        raise RuntimeError(f'Unresolved dependencies: {binary}\n{result.stdout}')
    for source in re.findall(r'=> (/\S+) \(', result.stdout):
        source = Path(source)
        if glibc.match(source.name):
            continue
        target = root / 'lib' / source.name
        if not target.exists():
            shutil.copy2(source, target)
            queue.append(target)
# Audit every bundled ELF, not just the executable.
report = []
for binary in sorted(root.rglob('*')):
    if not binary.is_file() or binary.open('rb').read(4) != b'\x7fELF':
        continue
    output = subprocess.check_output(['readelf', '--version-info', str(binary)], text=True)
    versions = set(re.findall(r'GLIBC_(\d+\.\d+(?:\.\d+)?)', output))
    for version in versions:
        if tuple(map(int, version.split('.'))) > (2, 28):
            raise RuntimeError(f'{binary} requires GLIBC_{version}')
    report.append(f'{binary.relative_to(root)}: {", ".join(sorted(versions))}')
(root / 'glibc-audit.txt').write_text('\n'.join(report) + '\n')
(root / 'start.sh').write_text('''#!/usr/bin/env bash
set -euo pipefail
APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export EASYGIT_BWRAP="$APP_DIR/bin/bwrap"
export EASYGIT_DBUS_PROXY="$APP_DIR/bin/xdg-dbus-proxy"
export LD_LIBRARY_PATH="$APP_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$APP_DIR/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export GSETTINGS_SCHEMA_DIR="$APP_DIR/share/glib-2.0/schemas"
export GIO_MODULE_DIR="$APP_DIR/lib/gio/modules"
export WEBKIT_EXEC_PATH="$APP_DIR/libexec/webkit2gtk-4.1"
export WEBKIT_INJECTED_BUNDLE_PATH="$APP_DIR/lib/webkit2gtk-4.1/injected-bundle"
export WEBKIT_RESOURCES_PATH="$APP_DIR/share/webkitgtk-4.1"
exec "$APP_DIR/bin/easygit" "$@"
''')
(root / 'start.sh').chmod(0o755)
(root / 'README.txt').write_text('''Experimental Rocky Linux 8 x86_64 portable build (glibc 2.28).
Extract and run ./start.sh from a graphical desktop. Git must be installed.
No root access or dnf is required on the target. System glibc is not included.
AI API key storage is unavailable on Linux in upstream.
This initial WebKitGTK 2.40.5 build is a compatibility experiment using an old
engine; do not use it for untrusted web content. Target-device GUI validation
is still required. See glibc-audit.txt for bundled ELF symbol requirements.
''')
with tarfile.open('/work/out/easygit-linux-x86_64.tar.gz', 'w:gz') as archive:
    archive.add(root, arcname=root.name)
print('Created /work/out/easygit-linux-x86_64.tar.gz')
