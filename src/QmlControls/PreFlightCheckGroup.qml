import QtQuick
import QtQml.Models

import QGroundControl
import QGroundControl.Controls

/// A PreFlightCheckGroup manages a set of PreFlightCheckButtons as a single entity.
Column  {
    property string name
    property bool   passed: false
    property bool   failed: false

    spacing: ScreenTools.defaultFontPixelHeight * 0.35

    property bool _checked: true

    onPassedChanged: parent.groupPassedChanged(ObjectModel.index, passed)

    Component.onCompleted: {
        enabled = _checked
        var moveList = []
        var i = 0
        for (i = 2; i < children.length; i++) {
            moveList.push(children[i])
        }
        for (i = 0; i < moveList.length; i++) {
            moveList[i].parent = innerColumn
        }
    }

    function reset() {
        for (var i=0; i<innerColumn.children.length; i++) {
            innerColumn.children[i].reset()
        }
    }

    Rectangle {
        id:             header
        anchors.left:   parent.left
        anchors.right:  parent.right
        height:         ScreenTools.defaultFontPixelHeight * 1.72
        color:          headerMouseArea.pressed ? "#20251F" : (headerMouseArea.containsMouse ? "#2C332B" : "#222721")
        radius:         ScreenTools.defaultFontPixelHeight * 0.24
        border.width:   1
        border.color:   "#3F483E"

        readonly property color stateColor: failed ? "#D85D5D" : (passed ? "#8FCB7B" : "#F0F3EA")

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: ScreenTools.defaultFontPixelWidth * 0.42
            color: header.stateColor
            radius: parent.radius
        }

        QGCLabel {
            anchors.left: parent.left
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.95
            anchors.right: arrowLabel.left
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.45
            anchors.verticalCenter: parent.verticalCenter
            color: header.stateColor
            font.weight: Font.DemiBold
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.62
            elide: Text.ElideRight
            text: name + (passed ? qsTr(" · 已通过") : "")
        }

        QGCLabel {
            id: arrowLabel
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.65
            anchors.verticalCenter: parent.verticalCenter
            color: "#9AA493"
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
            text: _checked ? "⌃" : "⌄"
        }

        QGCMouseArea {
            id: headerMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: _checked = !_checked
        }
    }

    Column {
        id:         innerColumn
        spacing:    ScreenTools.defaultFontPixelHeight * 0.34
        visible:    _checked

        function buttonPassedChanged() {
            for (var i=0; i<children.length; i++) {
                if (!children[i].passed) {
                    passed = false
                    failed = children[i].failed
                    return
                }
            }
            failed = false
            passed = true
        }
    }
}
