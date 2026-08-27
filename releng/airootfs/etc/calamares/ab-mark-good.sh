#!/usr/bin/env bash
for f in /boot/loader/entries/akspa-current+*.conf; do
    [ -e "$f" ] || continue
    mv "$f" /boot/loader/entries/akspa-current.conf
done
