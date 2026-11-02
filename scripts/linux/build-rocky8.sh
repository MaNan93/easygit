#!/usr/bin/env bash
set -euo pipefail
cd /work
# All build-time changes occur inside the disposable Rocky Linux container.
dnf -y install dnf-plugins-core epel-release
dnf config-manager --set-enabled powertools
dnf -y install gcc-toolset-12-gcc-c++ make cmake ninja-build python39 python39-pip \
  git curl tar xz unzip patch pkgconf-pkg-config bison flex gperf ruby perl unifdef libseccomp-devel \
  gtk3-devel libappindicator-gtk3-devel glib2-devel libffi-devel pcre2-devel \
  libxml2-devel libxslt-devel sqlite-devel libicu-devel libjpeg-turbo-devel \
  libpng-devel libwebp-devel libgcrypt-devel libsecret-devel libtasn1-devel \
  libXt-devel libepoxy-devel mesa-libEGL-devel mesa-libGL-devel \
  libXcomposite-devel libXdamage-devel libXrandr-devel libnotify-devel \
  harfbuzz-devel hyphen-devel enchant2-devel brotli-devel zlib-devel \
  gnutls-devel libpsl-devel libnghttp2-devel bubblewrap gettext-devel xorg-x11-server-Xvfb dbus-x11 binutils
set +u
source /opt/rh/gcc-toolset-12/enable
set -u
python3.9 -m pip install 'meson==1.2.3' 'ninja==1.11.1.1' 'cmake==3.27.9'
export PATH="/usr/local/bin:$PATH"
export PREFIX=/opt/easygit-runtime
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig:$PREFIX/share/pkgconfig"
export LD_LIBRARY_PATH="$PREFIX/lib:$PREFIX/lib64:${LD_LIBRARY_PATH:-}"
export CMAKE_PREFIX_PATH="$PREFIX"
export CFLAGS="-O2 -fPIC"
export CXXFLAGS="-O2 -fPIC"
mkdir -p /build "$PREFIX" /work/out
cd /build
fetch() { curl --fail --location --retry 4 "$1" -o "$2"; tar -xf "$2"; }
if ! pkg-config --exists 'webkit2gtk-4.1 >= 2.40'; then
  fetch https://download.gnome.org/sources/glib/2.70/glib-2.70.5.tar.xz glib.tar.xz
  meson setup glib-build glib-2.70.5 --prefix="$PREFIX" --libdir=lib \
    -Dtests=false -Dinstalled_tests=false -Dgtk_doc=false -Dman=false -Dselinux=disabled
  ninja -C glib-build -j2
  ninja -C glib-build install
  fetch https://download.gnome.org/sources/libsoup/3.2/libsoup-3.2.3.tar.xz soup.tar.xz
  meson setup soup-build libsoup-3.2.3 --prefix="$PREFIX" --libdir=lib \
    -Dtests=false -Dexamples=false -Dintrospection=disabled -Dvapi=disabled \
    -Dsysprof=disabled -Dtls_check=false -Ddocs=disabled
  ninja -C soup-build -j2
  ninja -C soup-build install
  fetch https://github.com/flatpak/xdg-dbus-proxy/releases/download/0.1.5/xdg-dbus-proxy-0.1.5.tar.xz proxy.tar.xz
  meson setup proxy-build xdg-dbus-proxy-0.1.5 --prefix="$PREFIX" --libdir=lib -Dman=disabled
  ninja -C proxy-build -j2
  ninja -C proxy-build install
  fetch https://github.com/unicode-org/icu/releases/download/release-72-1/icu4c-72_1-src.tgz icu.tgz
  (cd icu/source && ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib" --disable-tests --disable-samples && make -j2 && make install)
  fetch https://github.com/harfbuzz/harfbuzz/releases/download/6.0.0/harfbuzz-6.0.0.tar.xz harfbuzz.tar.xz
  meson setup harfbuzz-build harfbuzz-6.0.0 --prefix="$PREFIX" --libdir=lib -Dicu=enabled -Dtests=disabled -Ddocs=disabled -Dintrospection=disabled
  ninja -C harfbuzz-build -j2
  ninja -C harfbuzz-build install
  fetch https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.38.tar.xz gtk.tar.xz
  meson setup gtk-build gtk+-3.24.38 --prefix="$PREFIX" --libdir=lib \
    -Dwayland_backend=false -Dbroadway_backend=false -Dintrospection=false \
    -Dtests=false -Dinstalled_tests=false -Ddemos=false -Dexamples=false \
    -Dgtk_doc=false -Dman=false -Dprint_backends=file,lpr
  ninja -C gtk-build -j2
  ninja -C gtk-build install
  fetch https://webkitgtk.org/releases/webkitgtk-2.40.5.tar.xz webkit.tar.xz
  # Keep sandboxing enabled; allow only the upstream relocation hooks in release builds.
  python3.9 - <<'PY'
from pathlib import Path
for p in Path('webkitgtk-2.40.5/Source/WebKit').rglob('*.cpp'):
    text = p.read_text()
    if 'WEBKIT_EXEC_PATH' in text or 'WEBKIT_INJECTED_BUNDLE_PATH' in text:
        p.write_text(text.replace('#if ENABLE(DEVELOPER_MODE)', '#if 1'))
for p in Path('webkitgtk-2.40.5/Source/WebKit/UIProcess/Launcher/glib').glob('*.cpp'):
    text = p.read_text()
    for macro, env in [('BWRAP_EXECUTABLE', 'EASYGIT_BWRAP'), ('DBUS_PROXY_EXECUTABLE', 'EASYGIT_DBUS_PROXY')]:
        text = text.replace(macro, f'(g_getenv("{env}") ? g_getenv("{env}") : {macro})')
    p.write_text(text)
PY
  cmake -S webkitgtk-2.40.5 -B webkit-build -G Ninja \
    -DPORT=GTK -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_INSTALL_LIBDIR=lib -DUSE_SOUP2=OFF -DENABLE_INTROSPECTION=OFF \
    -DENABLE_DOCUMENTATION=OFF -DENABLE_MINIBROWSER=OFF -DENABLE_GAMEPAD=OFF \
    -DENABLE_VIDEO=OFF -DENABLE_WEB_AUDIO=OFF -DUSE_WOFF2=OFF \
    -DENABLE_WAYLAND_TARGET=OFF -DUSE_WPE_RENDERER=OFF -DUSE_AVIF=OFF -DUSE_JPEGXL=OFF -DUSE_LIBBACKTRACE=OFF
  cmake --build webkit-build --parallel 2
  cmake --install webkit-build
fi
pkg-config --modversion webkit2gtk-4.1
cd /build
curl --fail --location --retry 4 https://nodejs.org/dist/v22.14.0/node-v22.14.0-linux-x64.tar.xz -o node.tar.xz
tar -xf node.tar.xz
export PATH="/build/node-v22.14.0-linux-x64/bin:$PATH"
curl --fail --location --retry 4 https://sh.rustup.rs -o rustup.sh
sh rustup.sh -y --profile minimal --default-toolchain stable
source "$HOME/.cargo/env"
cd /work
npm ci
npm run check
npm run tauri:build -- --no-bundle
cargo test --locked --manifest-path src-tauri/Cargo.toml --lib -- --test-threads=2
python3.9 scripts/linux/package-portable.py
