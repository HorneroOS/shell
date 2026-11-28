import "../../services/store.js" as Store
import "../controlcenter/components"
import qs.components
import qs.components.atmosphere
import qs.components.controls
import qs.components.containers
import qs.modules.controlcenter
import qs.modules.welcome
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Standalone Hornero Apps Software Center window.
// Follows Signal Day/Night visual language, WCAG 2.2 AA accessibility,
// keyboard navigation (/ or Ctrl+F search, Escape closes detail/window),
// and single-writer `horneroctl --json store ...` via AppsStore.
FloatingWindow {
    id: win

    title: qsTr("Hornero Apps")
    color: Signal.palette.base

    implicitWidth: 1120
    implicitHeight: 720
    minimumSize.width: 960
    minimumSize.height: 640
    visible: true

    onVisibleChanged: {
        if (!visible && AppsStore.opened)
            AppsStore.close();
    }

    Behavior on color {
        CAnim {}
    }

    property bool _navReady: false
    property string selectedCategory: "all"
    property string selectedCollection: "all"
    property bool filterVerifiedOnly: false
    property bool filterOpenSourceOnly: false

    // AppImage & WebApp tool fields
    property string appImagePath: ""
    property string appImageName: ""
    property string webAppName: ""
    property string webAppUrl: ""
    property string webAppProfile: ""
    property string manifestPath: ""

    readonly property var navViews: [
        { id: "discover", icon: "compass", label: qsTr("Discover") },
        { id: "ai", icon: "sparkles", label: qsTr("AI & Agents") },
        { id: "categories", icon: "category", label: qsTr("Categories") },
        { id: "collections", icon: "folders", label: qsTr("Collections") },
        { id: "installed", icon: "circle-check", label: qsTr("Installed") },
        { id: "updates", icon: "download", label: qsTr("Updates") },
        { id: "queue", icon: "playlist", label: qsTr("Queue") },
        { id: "sources", icon: "shield-lock", label: qsTr("Sources & Policy") }
    ]

    readonly property var curatedCollectionMeta: [
        { id: "everyday-essentials", name: qsTr("Everyday Essentials"), icon: "compass", desc: qsTr("Browsers, messaging, media, and daily productivity.") },
        { id: "ai-workstation", name: qsTr("AI Workstation"), icon: "sparkles", desc: qsTr("Local LLMs, AI coding editors, and agentic workflows.") },
        { id: "start-coding", name: qsTr("Start Coding"), icon: "code", desc: qsTr("Editors, terminals, containers, and SDKs.") },
        { id: "create-something", name: qsTr("Create Something"), icon: "palette", desc: qsTr("Illustration, photo editing, vector design, and video.") },
        { id: "make-music", name: qsTr("Make Music"), icon: "music", desc: qsTr("DAWs, synthesizers, and low-latency PipeWire studio tools.") },
        { id: "ready-to-game", name: qsTr("Ready to Game"), icon: "device-gamepad-2", desc: qsTr("Launchers, compatibility layers, and overlays.") },
        { id: "protect-your-privacy", name: qsTr("Protect Your Privacy"), icon: "shield-lock", desc: qsTr("Password managers, encrypted messaging, and VPN tools.") }
    ]

    readonly property var aiShowcaseIds: ["ollama", "lm-studio", "jan", "antigravity", "cursor", "zed", "claude-code", "opencode", "veasel", "agent-toolkit"]

    function viewIndex(id: string): int {
        for (let i = 0; i < win.navViews.length; i++) {
            if (win.navViews[i].id === id)
                return i;
        }
        return 0;
    }

    function filteredCatalogApps(): var {
        const base = AppsStore.searchActive ? AppsStore.searchResults : AppsStore.catalogApps;
        return Store.filterApps(
            base,
            "",
            win.currentViewIs("categories") ? win.selectedCategory : "",
            win.currentViewIs("collections") ? win.selectedCollection : "",
            win.filterVerifiedOnly || AppsStore.policy.verifiedOnly === true,
            win.filterOpenSourceOnly || AppsStore.policy.openSourceOnly === true
        );
    }

    function currentViewIs(id: string): bool {
        return AppsStore.currentView === id;
    }

    function featuredApps(): var {
        const featured = AppsStore.catalogApps.filter(a => a.featured === true);
        return featured.length > 0 ? featured.slice(0, 12) : AppsStore.catalogApps.slice(0, 12);
    }

    function aiApps(): var {
        return AppsStore.catalogApps.filter(a => {
            if (win.aiShowcaseIds.includes(a.id))
                return true;
            if ((a.aiCategory || "") !== "")
                return true;
            const cats = (a.categories || []).map(c => String(c).toLowerCase());
            const cols = (a.collections || []).map(c => String(c).toLowerCase());
            const tags = (a.tags || []).map(c => String(c).toLowerCase());
            return cats.includes("ai") || cols.includes("ai-workstation") || tags.includes("ai") || tags.includes("llm") || tags.includes("agent");
        });
    }

    function availableCategories(): var {
        if (AppsStore.categories.length > 0)
            return AppsStore.categories;
        const map = {};
        for (let i = 0; i < AppsStore.catalogApps.length; i++) {
            const cats = AppsStore.catalogApps[i].categories || [];
            for (let j = 0; j < cats.length; j++) {
                const c = cats[j];
                if (!map[c])
                    map[c] = { id: c, name: c, count: 0 };
                map[c].count++;
            }
        }
        return Object.keys(map).sort().map(k => map[k]);
    }

    Shortcut {
        sequences: ["Escape"]
        context: Qt.WindowShortcut
        onActivated: {
            if (AppsStore.selectedApp !== null) {
                AppsStore.clearSelectedApp();
            } else if (searchField.text !== "") {
                searchField.clear();
                AppsStore.searchCatalog("");
            } else {
                AppsStore.close();
            }
        }
    }

    Shortcut {
        sequences: ["Ctrl+F", "/"]
        context: Qt.WindowShortcut
        onActivated: searchField.forceActiveFocus()
    }

    Component.onCompleted: {
        navList.currentIndex = win.viewIndex(AppsStore.currentView);
        win._navReady = true;
        AppsStore.refreshAll();
        navList.forceActiveFocus();
    }

    Connections {
        target: AppsStore

        function onCurrentViewChanged(): void {
            navList.currentIndex = win.viewIndex(AppsStore.currentView);
        }
    }

    AtmosphereTexture {}

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Top Header ───────────────────────────────────────────────────────
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: Signal.palette.panel

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Signal.palette.rule
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: Appearance.rounding.small
                    color: Signal.palette.signalWell
                    border.width: 1
                    border.color: Signal.palette.signal

                    Glyph {
                        anchors.centerIn: parent
                        name: "apps"
                        color: Signal.palette.onSignalWell
                        font.pointSize: Appearance.font.size.large
                    }
                }

                StyledText {
                    text: qsTr("Hornero Apps")
                    font.pointSize: Appearance.font.size.large
                    font.weight: Appearance.font.weight.strong
                }

                Item {
                    Layout.preferredWidth: Appearance.spacing.normal
                }

                SearchBar {
                    id: searchField

                    Layout.fillWidth: true
                    Layout.maximumWidth: 460
                    placeholderText: qsTr("Search apps, categories, tags… (/)")
                    Accessible.name: qsTr("Search applications")
                    onTextChanged: searchDebounce.restart()
                    onAccepted: AppsStore.searchCatalog(searchField.text)
                }

                Timer {
                    id: searchDebounce

                    interval: 160
                    onTriggered: AppsStore.searchCatalog(searchField.text)
                }

                Item {
                    Layout.fillWidth: true
                }

                IconTextButton {
                    visible: AppsStore.queueItems.length > 0
                    icon: "playlist"
                    text: qsTr("Queue (%1)").arg(AppsStore.queueItems.length)
                    type: IconTextButton.Tonal
                    onClicked: {
                        AppsStore.clearSelectedApp();
                        AppsStore.currentView = "queue";
                    }
                }

                IconButton {
                    type: IconButton.Text
                    icon: "refresh"
                    accessibleName: qsTr("Refresh catalog")
                    onClicked: AppsStore.refreshAll()
                }

                IconButton {
                    type: IconButton.Text
                    icon: "x"
                    accessibleName: qsTr("Close Hornero Apps")
                    onClicked: AppsStore.close()
                }
            }
        }

        // ── Body: Left Nav Rail + Main Workspace ─────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ListView {
                id: navList

                Layout.fillHeight: true
                Layout.preferredWidth: 232
                Layout.topMargin: Appearance.padding.normal
                Layout.bottomMargin: Appearance.padding.normal
                Layout.leftMargin: Appearance.padding.normal

                keyNavigationWraps: true
                activeFocusOnTab: true
                spacing: Appearance.spacing.smaller
                highlightMoveDuration: Appearance.anim.durations.medium
                clip: true

                Accessible.role: Accessible.List
                Accessible.name: qsTr("Hornero Apps sections")

                model: win.navViews

                onCurrentIndexChanged: {
                    if (!win._navReady)
                        return;
                    const entry = win.navViews[currentIndex];
                    if (entry && entry.id !== AppsStore.currentView) {
                        AppsStore.currentView = entry.id;
                        AppsStore.clearSelectedApp();
                    }
                }

                highlight: StyledRect {
                    radius: Appearance.rounding.small
                    color: Signal.palette.raised
                    border.width: navList.activeFocus ? 2 : 0
                    border.color: Signal.palette.focus

                    OnAirBar {
                        edge: "right"
                    }
                }

                delegate: StyledRect {
                    id: navDelegate

                    required property var modelData
                    required property int index

                    readonly property bool isCurrent: ListView.isCurrentItem

                    width: ListView.view.width
                    implicitHeight: 42
                    radius: Appearance.rounding.small
                    color: isCurrent ? "transparent" : (navMouse.containsMouse ? Qt.alpha(Signal.palette.raised, 0.6) : "transparent")

                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label
                    Accessible.onPressAction: navList.currentIndex = navDelegate.index

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.rightMargin: Appearance.padding.normal
                        spacing: Appearance.spacing.normal

                        Glyph {
                            name: navDelegate.modelData.icon
                            color: navDelegate.isCurrent ? Signal.palette.ink : Signal.palette.inkMuted
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: navDelegate.modelData.label
                            font.weight: navDelegate.isCurrent ? 600 : 400
                            color: navDelegate.isCurrent ? Signal.palette.ink : Signal.palette.inkMuted
                            elide: Text.ElideRight
                        }

                        ProvenancePill {
                            visible: navDelegate.modelData.id === "updates" && AppsStore.updates.length > 0
                            text: String(AppsStore.updates.length)
                            tone: "signal"
                        }

                        ProvenancePill {
                            visible: navDelegate.modelData.id === "queue" && AppsStore.queueItems.length > 0
                            text: String(AppsStore.queueItems.length)
                            tone: "cue"
                        }
                    }

                    MouseArea {
                        id: navMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        Accessible.role: Accessible.Button
                        Accessible.name: navDelegate.modelData.label
                        onClicked: {
                            navList.currentIndex = navDelegate.index;
                            AppsStore.clearSelectedApp();
                        }
                    }
                }
            }

            // Main Workspace
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Appearance.padding.large

                // Detail drawer/sheet when an app is selected (lazy-loaded)
                Loader {
                    anchors.fill: parent
                    active: AppsStore.selectedApp !== null || AppsStore.detailLoading || AppsStore.detailError !== ""
                    visible: active
                    z: 10

                    sourceComponent: Component {
                        AppDetailView {
                            app: AppsStore.selectedApp
                            loading: AppsStore.detailLoading
                            error: AppsStore.detailError
                        }
                    }
                }

                // Search results overlay when searching (lazy + virtualized GridView)
                Loader {
                    anchors.fill: parent
                    active: AppsStore.selectedApp === null && !AppsStore.detailLoading && AppsStore.detailError === "" && AppsStore.searchActive
                    visible: active

                    sourceComponent: Component {
                        ColumnLayout {
                            id: searchCol

                            spacing: Appearance.spacing.large

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.normal

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("Search results for “%1”").arg(AppsStore.searchQuery)
                                    font.family: Appearance.font.family.display
                                    font.pointSize: Appearance.font.size.large
                                    font.weight: Appearance.font.weight.strong
                                }

                                TextButton {
                                    text: qsTr("Clear search")
                                    type: TextButton.Tonal
                                    onClicked: {
                                        searchField.clear();
                                        AppsStore.searchCatalog("");
                                    }
                                }
                            }

                            StyledText {
                                visible: !AppsStore.searchLoading && win.filteredCatalogApps().length === 0
                                Layout.fillWidth: true
                                text: qsTr("No applications matched your query and active policy filters.")
                                color: Signal.palette.inkMuted
                            }

                            GridView {
                                id: searchGrid

                                readonly property int cols: width >= 760 ? 2 : 1
                                readonly property int colGap: Appearance.spacing.normal

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: win.filteredCatalogApps().length > 0
                                clip: true
                                cellWidth: cols === 2 ? Math.floor((width + colGap) / 2) : width
                                cellHeight: 176
                                cacheBuffer: 360
                                model: win.filteredCatalogApps()

                                StyledScrollBar.vertical: StyledScrollBar {
                                    flickable: searchGrid
                                }

                                delegate: Item {
                                    id: searchCell

                                    required property var modelData

                                    width: searchGrid.cellWidth
                                    height: searchGrid.cellHeight

                                    AppCard {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        width: searchGrid.cols === 2 ? searchGrid.cellWidth - searchGrid.colGap : searchGrid.cellWidth
                                        height: searchGrid.cellHeight - searchGrid.colGap
                                        app: searchCell.modelData
                                        policy: AppsStore.policy
                                        onSelected: appId => AppsStore.selectApp(appId)
                                    }
                                }
                            }
                        }
                    }
                }

                // Lazy-loaded view container for the 8 nav views (only the active tab is instantiated)
                Item {
                    anchors.fill: parent
                    visible: AppsStore.selectedApp === null && !AppsStore.detailLoading && AppsStore.detailError === "" && !AppsStore.searchActive

                    // ── 0: Discover ──────────────────────────────────────────
                    Loader {
                        anchors.fill: parent
                        active: AppsStore.currentView === "discover"
                        visible: active

                        sourceComponent: Component {
                            StyledFlickable {
                                id: discoverFlick

                                flickableDirection: Flickable.VerticalFlick
                                contentHeight: discoverCol.implicitHeight
                                clip: true

                                StyledScrollBar.vertical: StyledScrollBar {
                                    flickable: discoverFlick
                                }

                                ColumnLayout {
                                    id: discoverCol

                                    width: discoverFlick.width
                                    spacing: Appearance.spacing.large

                                    // Offline / Unavailable / Error banner
                                    StyledRect {
                                        visible: !AppsStore.catalogAvailable || AppsStore.catalogError !== ""
                                        Layout.fillWidth: true
                                        implicitHeight: catErrRow.implicitHeight + Appearance.padding.normal * 2
                                        radius: Appearance.rounding.small
                                        color: Signal.palette.alertWell
                                        border.width: 1
                                        border.color: Signal.palette.alert

                                        RowLayout {
                                            id: catErrRow

                                            anchors.fill: parent
                                            anchors.margins: Appearance.padding.normal
                                            spacing: Appearance.spacing.normal

                                            Glyph {
                                                name: "alert-triangle"
                                                color: Signal.palette.onAlertWell
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: AppsStore.catalogError || qsTr("Hornero Apps catalog is currently unavailable.")
                                                color: Signal.palette.onAlertWell
                                                wrapMode: Text.WordWrap
                                            }

                                            TextButton {
                                                text: qsTr("Retry")
                                                type: TextButton.Tonal
                                                onClicked: AppsStore.refreshAll()
                                            }
                                        }
                                    }

                                    // Hero Banner
                                    StyledRect {
                                        Layout.fillWidth: true
                                        implicitHeight: heroContent.implicitHeight + Appearance.padding.large * 2
                                        radius: Appearance.rounding.small
                                        color: Signal.palette.panel
                                        border.width: 1
                                        border.color: Signal.palette.rule

                                        ColumnLayout {
                                            id: heroContent

                                            anchors.fill: parent
                                            anchors.margins: Appearance.padding.large
                                            spacing: Appearance.spacing.small

                                            Eyebrow {
                                                label: qsTr("Hornero Apps Software Center")
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: qsTr("Find the apps you know. Discover the apps you'll love.")
                                                font.family: Appearance.font.family.display
                                                font.pointSize: Appearance.font.size.extraLarge
                                                font.weight: Appearance.font.weight.strong
                                                wrapMode: Text.WordWrap
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: qsTr("Verified native Arch packages, Flathub apps, official vendor channels, isolated Web Apps, and guided setup — with transparent provenance on every card.")
                                                color: Signal.palette.inkMuted
                                                wrapMode: Text.WordWrap
                                            }

                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: Appearance.spacing.small

                                                IconTextButton {
                                                    icon: "sparkles"
                                                    text: qsTr("Explore AI & Agents")
                                                    onClicked: AppsStore.currentView = "ai"
                                                }

                                                IconTextButton {
                                                    icon: "folders"
                                                    text: qsTr("Browse Collections")
                                                    type: IconTextButton.Tonal
                                                    onClicked: AppsStore.currentView = "collections"
                                                }
                                            }
                                        }
                                    }

                                    // Workstation Profiles Quick-Setup Banner
                                    StyledRect {
                                        Layout.fillWidth: true
                                        implicitHeight: profBanner.implicitHeight + Appearance.padding.normal * 2
                                        radius: Appearance.rounding.small
                                        color: Signal.palette.cueWell
                                        border.width: 1
                                        border.color: Signal.palette.cue

                                        RowLayout {
                                            id: profBanner

                                            anchors.fill: parent
                                            anchors.margins: Appearance.padding.normal
                                            spacing: Appearance.spacing.normal

                                            Glyph {
                                                name: "apps"
                                                color: Signal.palette.onCueWell
                                                font.pointSize: Appearance.font.size.large
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: qsTr("Workstation Profiles Quick Setup")
                                                    font.weight: Appearance.font.weight.strong
                                                    color: Signal.palette.onCueWell
                                                }

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: AppsStore.profiles.length > 0
                                                        ? qsTr("Queue curated stacks across %1 optional workstation profiles in Hornero Welcome.").arg(AppsStore.profiles.length)
                                                        : qsTr("Preview and queue optional workstation app bundles in Hornero Welcome.")
                                                    color: Signal.palette.onCueWell
                                                    font.pointSize: Appearance.font.size.smaller
                                                    wrapMode: Text.WordWrap
                                                }
                                            }

                                            TextButton {
                                                text: qsTr("Set up apps")
                                                type: TextButton.Filled
                                                onClicked: Welcome.open("apps")
                                            }
                                        }
                                    }

                                    // Curated Collections Rail
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Appearance.spacing.small

                                        Eyebrow {
                                            label: qsTr("Curated collections")
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: Appearance.spacing.small

                                            Repeater {
                                                model: AppsStore.collections.length > 0 ? AppsStore.collections : win.curatedCollectionMeta

                                                delegate: IconTextButton {
                                                    required property var modelData
                                                    icon: modelData.icon || "folders"
                                                    text: modelData.name
                                                    type: IconTextButton.Tonal
                                                    onClicked: {
                                                        win.selectedCollection = modelData.id;
                                                        AppsStore.currentView = "collections";
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Featured Applications Grid
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Appearance.spacing.small

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Eyebrow {
                                                Layout.fillWidth: true
                                                label: qsTr("Featured applications")
                                            }

                                            CircularIndicator {
                                                visible: AppsStore.catalogLoading
                                                running: AppsStore.catalogLoading
                                            }
                                        }

                                        StyledText {
                                            visible: !AppsStore.catalogLoading && win.featuredApps().length === 0
                                            Layout.fillWidth: true
                                            text: qsTr("No featured applications loaded yet. Check Sources & Policy or click Refresh.")
                                            color: Signal.palette.inkMuted
                                        }

                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: discoverFlick.width >= 760 ? 2 : 1
                                            columnSpacing: Appearance.spacing.normal
                                            rowSpacing: Appearance.spacing.normal

                                            Repeater {
                                                model: win.featuredApps()

                                                delegate: AppCard {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    app: modelData
                                                    policy: AppsStore.policy
                                                    onSelected: appId => AppsStore.selectApp(appId)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 1: AI & Agents ───────────────────────────────────────
                    Loader {
                        anchors.fill: parent
                        active: AppsStore.currentView === "ai"
                        visible: active

                        sourceComponent: Component {
                            StyledFlickable {
                                id: aiFlick

                                flickableDirection: Flickable.VerticalFlick
                                contentHeight: aiCol.implicitHeight
                                clip: true

                                StyledScrollBar.vertical: StyledScrollBar {
                                    flickable: aiFlick
                                }

                                ColumnLayout {
                                    id: aiCol

                                    width: aiFlick.width
                                    spacing: Appearance.spacing.large

                                    StyledRect {
                                        Layout.fillWidth: true
                                        implicitHeight: aiHero.implicitHeight + Appearance.padding.large * 2
                                        radius: Appearance.rounding.small
                                        color: Signal.palette.panel
                                        border.width: 1
                                        border.color: Signal.palette.rule

                                        ColumnLayout {
                                            id: aiHero

                                            anchors.fill: parent
                                            anchors.margins: Appearance.padding.large
                                            spacing: Appearance.spacing.small

                                            Eyebrow {
                                                label: qsTr("AI Workstation & Agentic Tools")
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: qsTr("Local models, AI coding editors, and agentic CLIs")
                                                font.family: Appearance.font.family.display
                                                font.pointSize: Appearance.font.size.extraLarge
                                                font.weight: Appearance.font.weight.strong
                                                wrapMode: Text.WordWrap
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: qsTr("Install verified runtimes like Ollama, LM Studio, Jan, Antigravity, Cursor, Zed, Claude Code, OpenCode, Veasel, and Agent Toolkit. Configure active agents and Javi in Control Center.")
                                                color: Signal.palette.inkMuted
                                                wrapMode: Text.WordWrap
                                            }

                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: Appearance.spacing.small

                                                IconTextButton {
                                                    icon: "robot"
                                                    text: qsTr("Open Hornero Agents")
                                                    type: IconTextButton.Tonal
                                                    onClicked: WindowFactory.create(null, { pane: "agents" })
                                                }

                                                IconTextButton {
                                                    icon: "feather"
                                                    text: qsTr("Open Javi Companion")
                                                    type: IconTextButton.Tonal
                                                    onClicked: WindowFactory.create(null, { pane: "companion" })
                                                }
                                            }
                                        }
                                    }

                                    StyledText {
                                        visible: !AppsStore.catalogLoading && win.aiApps().length === 0
                                        Layout.fillWidth: true
                                        text: qsTr("No AI & Agent entries available in the current catalog snapshot.")
                                        color: Signal.palette.inkMuted
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: aiFlick.width >= 760 ? 2 : 1
                                        columnSpacing: Appearance.spacing.normal
                                        rowSpacing: Appearance.spacing.normal

                                        Repeater {
                                            model: win.aiApps()

                                            delegate: AppCard {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                app: modelData
                                                policy: AppsStore.policy
                                                onSelected: appId => AppsStore.selectApp(appId)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 2: Categories (virtualized GridView) ─────────────────
                    Loader {
                        anchors.fill: parent
                        active: AppsStore.currentView === "categories"
                        visible: active

                        sourceComponent: Component {
                            ColumnLayout {
                                id: catCol

                                spacing: Appearance.spacing.large

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    Eyebrow {
                                        Layout.fillWidth: true
                                        label: qsTr("Browse by category")
                                    }

                                    ToggleButton {
                                        toggled: win.filterVerifiedOnly
                                        icon: "rosette-discount-check"
                                        label: qsTr("Verified only")
                                        onClicked: win.filterVerifiedOnly = !win.filterVerifiedOnly
                                    }

                                    ToggleButton {
                                        toggled: win.filterOpenSourceOnly
                                        icon: "code"
                                        label: qsTr("Open source only")
                                        onClicked: win.filterOpenSourceOnly = !win.filterOpenSourceOnly
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    ToggleButton {
                                        toggled: win.selectedCategory === "all"
                                        label: qsTr("All")
                                        onClicked: win.selectedCategory = "all"
                                    }

                                    Repeater {
                                        model: win.availableCategories()

                                        delegate: ToggleButton {
                                            required property var modelData
                                            toggled: win.selectedCategory === modelData.id
                                            label: modelData.count > 0 ? `${modelData.name} (${modelData.count})` : modelData.name
                                            onClicked: win.selectedCategory = modelData.id
                                        }
                                    }
                                }

                                StyledText {
                                    visible: !AppsStore.catalogLoading && win.filteredCatalogApps().length === 0
                                    Layout.fillWidth: true
                                    text: qsTr("No applications in this category match your active filters.")
                                    color: Signal.palette.inkMuted
                                }

                                GridView {
                                    id: catGrid

                                    readonly property int cols: width >= 760 ? 2 : 1
                                    readonly property int colGap: Appearance.spacing.normal

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: win.filteredCatalogApps().length > 0
                                    clip: true
                                    cellWidth: cols === 2 ? Math.floor((width + colGap) / 2) : width
                                    cellHeight: 176
                                    cacheBuffer: 360
                                    model: win.filteredCatalogApps()

                                    StyledScrollBar.vertical: StyledScrollBar {
                                        flickable: catGrid
                                    }

                                    delegate: Item {
                                        id: catCell

                                        required property var modelData

                                        width: catGrid.cellWidth
                                        height: catGrid.cellHeight

                                        AppCard {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            width: catGrid.cols === 2 ? catGrid.cellWidth - catGrid.colGap : catGrid.cellWidth
                                            height: catGrid.cellHeight - catGrid.colGap
                                            app: catCell.modelData
                                            policy: AppsStore.policy
                                            onSelected: appId => AppsStore.selectApp(appId)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 3: Collections (virtualized GridView) ────────────────
                    Loader {
                        anchors.fill: parent
                        active: AppsStore.currentView === "collections"
                        visible: active

                        sourceComponent: Component {
                            ColumnLayout {
                                id: colLayout

                                spacing: Appearance.spacing.large

                                Eyebrow {
                                    label: qsTr("Curated collections")
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    ToggleButton {
                                        toggled: win.selectedCollection === "all"
                                        label: qsTr("All collections")
                                        onClicked: win.selectedCollection = "all"
                                    }

                                    Repeater {
                                        model: AppsStore.collections.length > 0 ? AppsStore.collections : win.curatedCollectionMeta

                                        delegate: ToggleButton {
                                            required property var modelData
                                            toggled: win.selectedCollection === modelData.id
                                            icon: modelData.icon || "folders"
                                            label: modelData.name
                                            onClicked: win.selectedCollection = modelData.id
                                        }
                                    }
                                }

                                StyledText {
                                    visible: !AppsStore.catalogLoading && win.filteredCatalogApps().length === 0
                                    Layout.fillWidth: true
                                    text: qsTr("No applications found for this collection.")
                                    color: Signal.palette.inkMuted
                                }

                                GridView {
                                    id: colGrid

                                    readonly property int cols: width >= 760 ? 2 : 1
                                    readonly property int colGap: Appearance.spacing.normal

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: win.filteredCatalogApps().length > 0
                                    clip: true
                                    cellWidth: cols === 2 ? Math.floor((width + colGap) / 2) : width
                                    cellHeight: 176
                                    cacheBuffer: 360
                                    model: win.filteredCatalogApps()

                                    StyledScrollBar.vertical: StyledScrollBar {
                                        flickable: colGrid
                                    }

                                    delegate: Item {
                                        id: colCell

                                        required property var modelData

                                        width: colGrid.cellWidth
                                        height: colGrid.cellHeight

                                        AppCard {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            width: colGrid.cols === 2 ? colGrid.cellWidth - colGrid.colGap : colGrid.cellWidth
                                            height: colGrid.cellHeight - colGrid.colGap
                                            app: colCell.modelData
                                            policy: AppsStore.policy
                                            onSelected: appId => AppsStore.selectApp(appId)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 4: Installed ─────────────────────────────────────────
                    Loader {
                        anchors.fill: parent
                        active: AppsStore.currentView === "installed"
                        visible: active

                        sourceComponent: Component {
                            StyledFlickable {
                                id: instFlick

                                flickableDirection: Flickable.VerticalFlick
                                contentHeight: instCol.implicitHeight
                                clip: true

                                StyledScrollBar.vertical: StyledScrollBar {
                                    flickable: instFlick
                                }

                                ColumnLayout {
                                    id: instCol

                                    width: instFlick.width
                                    spacing: Appearance.spacing.large

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Eyebrow {
                                            Layout.fillWidth: true
                                            label: qsTr("Installed applications (%1)").arg(AppsStore.installedApps.length)
                                        }

                                        TextButton {
                                            text: qsTr("Refresh")
                                            type: TextButton.Tonal
                                            disabled: AppsStore.installedLoading
                                            onClicked: AppsStore.refreshInstalled()
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Includes catalog apps and externally detected system/Flatpak applications. User data is preserved if you remove an app.")
                                        color: Signal.palette.inkMuted
                                        font.pointSize: Appearance.font.size.smaller
                                        wrapMode: Text.WordWrap
                                    }

                                    StyledText {
                                        visible: AppsStore.installedError !== ""
                                        Layout.fillWidth: true
                                        text: AppsStore.installedError
                                        color: Signal.palette.alert
                                        wrapMode: Text.WordWrap
                                    }

                                    StyledText {
                                        visible: !AppsStore.installedLoading && AppsStore.installedError === "" && AppsStore.installedApps.length === 0
                                        Layout.fillWidth: true
                                        text: qsTr("No managed applications detected yet.")
                                        color: Signal.palette.inkMuted
                                    }

                                    SectionContainer {
                                        visible: AppsStore.installedApps.length > 0

                                        Repeater {
                                            model: AppsStore.installedApps

                                            delegate: SettingRow {
                                                id: instRow
                                                required property var modelData
                                                property bool removeArmed: false

                                                label: modelData.name
                                                description: `${Store.backendLabel(modelData.backend)} · ${modelData.installedVersion || Store.provenanceLabel(modelData.provenance)}`

                                                RowLayout {
                                                    spacing: Appearance.spacing.small

                                                    TextButton {
                                                        text: qsTr("Details")
                                                        type: TextButton.Text
                                                        onClicked: AppsStore.selectApp(instRow.modelData.id)
                                                    }

                                                    TextButton {
                                                        text: qsTr("Open")
                                                        type: TextButton.Tonal
                                                        onClicked: AppsStore.launchApp(instRow.modelData)
                                                    }

                                                    TextButton {
                                                        text: instRow.removeArmed ? qsTr("Confirm remove") : qsTr("Remove")
                                                        type: instRow.removeArmed ? TextButton.Filled : TextButton.Tonal
                                                        disabled: AppsStore.busy
                                                        onClicked: {
                                                            if (!instRow.removeArmed) {
                                                                instRow.removeArmed = true;
                                                                return;
                                                            }
                                                            instRow.removeArmed = false;
                                                            AppsStore.removeApp(instRow.modelData.id);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 5: Updates ───────────────────────────────────────────
                    Loader {
                        anchors.fill: parent
                        active: AppsStore.currentView === "updates"
                        visible: active

                        sourceComponent: Component {
                            StyledFlickable {
                                id: updFlick

                                flickableDirection: Flickable.VerticalFlick
                                contentHeight: updCol.implicitHeight
                                clip: true

                                StyledScrollBar.vertical: StyledScrollBar {
                                    flickable: updFlick
                                }

                                ColumnLayout {
                                    id: updCol

                                    width: updFlick.width
                                    spacing: Appearance.spacing.large

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Appearance.spacing.small

                                        Eyebrow {
                                            Layout.fillWidth: true
                                            label: qsTr("Available updates (%1)").arg(AppsStore.updates.length)
                                        }

                                        TextButton {
                                            text: qsTr("Check updates")
                                            type: TextButton.Tonal
                                            disabled: AppsStore.updatesLoading || AppsStore.busy
                                            onClicked: AppsStore.refreshUpdates()
                                        }

                                        TextButton {
                                            visible: AppsStore.updates.length > 0
                                            text: AppsStore.busy ? AppsStore.activeJobLabel : qsTr("Update All")
                                            disabled: AppsStore.busy
                                            onClicked: AppsStore.updateAll()
                                        }
                                    }

                                    StyledText {
                                        visible: AppsStore.updatesError !== ""
                                        Layout.fillWidth: true
                                        text: AppsStore.updatesError
                                        color: Signal.palette.alert
                                        wrapMode: Text.WordWrap
                                    }

                                    StyledText {
                                        visible: !AppsStore.updatesLoading && AppsStore.updatesError === "" && AppsStore.updates.length === 0
                                        Layout.fillWidth: true
                                        text: qsTr("All tracked applications are up to date.")
                                        color: Signal.palette.inkMuted
                                    }

                                    SectionContainer {
                                        visible: AppsStore.updates.length > 0

                                        Repeater {
                                            model: AppsStore.updates

                                            delegate: SettingRow {
                                                required property var modelData

                                                label: modelData.name
                                                description: `${Store.backendLabel(modelData.backend)}${modelData.currentVersion || modelData.nextVersion ? ` · ${modelData.currentVersion} → ${modelData.nextVersion}` : ""}`

                                                TextButton {
                                                    text: qsTr("Update")
                                                    type: TextButton.Tonal
                                                    disabled: AppsStore.busy
                                                    onClicked: AppsStore.updateApp(modelData.id)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 6: Queue & AppImage / WebApp Tools ───────────────────
                    Loader {
                        anchors.fill: parent
                        active: AppsStore.currentView === "queue"
                        visible: active

                        sourceComponent: Component {
                            StyledFlickable {
                                id: queueFlick

                                flickableDirection: Flickable.VerticalFlick
                                contentHeight: queueCol.implicitHeight
                                clip: true

                                StyledScrollBar.vertical: StyledScrollBar {
                                    flickable: queueFlick
                                }

                                ColumnLayout {
                                    id: queueCol

                                    width: queueFlick.width
                                    spacing: Appearance.spacing.large

                                    // Queue card
                                    SectionContainer {
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Appearance.spacing.small

                                            Eyebrow {
                                                Layout.fillWidth: true
                                                label: qsTr("Installation queue (%1)").arg(AppsStore.queueItems.length)
                                            }

                                            TextButton {
                                                visible: AppsStore.queueItems.length > 0
                                                text: qsTr("Clear")
                                                type: TextButton.Text
                                                disabled: AppsStore.busy
                                                onClicked: AppsStore.queueClear()
                                            }

                                            TextButton {
                                                visible: AppsStore.queueItems.length > 0
                                                text: AppsStore.busy ? AppsStore.activeJobLabel : qsTr("Run Queue")
                                                disabled: AppsStore.busy
                                                onClicked: AppsStore.queueRun()
                                            }
                                        }

                                        StyledText {
                                            visible: AppsStore.queueItems.length === 0
                                            Layout.fillWidth: true
                                            text: qsTr("No applications queued. Queue apps from Hornero Welcome profiles or any app detail view.")
                                            color: Signal.palette.inkMuted
                                            wrapMode: Text.WordWrap
                                        }

                                        Repeater {
                                            model: AppsStore.queueItems

                                            delegate: SettingRow {
                                                required property var modelData
                                                label: modelData.name
                                                description: `${modelData.action} · ${Store.statusLabel(modelData.status)}`
                                            }
                                        }
                                    }

                                    // Import local AppImage
                                    SectionContainer {
                                        Eyebrow {
                                            label: qsTr("Import local AppImage")
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: qsTr("Integrates a local .AppImage into your user application directory and desktop launcher. AppImages are not sandboxed by default.")
                                            color: Signal.palette.inkMuted
                                            font.pointSize: Appearance.font.size.smaller
                                            wrapMode: Text.WordWrap
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: qsTr("Path to .AppImage file (e.g. ~/Downloads/Tool.AppImage)")
                                            color: Signal.palette.inkMuted
                                            font.pointSize: Appearance.font.size.smaller
                                        }

                                        StyledInputField {
                                            Layout.fillWidth: true
                                            horizontalAlignment: TextInput.AlignLeft
                                            text: win.appImagePath
                                            Accessible.name: qsTr("AppImage file path")
                                            onTextEdited: t => win.appImagePath = t
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: qsTr("Application display name (optional)")
                                            color: Signal.palette.inkMuted
                                            font.pointSize: Appearance.font.size.smaller
                                        }

                                        StyledInputField {
                                            Layout.fillWidth: true
                                            horizontalAlignment: TextInput.AlignLeft
                                            text: win.appImageName
                                            Accessible.name: qsTr("AppImage display name")
                                            onTextEdited: t => win.appImageName = t
                                        }

                                        IconTextButton {
                                            icon: "file-download"
                                            text: qsTr("Import local AppImage")
                                            type: IconTextButton.Tonal
                                            onClicked: {
                                                if (!AppsStore.busy && win.appImagePath.trim() !== "")
                                                    AppsStore.importAppImage(win.appImagePath, win.appImageName);
                                            }
                                        }
                                    }

                                    // Create Web App
                                    SectionContainer {
                                        Eyebrow {
                                            label: qsTr("Create isolated Web App")
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: qsTr("Create a desktop entry for an HTTPS web application with an isolated browser profile.")
                                            color: Signal.palette.inkMuted
                                            font.pointSize: Appearance.font.size.smaller
                                            wrapMode: Text.WordWrap
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: qsTr("Web App name (e.g. Linear)")
                                            color: Signal.palette.inkMuted
                                            font.pointSize: Appearance.font.size.smaller
                                        }

                                        StyledInputField {
                                            Layout.fillWidth: true
                                            horizontalAlignment: TextInput.AlignLeft
                                            text: win.webAppName
                                            Accessible.name: qsTr("Web App name")
                                            onTextEdited: t => win.webAppName = t
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: qsTr("HTTPS URL (e.g. https://linear.app)")
                                            color: Signal.palette.inkMuted
                                            font.pointSize: Appearance.font.size.smaller
                                        }

                                        StyledInputField {
                                            Layout.fillWidth: true
                                            horizontalAlignment: TextInput.AlignLeft
                                            text: win.webAppUrl
                                            Accessible.name: qsTr("Web App URL")
                                            onTextEdited: t => win.webAppUrl = t
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: qsTr("Profile slug (optional)")
                                            color: Signal.palette.inkMuted
                                            font.pointSize: Appearance.font.size.smaller
                                        }

                                        StyledInputField {
                                            Layout.fillWidth: true
                                            horizontalAlignment: TextInput.AlignLeft
                                            text: win.webAppProfile
                                            Accessible.name: qsTr("Web App profile")
                                            onTextEdited: t => win.webAppProfile = t
                                        }

                                        IconTextButton {
                                            icon: "world"
                                            text: qsTr("Create Web App")
                                            type: IconTextButton.Tonal
                                            onClicked: {
                                                if (!AppsStore.busy && win.webAppName.trim() !== "" && win.webAppUrl.trim() !== "")
                                                    AppsStore.addWebApp(win.webAppName, win.webAppUrl, win.webAppProfile);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 7: Sources & Policy ──────────────────────────────────
                    Loader {
                        anchors.fill: parent
                        active: AppsStore.currentView === "sources"
                        visible: active

                        sourceComponent: Component {
                            StyledFlickable {
                                id: srcFlick

                                flickableDirection: Flickable.VerticalFlick
                                contentHeight: srcCol.implicitHeight
                                clip: true

                                StyledScrollBar.vertical: StyledScrollBar {
                                    flickable: srcFlick
                                }

                                ColumnLayout {
                                    id: srcCol

                                    width: srcFlick.width
                                    spacing: Appearance.spacing.large

                                    // Enterprise / Team Trust Policy Controls
                                    SectionContainer {
                                        Eyebrow {
                                            label: qsTr("Software trust policy")
                                        }

                                        SwitchRow {
                                            label: qsTr("Verified sources only (Official Vendor, Arch Official, Hornero Official, Flathub Verified)")
                                            checked: AppsStore.policy.verifiedOnly === true
                                            enabled: !AppsStore.busy
                                            onToggled: val => {
                                                const next = Object.assign({}, AppsStore.policy);
                                                next.verifiedOnly = val;
                                                AppsStore.updatePolicy(next);
                                            }
                                        }

                                        SwitchRow {
                                            label: qsTr("Open source software only")
                                            checked: AppsStore.policy.openSourceOnly === true
                                            enabled: !AppsStore.busy
                                            onToggled: val => {
                                                const next = Object.assign({}, AppsStore.policy);
                                                next.openSourceOnly = val;
                                                AppsStore.updatePolicy(next);
                                            }
                                        }

                                        SettingRow {
                                            label: qsTr("Community AUR policy")
                                            description: qsTr("Explicit opt-in requires PKGBUILD inspection; disabled hides/blocks AUR installs.")

                                            SegmentedControl {
                                                accessibleName: qsTr("Community AUR policy")
                                                model: [qsTr("Opt-in"), qsTr("Disabled")]
                                                currentIndex: AppsStore.policy.aurPolicy === "disabled" ? 1 : 0
                                                disabled: AppsStore.busy
                                                onActivated: idx => {
                                                    const next = Object.assign({}, AppsStore.policy);
                                                    next.aurPolicy = idx === 1 ? "disabled" : "explicit_opt_in";
                                                    AppsStore.updatePolicy(next);
                                                }
                                            }
                                        }

                                        SettingRow {
                                            label: qsTr("Proprietary software policy")
                                            description: qsTr("Explicit consent prompts before installing non-FOSS apps.")

                                            SegmentedControl {
                                                accessibleName: qsTr("Proprietary software policy")
                                                model: [qsTr("Explicit consent"), qsTr("Disabled")]
                                                currentIndex: AppsStore.policy.proprietaryPolicy === "disabled" ? 1 : 0
                                                disabled: AppsStore.busy
                                                onActivated: idx => {
                                                    const next = Object.assign({}, AppsStore.policy);
                                                    next.proprietaryPolicy = idx === 1 ? "disabled" : "explicit_consent";
                                                    AppsStore.updatePolicy(next);
                                                }
                                            }
                                        }
                                    }

                                    // Manifest Export / Import
                                    SectionContainer {
                                        Eyebrow {
                                            label: qsTr("Application manifest (Team & Workstation Provisioning)")
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: qsTr("Manifest JSON path (e.g. ~/hornero-apps-manifest.json)")
                                            color: Signal.palette.inkMuted
                                            font.pointSize: Appearance.font.size.smaller
                                        }

                                        StyledInputField {
                                            Layout.fillWidth: true
                                            horizontalAlignment: TextInput.AlignLeft
                                            text: win.manifestPath
                                            Accessible.name: qsTr("Manifest file path")
                                            onTextEdited: t => win.manifestPath = t
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: Appearance.spacing.small

                                            IconTextButton {
                                                icon: "upload"
                                                text: qsTr("Export Manifest")
                                                type: IconTextButton.Tonal
                                                onClicked: {
                                                    if (!AppsStore.busy)
                                                        AppsStore.exportManifest(win.manifestPath.trim() || `${Paths.home}/hornero-apps-manifest.json`);
                                                }
                                            }

                                            IconTextButton {
                                                icon: "file-download"
                                                text: qsTr("Import Manifest")
                                                type: IconTextButton.Tonal
                                                onClicked: {
                                                    if (!AppsStore.busy && win.manifestPath.trim() !== "")
                                                        AppsStore.importManifest(win.manifestPath);
                                                }
                                            }
                                        }
                                    }

                                    // Backend Sources Matrix
                                    SectionContainer {
                                        RowLayout {
                                            Layout.fillWidth: true

                                            Eyebrow {
                                                Layout.fillWidth: true
                                                label: qsTr("Backend capabilities")
                                            }

                                            TextButton {
                                                text: qsTr("Refresh")
                                                type: TextButton.Text
                                                onClicked: {
                                                    AppsStore.refreshSources();
                                                    AppsStore.refreshDoctor();
                                                }
                                            }
                                        }

                                        StyledText {
                                            visible: AppsStore.sources.length === 0
                                            Layout.fillWidth: true
                                            text: AppsStore.sourcesError || qsTr("No backend source diagnostics returned yet.")
                                            color: Signal.palette.inkMuted
                                        }

                                        Repeater {
                                            model: AppsStore.sources

                                            delegate: SettingRow {
                                                required property var modelData
                                                label: modelData.name
                                                description: modelData.detail || (modelData.scope !== "" ? qsTr("Scope: %1").arg(modelData.scope) : "")

                                                ProvenancePill {
                                                    text: modelData.ready ? qsTr("Ready") : qsTr("Unavailable")
                                                    icon: modelData.ready ? "circle-check" : "alert-triangle"
                                                    tone: modelData.ready ? "phosphor" : "alert"
                                                }
                                            }
                                        }
                                    }

                                    // Store Doctor Checks
                                    SectionContainer {
                                        Eyebrow {
                                            label: qsTr("Store health checks")
                                        }

                                        StyledText {
                                            visible: AppsStore.doctorReport.checks.length === 0
                                            Layout.fillWidth: true
                                            text: AppsStore.doctorReport.error || qsTr("No doctor checks reported.")
                                            color: Signal.palette.inkMuted
                                        }

                                        Repeater {
                                            model: AppsStore.doctorReport.checks

                                            delegate: SettingRow {
                                                required property var modelData
                                                label: modelData.name
                                                description: modelData.detail

                                                ProvenancePill {
                                                    text: modelData.ok ? qsTr("Pass") : qsTr("Check")
                                                    icon: modelData.ok ? "circle-check" : "alert-triangle"
                                                    tone: modelData.ok ? "phosphor" : "signal"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    AtmosphereLayer {
        lampOrigin: "topRight"
        lampReach: 1.0
    }
}
