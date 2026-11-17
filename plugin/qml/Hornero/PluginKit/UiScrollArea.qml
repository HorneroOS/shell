import QtQuick
import QtQuick.Controls

// Scrolling content region for desktop widgets and cards (PluginKit 4).
// Content that is taller than the frame the host gives the widget scrolls
// instead of being clipped: put it inside a UiScrollArea sized to the host
// context (`width: hostAvailableWidth`, `height: hostAvailableHeight`), and
// add children to `content`. The track is a 2 px `rule` line with a `cue`
// thumb that only shows while the content overflows; the mouse wheel and
// Up/Down/PageUp/PageDown scroll it, and it is a tab stop only while it
// scrolls (no empty tab stops).
Flickable {
    id: root

    default property alias content: inner.data
    property string accessibleName: "Scrollable content"

    clip: true
    contentWidth: width
    contentHeight: inner.childrenRect.height
    boundsBehavior: Flickable.StopAtBounds
    activeFocusOnTab: contentHeight > height
    Accessible.role: Accessible.Pane
    Accessible.name: root.accessibleName

    Item {
        id: inner

        width: root.width
        height: childrenRect.height
    }

    Keys.onPressed: event => {
        const page = root.height * 0.9;
        const maxY = Math.max(0, root.contentHeight - root.height);
        const steps = {};
        steps[Qt.Key_Down] = 40;
        steps[Qt.Key_Up] = -40;
        steps[Qt.Key_PageDown] = page;
        steps[Qt.Key_PageUp] = -page;
        if (steps[event.key] !== undefined) {
            root.contentY = Math.max(0, Math.min(maxY, root.contentY + steps[event.key]));
            event.accepted = true;
        }
    }

    ScrollBar.vertical: ScrollBar {
        policy: root.contentHeight > root.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        implicitWidth: 4
        contentItem: Rectangle {
            implicitWidth: 2
            radius: 1
            color: Theme.palette.cue
        }
        background: Rectangle {
            implicitWidth: 2
            color: Theme.palette.rule
        }
    }
}
