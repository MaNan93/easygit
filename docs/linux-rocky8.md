# Rocky Linux 8 portable build

Target: x86_64, glibc 2.28. Builds and runtime compatibility are not yet verified.

The desktop UI is retained. WebKitGTK API 4.1 (GTK 3 / libsoup 3) and its runtime files must be supplied with the portable package; the target machine does not need dnf or root access. Git and a graphical desktop are required on the target.

Linux currently cannot save AI API keys: upstream deliberately rejects this operation when Windows DPAPI is unavailable. Do not replace this with plaintext storage.
