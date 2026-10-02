pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.modules.controlcenter
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    required property Session session

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - 32 : 620, 620)
    height: Math.min(parent ? parent.height - 32 : 520, Math.min(520, 164 + Math.max(1, results.length) * 62))
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose
    visible: session.searchOpen

    readonly property var results: findResults(session.searchQuery)

    function normalize(value: string): string {
        return value.toLowerCase().replace(/[^a-z0-9 ]/g, " ").replace(/\s+/g, " ").trim();
    }

    function fuzzyTokenMatch(query: string, haystack: string): bool {
        const words = haystack.split(" ");
        for (let i = 0; i < words.length; i++) {
            const word = words[i];
            if (word.length < 4 || Math.abs(word.length - query.length) > 1)
                continue;
            let differences = 0;
            let a = 0;
            let b = 0;
            while (a < query.length && b < word.length) {
                if (query[a] === word[b]) {
                    a++;
                    b++;
                } else {
                    differences++;
                    if (differences > 1)
                        break;
                    if (query.length > word.length)
                        a++;
                    else if (word.length > query.length)
                        b++;
                    else {
                        a++;
                        b++;
                    }
                }
            }
            if (a < query.length || b < word.length)
                differences++;
            if (differences <= 1)
                return true;
        }
        return false;
    }

    function score(query: string, text: string): int {
        const haystack = normalize(text);
        if (haystack === query)
            return 100;
        if (haystack.startsWith(query))
            return 80;
        if (haystack.indexOf(query) !== -1)
            return 65;
        const queryWords = query.split(" ");
        let matched = 0;
        for (let i = 0; i < queryWords.length; i++) {
            const word = queryWords[i];
            if (!word)
                continue;
            if (haystack.indexOf(word) !== -1)
                matched += 2;
            else if (fuzzyTokenMatch(word, haystack))
                matched += 1;
        }
        return matched === 0 ? 0 : matched * 10;
    }

    function findResults(rawQuery: string): var {
        const query = normalize(rawQuery);
        if (!query)
            return [];
        const matches = [];
        for (let i = 0; i < PaneRegistry.panes.length; i++) {
            const pane = PaneRegistry.panes[i];
            const points = score(query, pane.title + " " + pane.description + " " + pane.keywords + " " + pane.id);
            if (points > 0) {
                matches.push({
                    id: pane.id,
                    title: pane.title,
                    detail: PaneRegistry.categoryTitle(pane.category),
                    icon: pane.icon,
                    pane: pane.id,
                    section: "",
                    score: points
                });
            }
        }
        for (let i = 0; i < PaneRegistry.searchTargets.length; i++) {
            const target = PaneRegistry.searchTargets[i];
            const pane = PaneRegistry.getById(target.pane);
            const points = score(query, target.title + " " + target.keywords + " " + target.id + " " + (pane ? pane.title : ""));
            if (points > 0) {
                matches.push({
                    id: target.id,
                    title: target.title,
                    detail: pane ? pane.title : "",
                    icon: target.icon,
                    pane: target.pane,
                    section: target.section,
                    score: points + 8
                });
            }
        }
        matches.sort((a, b) => b.score - a.score || a.title.localeCompare(b.title));
        return matches.slice(0, 8);
    }

    function selectResult(index: int): void {
        if (index < 0 || index >= root.results.length)
            return;
        const result = root.results[index];
        root.session.navigateTo(result.pane, result.section);
    }

    onOpened: Qt.callLater(() => searchField.forceActiveFocus())
    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => searchField.forceActiveFocus());
    }

    background: StyledRect {
        color: Colours.tPalette.m3surfaceContainerHigh
        radius: Appearance.rounding.large
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.55)
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.42)
    }

    contentItem: ColumnLayout {
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.leftMargin: Appearance.padding.larger
            Layout.rightMargin: Appearance.padding.larger
            Layout.topMargin: Appearance.padding.larger
            spacing: Appearance.spacing.normal

            MaterialIcon {
                text: "search"
                color: Colours.palette.m3primary
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Find a setting")
                font.pointSize: Appearance.font.size.large
                font.weight: 600
            }

            StyledText {
                text: "ESC"
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.smaller
            }
        }

        SearchBar {
            id: searchField
            Layout.fillWidth: true
            Layout.leftMargin: Appearance.padding.larger
            Layout.rightMargin: Appearance.padding.larger
            placeholderText: qsTr("Try “wallpaper”, “VPN”, or “reduce motion”")
            text: root.session.searchQuery
            onTextEdited: {
                root.session.searchQuery = text;
                root.session.searchSelection = 0;
            }

            Connections {
                target: root.session
                function onSearchQueryChanged(): void {
                    if (searchField.text !== root.session.searchQuery)
                        searchField.text = root.session.searchQuery;
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                    root.session.searchSelection = Math.min(root.session.searchSelection + 1, root.results.length - 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    root.session.searchSelection = Math.max(root.session.searchSelection - 1, 0);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.selectResult(root.session.searchSelection);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    if (root.session.searchQuery.length > 0) {
                        root.session.searchQuery = "";
                        event.accepted = true;
                    } else {
                        root.session.searchOpen = false;
                        event.accepted = true;
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Appearance.padding.normal
            Layout.rightMargin: Appearance.padding.normal
            Layout.bottomMargin: Appearance.padding.normal
            implicitHeight: Math.max(52, Math.min(300, root.results.length * 62))

            ListView {
                id: resultsList
                anchors.fill: parent
                clip: true
                model: root.results
                spacing: Appearance.spacing.smaller
                currentIndex: root.session.searchSelection

                delegate: Item {
                    id: row
                    required property int index
                    required property var modelData
                    width: resultsList.width
                    height: resultSurface.implicitHeight
                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.title + ", " + modelData.detail

                    StyledRect {
                        id: resultSurface
                        anchors.fill: parent
                        implicitHeight: Appearance.padding.larger * 2 + resultIcon.implicitHeight
                        radius: Appearance.rounding.normal
                        color: row.index === root.session.searchSelection ? Colours.palette.m3secondaryContainer : "transparent"

                        StateLayer {
                            onClicked: root.selectResult(row.index)
                        }

                        MaterialIcon {
                            id: resultIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Appearance.padding.normal
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.icon
                            color: row.index === root.session.searchSelection ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3primary
                        }

                        ColumnLayout {
                            anchors.left: resultIcon.right
                            anchors.leftMargin: Appearance.spacing.normal
                            anchors.right: parent.right
                            anchors.rightMargin: Appearance.padding.normal
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.title
                                color: row.index === root.session.searchSelection ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                font.weight: 500
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.detail
                                color: row.index === root.session.searchSelection ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                font.pointSize: Appearance.font.size.smaller
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: root.session.searchQuery.trim().length > 0 ? qsTr("No settings found. Try a shorter search.") : qsTr("Type to find a page or setting")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Appearance.padding.normal
            text: qsTr("↑ ↓ move     Enter open     Esc close")
            color: Colours.palette.m3outline
            font.pointSize: Appearance.font.size.smaller
        }
    }
}
