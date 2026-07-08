import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Editor for Initial Camera Settings (mission item 0)
Rectangle {
    id: root
    width: availableWidth
    height: valuesColumn.height + (_margin * 2)
    color: qgcPal.windowShadeDark
    radius: ScreenTools.defaultBorderRadius

    required property var missionItem
    required property real availableWidth
    property real uiScale: 1.0

    property var _masterController: missionItem.masterController
    property var _controllerVehicle: _masterController.controllerVehicle
    property bool _waypointsOnlyMode: QGroundControl.corePlugin.options.missionWaypointsOnly
    property bool _showCameraSection: _waypointsOnlyMode || QGroundControl.corePlugin.showAdvancedUI
    property bool _simpleMissionStart: QGroundControl.corePlugin.options.showSimpleMissionStart

    readonly property real _margin: ScreenTools.defaultFontPixelWidth * uiScale / 2

    QGCPalette { id: qgcPal }

    ColumnLayout {
        id: valuesColumn
        anchors.margins: _margin
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: ScreenTools.defaultFontPixelHeight * root.uiScale / 2

        Column {
            Layout.fillWidth: true
            spacing: _margin
            visible: !_simpleMissionStart

            CameraSection {
                id: cameraSection
                anchors.left: parent.left
                anchors.right: parent.right
                missionItem: root.missionItem
                uiScale: root.uiScale
                visible: _showCameraSection
                showSectionHeader: false

                Component.onCompleted: checked = !_waypointsOnlyMode && missionItem.cameraSection.settingsSpecified
            }

            QGCLabel {
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("以上相机命令将在任务开始时立即生效。")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: ScreenTools.smallFontPointSize * root.uiScale
                visible: _showCameraSection && cameraSection.checked
            }
        }
    }
}
