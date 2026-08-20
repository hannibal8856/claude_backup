#!/usr/bin/env python3
"""Probe a Buildroot tree for serial-console autologin feasibility.

Path-independent: discovers the Buildroot root from CWD (or an explicit arg),
reads the *configured* .config rather than guessing a defconfig, then inspects
the built target/ rootfs. Prints a report and a recommended method.

Usage:  probe.py [buildroot_root_or_any_path_inside_it]
"""
import os, re, sys, glob, json

def find_root(start):
    p = os.path.abspath(start)
    while True:
        if (os.path.isdir(os.path.join(p, "package"))
                and os.path.isfile(os.path.join(p, "Makefile"))):
            return p
        nxt = os.path.dirname(p)
        if nxt == p:
            return None
        p = nxt

def read_config(root):
    """Prefer the configured build (output/.config); it is authoritative."""
    cands = [os.path.join(root, "output", ".config"), os.path.join(root, ".config")]
    cands += sorted(glob.glob(os.path.join(root, "output", "*", ".config")))
    for c in cands:
        if os.path.isfile(c):
            return c, open(c, errors="replace").read()
    return None, ""

def cfg(txt, key, default=None):
    m = re.search(r'^%s=(.*)$' % re.escape(key), txt, re.M)
    if not m:
        return default
    return m.group(1).strip().strip('"')

def out(label, value, note=""):
    print("  %-34s %s%s" % (label, value, ("   " + note) if note else ""))

def main():
    start = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    root = find_root(start)
    if not root:
        print("NOT A BUILDROOT TREE (no dir with package/ + Makefile above %s)" % start)
        return 2
    print("=== Buildroot root ===");  out("root", root)

    cpath, txt = read_config(root)
    if not cpath:
        print("\nNO .config FOUND — run `make <board>_defconfig` first, or point me at the tree.")
        return 2
    out(".config", cpath)

    # --- config facts -------------------------------------------------------
    systemd   = cfg(txt, "BR2_INIT_SYSTEMD") == "y"
    busybox   = cfg(txt, "BR2_INIT_BUSYBOX") == "y"
    sysv      = cfg(txt, "BR2_INIT_SYSV") == "y"
    port      = cfg(txt, "BR2_TARGET_GENERIC_GETTY_PORT", "")
    baud      = cfg(txt, "BR2_TARGET_GENERIC_GETTY_BAUDRATE", "")
    squashfs  = cfg(txt, "BR2_TARGET_ROOTFS_SQUASHFS") == "y"
    postbuild = cfg(txt, "BR2_ROOTFS_POST_BUILD_SCRIPT", "")
    overlay   = cfg(txt, "BR2_ROOTFS_OVERLAY", "")
    rootlogin = cfg(txt, "BR2_TARGET_ENABLE_ROOT_LOGIN") == "y"
    init = "systemd" if systemd else ("busybox-init" if busybox else ("sysv" if sysv else "UNKNOWN"))

    print("\n=== config ===")
    out("init system", init)
    out("getty port", port or "(unset)")
    out("getty baudrate", baud or "(unset)")
    out("squashfs rootfs", squashfs, "(read-only -> must bake at build time)" if squashfs else "")
    out("post-build script", postbuild or "(none)")
    out("rootfs overlay", overlay or "(none)")
    out("root login enabled", rootlogin)

    if postbuild:
        pb = os.path.join(root, postbuild)
        out("post-build exists", os.path.isfile(pb))
        if os.path.isfile(pb):
            shared = len(set(re.findall(r'BR2_ROOTFS_POST_BUILD_SCRIPT="([^"]+)"',
                     "\n".join(open(f, errors="replace").read()
                               for f in glob.glob(os.path.join(root, "*/configs/*"))
                               if os.path.isfile(f)))))
            out("post-build shared by N configs",
                sum(1 for f in glob.glob(os.path.join(root, "*/configs/*"))
                    if os.path.isfile(f) and postbuild in open(f, errors="replace").read()),
                "<- editing it hits every one of them")

    # --- target rootfs facts ------------------------------------------------
    tgt = os.path.join(root, "output", "target")
    print("\n=== target rootfs (%s) ===" % ("present" if os.path.isdir(tgt) else "ABSENT - build first"))
    if not os.path.isdir(tgt):
        print("  (build at least once so these can be checked)")
        return 0

    def has(*rel):
        return any(os.path.exists(os.path.join(tgt, r)) for r in rel)

    out("agetty", has("sbin/agetty", "usr/sbin/agetty"), "(needed for --autologin)")
    out("login", has("bin/login", "usr/bin/login"), "(agetty runs `login -f <user>`)")
    out("busybox getty", has("sbin/getty", "bin/busybox"))

    # who is root, what shell
    pw = os.path.join(tgt, "etc/passwd")
    users = {}
    if os.path.isfile(pw):
        for l in open(pw, errors="replace"):
            f = l.split(":")
            if len(f) > 6:
                users[f[0]] = f[6].strip()
    out("root shell (build-time)", users.get("root", "NO root ENTRY"))
    out("build-time users", ", ".join(sorted(users)) or "(none)",
        "<- anything NOT here is created at runtime; do not autologin as it")

    # PAM
    pam = os.path.join(tgt, "etc/pam.d/login")
    if os.path.isfile(pam):
        body = [l.strip() for l in open(pam, errors="replace")
                if l.strip() and not l.startswith("#")]
        blockers = [l for l in body
                    if l.startswith("account") and
                    re.search(r'pam_(nologin|securetty|access|time|tally|faillock)', l)]
        out("pam.d/login account stage", "; ".join(l for l in body if l.startswith("account")) or "(none)")
        out("PAM blockers for `login -f`", blockers or "NONE",
            "<- `-f` skips auth, so only account/session matter")
    else:
        out("pam.d/login", "ABSENT", "(login likely not PAM-linked; -f still fine)")

    # getty units + who owns the tty
    if init == "systemd":
        units = []
        for d in ("lib/systemd/system", "usr/lib/systemd/system", "etc/systemd/system"):
            units += glob.glob(os.path.join(tgt, d, "*getty*"))
        out("serial-getty@.service", any("serial-getty@.service" in u for u in units))
        dropdirs = [u for u in units if u.endswith(".service.d")]
        out("existing drop-in dirs", [os.path.relpath(d, tgt) for d in dropdirs] or "(none)",
            "<- drop-in mechanism already in use" if dropdirs else "")
        wants = [d for d in glob.glob(os.path.join(tgt, "*/systemd/system/getty.target.wants"))
                 if os.path.isdir(d)]
        gen = has("lib/systemd/system-generators/systemd-getty-generator",
                  "usr/lib/systemd/system-generators/systemd-getty-generator")
        out("getty.target.wants symlinks", [os.path.relpath(w, tgt) for w in wants] or "(none)")
        out("systemd-getty-generator", gen,
            "<- instance comes from kernel console=; drop-in on the TEMPLATE still applies" if gen and not wants else "")
        # anyone else claiming the tty
        claim = []
        for d in ("lib/systemd/system", "usr/lib/systemd/system", "etc/systemd/system"):
            for p in glob.glob(os.path.join(tgt, d, "**", "*"), recursive=True):
                if os.path.isfile(p) and not os.path.islink(p) and "getty" not in os.path.basename(p):
                    try: s = open(p, errors="replace").read()
                    except Exception: continue
                    if re.search(r'TTYPath=|/dev/tty[A-Z]|/dev/console', s):
                        claim.append(os.path.relpath(p, tgt))
        out("other units touching a tty", sorted(set(claim)) or "(none)")
    else:
        out("/etc/inittab", os.path.isfile(os.path.join(tgt, "etc/inittab")),
            "<- non-systemd: autologin goes here, NOT a drop-in")

    # --- verdict ------------------------------------------------------------
    print("\n=== verdict ===")
    if init == "systemd":
        print("  method: systemd drop-in on serial-getty@.service (see SKILL.md)")
    elif init in ("busybox-init", "sysv"):
        print("  method: /etc/inittab respawn line with `-n -l /bin/sh` (see SKILL.md)")
    else:
        print("  method: UNKNOWN init - stop and ask the user")
    print("  delivery: %s" % ("BR2_ROOTFS_OVERLAY (preferred)" if True else ""))
    if postbuild:
        print("             or a flag-guarded block in %s (shared - see count above)" % postbuild)
    print("  autologin user: root  (only build-time users are safe)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
