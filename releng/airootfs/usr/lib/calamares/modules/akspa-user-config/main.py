#!/usr/bin/env python3

import os
import shutil
import subprocess


def find_user(target):
    passwd = os.path.join(target, "etc", "passwd")

    if not os.path.isfile(passwd):
        return None, None

    with open(passwd, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split(":")
            if len(parts) >= 7 and parts[2] == "1000":
                return parts[0], parts[5]

    return None, None


def copy_skel(target, user_home):
    skel = os.path.join(target, "etc", "skel")

    if not os.path.isdir(skel) or not os.path.isdir(user_home):
        return

    for name in os.listdir(skel):
        src = os.path.join(skel, name)
        dst = os.path.join(user_home, name)

        if os.path.isdir(src):
            os.makedirs(dst, exist_ok=True)
            shutil.copytree(src, dst, dirs_exist_ok=True)
        else:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)


def fix_permissions(target, username, home):
    subprocess.run(
        ["chroot", target, "chown", "-R", f"{username}:{username}", home],
        check=False
    )

    subprocess.run(
        ["chroot", target, "chmod", "700", home],
        check=False
    )


def configure_kwin(user_home):
    kwinrc = os.path.join(user_home, ".config", "kwinrc")

    if not os.path.isfile(kwinrc):
        return

    with open(kwinrc, "r", encoding="utf-8") as f:
        data = f.read()

    replacements = {
        "better_blur_dxEnabled=false": "better_blur_dxEnabled=true",
        "blurEnabled=true": "blurEnabled=false",
    }

    for old, new in replacements.items():
        data = data.replace(old, new)

    with open(kwinrc, "w", encoding="utf-8") as f:
        f.write(data)


def run():
    target = "/mnt"

    if not os.path.isdir(target):
        return

    username, home = find_user(target)

    if not username or not home:
        return

    user_home = os.path.join(target, home.lstrip("/"))

    if not os.path.isdir(user_home):
        return

    copy_skel(target, user_home)
    configure_kwin(user_home)
    fix_permissions(target, username, home)


def run_in_debug_mode():
    run()


def pretty_name():
    return "AKSPA User Configuration"


def pretty_description():
    return "Apply AKSPA configuration to the newly created user"


def pretty_status_message():
    return "Applying AKSPA user configuration..."


def name():
    return "akspa-user-config"


def cancel():
    pass


def get_widgets():
    return None
