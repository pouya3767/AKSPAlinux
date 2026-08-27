function parseList(raw) {
    return raw.toString()
        .split(",")
        .map(function (entry) { return entry.trim().toLowerCase(); })
        .filter(function (entry) { return entry.length > 0; });
}

function isExcluded(window, list) {
    var resourceClass = (window.resourceClass || "").toString().toLowerCase();
    var resourceName = (window.resourceName || "").toString().toLowerCase();
    return list.some(function (entry) {
        return resourceClass.indexOf(entry) !== -1 || resourceName.indexOf(entry) !== -1;
    });
}
