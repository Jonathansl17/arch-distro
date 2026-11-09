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

Pending (VM). Paste: `pacman -Qi` (Name, Version, Install Reason, Required
By), the file list, the hook lines from the transaction, the pactree tree.

## 5. Interpretation

Pending. Explain the openssh tree: which deps are direct, which come in
transitively, and why `openssl` appears more than once. Explain why the hook
fired (`Target = *`) and what `NeedsTargets` passed on stdin. Explain why
`-Qkk` can detect a modified file of the package (mtree hash).
