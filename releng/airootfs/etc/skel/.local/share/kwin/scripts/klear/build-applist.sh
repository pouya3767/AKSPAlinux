#!/usr/bin/env bash
set -euo pipefail

PKG="${1:-${XDG_DATA_HOME:-$HOME/.local/share}/kwin/scripts/klear}"
DEFAULT_PKG="${XDG_DATA_HOME:-$HOME/.local/share}/kwin/scripts/klear"

if [ "$PKG" = "$DEFAULT_PKG" ]; then
    SYSD="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    need_reload=0
    for unit in klear-applist.service klear-applist.path; do
        src="$PKG/$unit"
        dst="$SYSD/$unit"
        if [ -f "$src" ] && { [ ! -L "$dst" ] || [ "$(readlink "$dst")" != "$src" ]; }; then
            mkdir -p "$SYSD"
            ln -sfn "$src" "$dst"
            need_reload=1
        fi
    done
    if [ "$need_reload" = 1 ]; then
        systemctl --user daemon-reload 2>/dev/null || true
    fi
    systemctl --user enable --now klear-applist.path 2>/dev/null || true

    AUTO_DST="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/klear-applist.desktop"
    if [ ! -f "$AUTO_DST" ]; then
        mkdir -p "$(dirname "$AUTO_DST")"
        cat > "$AUTO_DST" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Klear app-list refresh
Exec=sh -c '"${XDG_DATA_HOME:-$HOME/.local/share}/kwin/scripts/klear/build-applist.sh"'
X-KDE-autostart-phase=2
OnlyShowIn=KDE;
NoDisplay=true
DESKTOP
    fi
fi

UI="$PKG/contents/ui/config.ui"
XML="$PKG/contents/config/main.xml"
for f in "$UI" "$XML"; do
    [ -f "$f" ] || exit 0
    grep -q '<!-- APPLIST:START -->' "$f" || exit 0
done
grep -q '<!-- APPLIST_CONNECTIONS:START -->' "$UI" || exit 0

APP_DIRS=(
    /usr/share/applications
    /usr/local/share/applications
    "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
)

collect() {
    local f wmclass exec
    for dir in "${APP_DIRS[@]}"; do
        [ -d "$dir" ] || continue
        for f in "$dir"/*.desktop; do
            [ -e "$f" ] || continue
            grep -qi '^NoDisplay=true' "$f" && continue
            grep -qi '^Hidden=true' "$f" && continue
            wmclass=$(sed -n 's/^StartupWMClass=//p' "$f" | head -n1)
            if [ -z "$wmclass" ]; then
                exec=$(sed -n 's/^Exec=//p' "$f" | head -n1)
                exec=${exec%% *}
                wmclass=${exec##*/}
            fi
            [ -n "$wmclass" ] && printf '%s\n' "${wmclass,,}"
        done
    done | sort -u | sed '/^$/d'
}

ui_items=""
xml_items=""
ui_connections=""
declare -A seen=()
count=0
while IFS= read -r app; do
    key=$(printf '%s' "$app" | tr -cd 'a-z0-9')
    [ -n "$key" ] || continue
    [ -n "${seen[$key]:-}" ] && continue
    seen[$key]=1
    label=${app//&/&amp;}; label=${label//</&lt;}; label=${label//>/&gt;}
    ui_items+="       <item>
        <widget class=\"QCheckBox\" name=\"kcfg_exclude_${key}\">
         <property name=\"text\">
          <string>${label}</string>
         </property>
        </widget>
       </item>
"
    xml_items+="        <entry name=\"exclude_${key}\" type=\"Bool\">
            <default>false</default>
        </entry>
"
    ui_connections+="  <connection>
   <sender>selectAllExclusions</sender>
   <signal>toggled(bool)</signal>
   <receiver>kcfg_exclude_${key}</receiver>
   <slot>setChecked(bool)</slot>
  </connection>
"
    count=$((count + 1))
done < <(collect)

HASH=$(printf '%s' "$ui_items" | cksum | cut -d' ' -f1)
STAMP="$PKG/.applist.hash"
if [ "${KLEAR_FORCE:-}" != 1 ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$HASH" ] \
   && [ "$(grep -c 'name="kcfg_exclude_' "$UI")" = "$count" ] \
   && [ "$(grep -c '<receiver>kcfg_exclude_' "$UI")" = "$count" ]; then
    echo "App list unchanged ($count apps); nothing to do."
    exit 0
fi

splice() {
    awk -v block="$2" '
        /<!-- APPLIST:START -->/ { print; printf "%s", block; skip=1; next }
        /<!-- APPLIST:END -->/   { skip=0 }
        !skip { print }
    ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

splice "$UI" "$ui_items"
splice "$XML" "$xml_items"

splice_connections() {
    awk -v block="$2" '
        /<!-- APPLIST_CONNECTIONS:START -->/ { print; printf "%s", block; skip=1; next }
        /<!-- APPLIST_CONNECTIONS:END -->/   { skip=0 }
        !skip { print }
    ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

splice_connections "$UI" "$ui_connections"

LOGO="$PKG/contents/ui/klear.png"
if [ -f "$LOGO" ]; then
    sed -i "s|<pixmap>klear.png</pixmap>|<pixmap>${LOGO}</pixmap>|" "$UI"
fi

printf '%s' "$HASH" > "$STAMP"
echo "Populated $count apps into $PKG"

if command -v qdbus >/dev/null 2>&1; then
    qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript klear >/dev/null 2>&1 || true
    qdbus org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    echo "Reloaded Klear."
fi
