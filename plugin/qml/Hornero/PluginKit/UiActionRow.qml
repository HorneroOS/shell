import QtQuick

// Native popout action row (shell modules/bar/popouts): a full-width
// clickable row — leading icon, label filling the row, optional trailing
// icon — with the shell state layer on hover/press and the keyboard-only
// focus ring. Popover footers compose these instead of small ghost
// buttons, so extension popovers end like the shell's own popouts.
Item {
    id: root

    property string text: ""
    property string iconName: ""
    property string trailingIconName: ""
    property string tooltipText: ""
    property string accessibleName: root.text
    property bool enabled: true

    signal clicked()

    implicitWidth: row.implicitWidth + Theme.spacing * 2
    implicitHeight: Math.max(row.implicitHeight, Theme.iconSize) + Theme.spacingSmall * 2

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.description: root.tooltipText

    // Keyboard contract (shell issue 376): one tab stop while enabled;
    // Enter/Return and Space both activate, like UiButton.
    activeFocusOnTab: enabled
    Keys.onReturnPressed: event => {
        if (root.enabled) {
            root.clicked();
            event.accepted = true;
        }
    }
    Keys.onEnterPressed: event => {
        if (root.enabled) {
            root.clicked();
            event.accepted = true;
        }
    }
    Keys.onSpacePressed: event => {
        if (root.enabled) {
            root.clicked();
            event.accepted = true;
        }
    }

    UiTooltip {
        target: root
        text: root.tooltipText
    }

    HoverHandler {
        id: hover

        enabled: root.enabled
    }

    TapHandler {
        id: tap

        enabled: root.enabled
        onPressedChanged: {
            if (pressed)
                stateLayer.startRipple(point.position.x, point.position.y);
        }
        onTapped: root.clicked()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.rounding
        color: "transparent"
        opacity: root.enabled ? 1 : 0.5

        UiStateLayer {
            id: stateLayer

            anchors.fill: parent
            radius: Theme.rounding
            hovered: hover.hovered
            pressed: tap.pressed
            disabled: !root.enabled
            color: Theme.onSurface
        }
    }

    // Keyboard-only focus ring (shell FocusRing contract).
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: Theme.rounding + 2
        color: "transparent"
        border.width: 2
        border.color: Theme.focusRing
        visible: root.activeFocus && Theme.keyboardFocus && root.enabled
    }

    Row {
        id: row

        anchors.fill: parent
        anchors.leftMargin: Theme.spacing
        anchors.rightMargin: Theme.spacing
        spacing: Theme.spacingSmall

        UiIcon {
            visible: root.iconName.length > 0
            anchors.verticalCenter: parent.verticalCenter
            icon: root.iconName
            color: Theme.onSurfaceVariant
        }

        UiText {
            width: root.width - Theme.spacing * 2 - (root.iconName.length > 0 ? Theme.iconSize + Theme.spacingSmall : 0) - (root.trailingIconName.length > 0 ? Theme.iconSize + Theme.spacingSmall : 0)
            anchors.verticalCenter: parent.verticalCenter
            role: "body"
            text: root.text
            elide: Text.ElideRight
        }

        UiIcon {
            visible: root.trailingIconName.length > 0
            anchors.verticalCenter: parent.verticalCenter
            icon: root.trailingIconName
            color: Theme.onSurfaceVariant
        }
    }
}
