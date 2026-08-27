callDBus(
    "org.freedesktop.systemd1",
    "/org/freedesktop/systemd1",
    "org.freedesktop.systemd1.Manager",
    "StartUnit",
    "klear-applist.service",
    "replace"
);

const parseList = (raw) =>
    String(raw)
        .split(",")
        .map((entry) => entry.trim().toLowerCase())
        .filter((entry) => entry.length > 0);

const isExcluded = (window, list) => {
    const resourceClass = String(window.resourceClass || "").toLowerCase();
    const resourceName = String(window.resourceName || "").toLowerCase();

    const key = "exclude_" + resourceClass.replace(/[^a-z0-9]/g, "");
    if (readConfig(key, false) === true) {
        return true;
    }

    return list.some(
        (entry) =>
            resourceClass.indexOf(entry) !== -1 ||
            resourceName.indexOf(entry) !== -1
    );
};

const setOpacity = (window) => {
    const excluded = parseList(readConfig("excludedWindows", ""));
    if (isExcluded(window, excluded)) {
        return;
    }
    window.opacity = readConfig("userSetOpacity", 90) / 100;
};

workspace.windowAdded.connect((window) => {
    window.normalWindow && setOpacity(window);
});
