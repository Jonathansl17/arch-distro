# Theme 6: Package management · Owner: Magdaleno Gómez Díaz

## 1. What was implemented

- **Own package** `arch-distro-tools` (`pacman/PKGBUILD`), built with
  `makepkg` from the checkout. `build()` compiles `src/`, `check()` runs the C
  unit tests, `package()` installs every command, unit, hook, udev rule and
  the module blacklist. `lib/step-tools.sh` rebuilds it only when a sha256
  over the packaged sources changes (idempotency).
- **Own ALPM hook** `pacman/hooks/ad-pacnew.hook`. `PostTransaction` on any
  package install, upgrade or remove (`NeedsTargets`). It runs
  `ad-pacnew-check.sh`, which lists pending `.pacnew`/`.pacsave` files under
  `/etc` and appends the transaction to `/var/log/arch-distro/pacman-hook.log`.
- `ad-pkg` (`bin/ad-pkg`): local db, all hooks, `pactree`, file owner, log.

## 2. Operating systems concept

How pacman works internally:

- **Sync databases** `/var/lib/pacman/sync/*.db`: tarballs of each repo's
  metadata, downloaded by `pacman -Sy`.
- **Local database** `/var/lib/pacman/local/<name>-<ver>/`: one directory
  per installed package with `desc` (metadata, deps, install reason),
  `files` (every path it owns, used for conflicts and `-Qo`) and `mtree`
  (hashes/permissions, used by `-Qkk`).
- **Dependency resolution**: libalpm builds the transaction from
  `depends`/`provides`/`conflicts`, topologically sorted so dependencies
  install first.
- **Signatures**: packages and dbs are signed with GPG. `SigLevel` in
  `pacman.conf` sets the policy. The keyring is in `/etc/pacman.d/gnupg`,
  maintained by `archlinux-keyring` and `pacman-key`.
- **Hooks**: `.hook` files in `/usr/share/libalpm/hooks` (packages) and
  `/etc/pacman.d/hooks` (admin, same name overrides). Triggered by Path or
  Package, run `PreTransaction` or `PostTransaction`.
- Related course topic: software management and system programs.
  Silberschatz et al. 10th ed., ch. 2 (Operating-System Services, System
  Programs, Linkers and Loaders).

## 3. Measurement method

```sh
experiments/exp-06-pkg.sh
```

`pacman -Qi`, `-Ql`, `-Qkk arch-distro-tools`. Contents of its local-db
entry. `ad-pkg hooks`. A real transaction (`sudo pacman -S pacman-contrib`,
a reinstall) with the hook output and log. `pactree -d 2 openssh` and
`pactree -r -d 1 openssh`.

## 4. Results

VM, 2026-11-09 19:35 UTC. Raw data: `results/tema-06/<ts>/1-package.txt` …
`4-deps.txt`. The same output came out in all 4 runs.

**Own package** (`pacman -Qi arch-distro-tools`, abridged):

```text
Name            : arch-distro-tools
Version         : 1.0.0-1
Depends On      : bash  glibc  systemd  pciutils  kmod  pacman-contrib  util-linux
Optional Deps   : snapper: ad-snap on btrfs roots [installed]
                  nftables: ad-sec firewall report [installed]
                  strace: tracing ad-ipc [installed]
Installed Size  : 97.35 KiB
Install Reason  : Explicitly installed
Validated By    : None
```

`pacman -Ql` lists 10 commands in `/usr/bin` (`ad-boot`, `ad-dev`,
`ad-info`, `ad-ipc`, `ad-mem`, `ad-pkg`, `ad-ps`, `ad-sec`, `ad-snap`,
`ad-svc`), the helper scripts in `/usr/lib/arch-distro/`, the module
blacklist, 4 systemd units, the udev rule and the hook.
`pacman -Qkk arch-distro-tools`: `35 total files, 0 altered files`.

**Local database** (`ad-pkg db`): 620 packages installed, 93 explicit,
2 orphans, `SigLevel = Required DatabaseOptional`.

**Hook in a real transaction** (`sudo pacman -S pacman-contrib`, a reinstall):

```text
:: Running post-transaction hooks...
(1/4) Reloading system manager configuration...
(2/4) Enqueuing marked services...
(3/4) Arming ConditionNeedsUpdate...
(4/4) arch-distro: checking for .pacnew/.pacsave files...
no .pacnew/.pacsave files pending
```

and the hook log (`/var/log/arch-distro/pacman-hook.log`):

```text
2026-11-09T19:18:48+00:00 transaction: 1 package(s): arch-distro-tools
2026-11-09T19:18:48+00:00 pending: none
2026-11-09T19:35:56+00:00 transaction: 1 package(s): pacman-contrib
2026-11-09T19:35:56+00:00 pending: none
```

**Dependency tree** (`pactree -d 2 openssh`, abridged): direct dependencies
`glibc`, `krb5`, `libedit`, `libxcrypt`, `openssl`, `pam`, `zlib`, plus
soname provides such as `krb5 provides libkrb5.so=3-64` and
`openssl provides libcrypto.so=3-64`. Reverse (`pactree -r -d 1`):
`openssh` is required only by `gcr-4`. `pacman -Qi openssh`: version
10.6p1-2, `Install Reason: Installed as a dependency for another package`,
`Validated By: Signature`.

## 5. Interpretation

- **The hook ran because of its trigger.** `Type = Package` with
  `Target = *` and `Operation = Install/Upgrade/Remove` matches any package
  in any transaction, so even a reinstall of `pacman-contrib` fired it.
  Hooks run in the order of their file names. `ad-pacnew.hook` sorts after
  the numbered systemd hooks, which is why it was 4/4. `NeedsTargets` makes
  pacman pass the matched package names on stdin, and that is how the log
  line knows it was `pacman-contrib`. The 19:18 line is the hook firing
  when `install.sh` installed `arch-distro-tools` itself.
- **Local database and `-Qkk`.** Every installed package has a directory in
  `/var/lib/pacman/local/` with `desc`, `files` and `mtree`. `-Ql` reads
  `files`. `-Qkk` compares each file on disk with the size, mode and sha256
  stored in `mtree`. 0 altered files means nothing from the package was
  modified after install. Editing, say, `/usr/bin/ad-info` by hand would
  show up there.
- **Signatures.** `openssh` says `Validated By: Signature`: its package came
  from the repo signed by an Arch packager and pacman checked it against the
  keyring (`SigLevel = Required` for packages). `arch-distro-tools` says
  `None`: it was built locally with `makepkg` and installed with
  `pacman -U`, which trusts local files the admin chose. Publishing it in a
  repo would require signing it.
- **Dependency resolution.** The tree shows two kinds of edges. Named
  dependencies (`krb5`) and soname dependencies (`libkrb5.so=3-64`), which
  `krb5` satisfies through `provides`. Soname dependencies let pacman catch
  a library ABI change: if a new `krb5` shipped `libkrb5.so=4`, `openssh`
  would no longer be satisfied. `glibc` and `openssl` appear several times
  because many packages depend on them; libalpm installs each only once and
  sorts the transaction so dependencies go first.
- **Install reason.** `arch-distro-tools` is explicit, `openssh` is a
  dependency. That flag is what makes `pacman -Qdt` find orphans (the 2
  orphans above) once nothing explicit needs them anymore.
