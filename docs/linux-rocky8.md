# Rocky Linux 8 portable build

Target: Linux x86_64, glibc 2.28. The desktop UI is retained.

## Build

Run the **Linux Rocky 8 portable** GitHub Actions workflow on main. It builds inside the Rocky-maintained `rockylinux/rockylinux:8.10` container, independently of the Ubuntu runner's system libraries.

The initial compatibility recipe builds GLib 2.70.5, libsoup 3.2.3, ICU 72.1, HarfBuzz 6.0.0, GTK 3.24.38 and WebKitGTK 2.40.5 (API 4.1) from upstream sources. GTK 3.24 is required by this Tauri version; Rocky 8's GTK 3.22 alone is insufficient. The older WebKit engine is for compatibility evaluation, not a current security-supported engine.

WebKit's release-build relocation hooks and sandbox helper paths are patched to allow an arbitrary extraction directory. Bubblewrap sandboxing is retained.

## Gates

- Frontend checks and release build.
- Rust library tests.
- Recursive dynamic-library collection, excluding system glibc.
- GLIBC symbol-version audit of every bundled ELF; anything above 2.28 fails.
- Extraction and ordinary-user window-launch smoke test in a clean Rocky 8 container.

A successful window-launch smoke test does not prove all application features or target graphics drivers work. Full real-device validation remains necessary. Failed workflow artifacts may contain diagnostics only; a downloadable ZIP containing just a log is not an application package.

## Run

Extract `easygit-linux-x86_64.tar.gz`, enter the extracted directory and run:

```bash
./start.sh
```

The target needs Git and a graphical desktop. It does not need dnf or root access. Host glibc and the graphics driver remain system-provided. Sandboxing requires the host kernel to permit the required user namespaces.

## Known limits

- AI API key storage is unavailable on Linux: upstream deliberately rejects this operation without Windows DPAPI. It is not replaced with plaintext storage.
- Desktop integrations and terminal launching depend on the target's installed desktop tools.
- Runtime packaging and device compatibility are not confirmed until the workflow gates and real-device tests pass.
