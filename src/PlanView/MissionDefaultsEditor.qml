import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.PlanView

Rectangle {
    id: _root

    required property var missionController
    required property var planMasterController

    property var _controllerVehicle: planMasterController.controllerVehicle
    property var _visualItems: missionController.visualItems
    property bool _noMissionItemsAdded: _visualItems ? _visualItems.count <= 1 : true
    property var _settingsItem: _visualItems && _visualItems.count > 0 ? _visualItems.get(0) : null
    property bool _showVehicleSpeeds: false
    property bool _showCruiseSpeed: _controllerVehicle ? !_controllerVehicle.multiRotor : false
    property bool _showHoverSpeed: _controllerVehicle ? (_controllerVehicle.multiRotor || _controllerVehicle.vtol) : false
    property real _fieldWidth: ScreenTools.defaultFontPixelWidth * 16

    function _altitudeFrameExtraUnitsText(altFrame) {
        switch (altFrame) {
        case QGroundControl.AltitudeFrameRelative:
            return qsTr("相对")
        case QGroundControl.AltitudeFrameAbsolute:
            return qsTr("AMSL")
        case QGroundControl.AltitudeFrameCalcAboveTerrain:
            return qsTr("AGLC")
        case QGroundControl.AltitudeFrameTerrain:
            return qsTr("AGL")
        case QGroundControl.AltitudeFrameMixed:
            return qsTr("混合")
        default:
            return ""
        }
    }

    width:  parent ? parent.width : 0
    height: mainColumn.height + ScreenTools.defaultFontPixelHeight
    color:  theme.panelColor
    radius: theme.radius
    border.width: 1
    border.color: theme.borderColor

    QGCPalette { id: qgcPal; colorGroupEnabled: _root.enabled }
    PlanEditorTheme { id: theme }

    Connections {
        target: _root._controllerVehicle
        function onFirmwareTypeChanged() {
            if (!_root._controllerVehicle.supports.terrainFrame
                    && _root.missionController.globalAltitudeFrame === QGroundControl.AltitudeFrameTerrain) {
                _root.missionController.globalAltitudeFrame = QGroundControl.AltitudeFrameCalcAboveTerrain
            }
        }
    }

    Component { id: altFrameDialogComponent; AltFrameDialog { } }

    QGCPopupDialogFactory {
        id: altFrameDialogFactory
        dialogComponent: altFrameDialogComponent
    }

    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.5

        PlanLabelledButton {
            Layout.fillWidth: true
            label: qsTr("高度框架")
            buttonText: _root._altitudeFrameExtraUnitsText(_root.missionController.globalAltitudeFrame)

            onClicked: {
                let removeModes = []
                let updateFunction = function(altFrame) { _root.missionController.globalAltitudeFrame = altFrame }
                if (!_root._controllerVehicle.supports.terrainFrame) {
                    removeModes.push(QGroundControl.AltitudeFrameTerrain)
                }
                if (!_root._noMissionItemsAdded) {
                    if (_root.missionController.globalAltitudeFrame !== QGroundControl.AltitudeFrameRelative) {
                        removeModes.push(QGroundControl.AltitudeFrameRelative)
                    }
                    if (_root.missionController.globalAltitudeFrame !== QGroundControl.AltitudeFrameAbsolute) {
                        removeModes.push(QGroundControl.AltitudeFrameAbsolute)
                    }
                    if (_root.missionController.globalAltitudeFrame !== QGroundControl.AltitudeFrameCalcAboveTerrain) {
                        removeModes.push(QGroundControl.AltitudeFrameCalcAboveTerrain)
                    }
                    if (_root.missionController.globalAltitudeFrame !== QGroundControl.AltitudeFrameTerrain) {
                        removeModes.push(QGroundControl.AltitudeFrameTerrain)
                    }
                }
                altFrameDialogFactory.open({ currentAltFrame: _root.missionController.globalAltitudeFrame, rgRemoveModes: removeModes, updateAltFrameFn: updateFunction })
            }
        }

        PlanFactTextFieldSlider {
            Layout.fillWidth: true
            label: qsTr("航点高度")
            fact: QGroundControl.settingsManager.appSettings.defaultMissionItemAltitude
        }

        PlanFactTextFieldSlider {
            Layout.fillWidth: true
            label: qsTr("飞行速度")
            fact: _root._settingsItem ? _root._settingsItem.speedSection.flightSpeed : null
            showEnableCheckbox: true
            enableCheckBoxChecked: _root._settingsItem ? _root._settingsItem.speedSection.specifyFlightSpeed : false
            visible: _root._settingsItem ? _root._settingsItem.speedSection.available : false

            onEnableCheckboxClicked: {
                if (_root._settingsItem) {
                    _root._settingsItem.speedSection.specifyFlightSpeed = enableCheckBoxChecked
                }
            }
        }

        // ── Vehicle Speeds ──
        PlanSectionHeader {
            id: vehicleSpeedsSectionHeader
            Layout.fillWidth: true
            text: qsTr("飞行器速度")
            visible: _root._showVehicleSpeeds && (_root._showCruiseSpeed || _root._showHoverSpeed)
            checked: false
        }

        GridLayout {
            Layout.fillWidth: true
            columnSpacing: ScreenTools.defaultFontPixelWidth
            rowSpacing: columnSpacing
            columns: 2
            visible: vehicleSpeedsSectionHeader.visible && vehicleSpeedsSectionHeader.checked

            QGCLabel {
                Layout.columnSpan: 2
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
                text: qsTr("以下速度值用于计算任务总时间，不会影响任务的实际飞行速度。")
                color: theme.secondaryTextColor
            }

            QGCLabel {
                text: qsTr("巡航速度")
                visible: _root._showCruiseSpeed
                Layout.fillWidth: true
                color: theme.secondaryTextColor
            }
            PlanFactTextField {
                fact: QGroundControl.settingsManager.appSettings.offlineEditingCruiseSpeed
                visible: _root._showCruiseSpeed
                Layout.preferredWidth: _root._fieldWidth
            }

            QGCLabel {
                text: qsTr("悬停速度")
                visible: _root._showHoverSpeed
                Layout.fillWidth: true
                color: theme.secondaryTextColor
            }
            PlanFactTextField {
                fact: QGroundControl.settingsManager.appSettings.offlineEditingHoverSpeed
                visible: _root._showHoverSpeed
                Layout.preferredWidth: _root._fieldWidth
            }
        }
    }
}
