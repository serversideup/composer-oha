## oha — Composer-distributed oha binary for PHP apps

**Goal**: Make the [`oha`](https://github.com/hatoo/oha) HTTP load generator easily available in PHP projects via Composer, without requiring Rust or manual installs.

- **Upstream project**: [hatoo/oha](https://github.com/hatoo/oha)
- **What this package does**: Vendors prebuilt `oha` binaries and exposes a tiny wrapper so you can run it as `vendor/bin/oha` inside your PHP app or CI.
- **What it does not do**: It does not modify upstream code or behavior. It only redistributes the binaries and adds a small launcher script.

### Installation

```bash
composer require serversideup/oha
```

### Usage

After installation, the executable is available at `vendor/bin/oha`:

```bash
vendor/bin/oha --help
vendor/bin/oha -z 15s -c 50 --no-tui --output-format json http://localhost:8080/
```

You can pass through all flags supported by upstream `oha` (see upstream README for full options).

### How it works

- This package ships platform-specific upstream binaries in `bin/` and a tiny launcher at `bin/oha`.
- When you run `vendor/bin/oha`, the launcher detects your OS/architecture and executes the matching bundled binary.
- Binaries are taken as-is from upstream releases and simply renamed to include their target triple (e.g., `oha_aarch64-unknown-linux-musl`).
- The Linux binaries are statically linked (musl + rustls), so they run on any Linux distribution — glibc or not — on both x86_64 and ARM64.

### Supported platforms

Currently bundled targets:

- aarch64-apple-darwin (Apple Silicon macOS)
- x86_64-unknown-linux-musl (Linux x86_64, static)
- aarch64-unknown-linux-musl (Linux ARM64, static)

Notes:

- Intel macOS is not currently supported by the launcher. On unsupported systems, the script will exit with an error.
- Windows is not supported.

### Versioning & releases

- **Upstream pin**: the single source of truth is `OHA_VERSION` in `download-oha-release.sh`. A scheduled GitHub Action (`sync-oha.yml`) checks [hatoo/oha](https://github.com/hatoo/oha/releases) daily and opens an auto-merging PR that bumps the pin and re-vendors the binaries when upstream publishes a new release.
- **Package releases**: tagged with CalVer (e.g. `v2026.07.07`). Publishing a GitHub release is all that's needed — Packagist watches this repository and picks up new tags automatically. The `release.yml` workflow re-verifies the vendored binaries on every release.
- **Development version**: every push to `main` is tested (binaries executed on x86_64 Linux, ARM64 Linux, and macOS ARM runners, checksums verified against upstream). Install the latest development state with:

```bash
composer require serversideup/oha:dev-main
```

### Binary verification

Every vendored binary is verified against the sha256 digest that GitHub reports for the corresponding upstream release asset — at download time, on every push/PR, and again when a release is published. You can re-verify a checkout at any time:

```bash
./download-oha-release.sh --verify-only
```

### Security & provenance

- You are executing a prebuilt third-party binary within your PHP project/CI.
- Binaries originate from upstream GitHub Releases of `oha`. Consider verifying checksums/signatures against the upstream release assets when appropriate.

### License

- This Composer package: MIT (see `composer.json`).
- Upstream `oha`: MIT License. See upstream project for details.

### Credits and attribution

- All credit for the `oha` implementation goes to the upstream maintainer: [hatoo/oha](https://github.com/hatoo/oha).
- This repository is an independent, open-source redistribution for Composer-based workflows and is **not affiliated with or maintained by** the upstream project.
