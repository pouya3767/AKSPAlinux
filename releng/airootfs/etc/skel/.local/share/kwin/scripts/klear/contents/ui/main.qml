import QtQuick
import Qt.labs.folderlistmodel
import "../code/logic.js" as Logic

Item {
    id: root

    property var installedApps: []

    FolderListModel {
        id: systemApps
        folder: "file:///usr/share/applications"
        nameFilters: ["*.desktop"]
        showDirs: false
        onStatusChanged: if (status === FolderListModel.Ready) root.collectApps()
    }

    function collectApps() {
        var apps = [];
        for (var i = 0; i < systemApps.count; i++) {
            var name = systemApps.get(i, "fileBaseName");
            if (name) {
                apps.push(name.toString().toLowerCase());
            }
        }
        installedApps = apps;
    }

    function setOpacity(window) {
        if (!window.normalWindow) {
            return;
        }
        var excluded = Logic.parseList(readConfig("excludedWindows", ""));
        if (Logic.isExcluded(window, excluded)) {
            return;
        }
        window.opacity = readConfig("userSetOpacity", 90) / 100;
    }

    Component.onCompleted: {
        workspace.windowAdded.connect(setOpacity);
    }
}
