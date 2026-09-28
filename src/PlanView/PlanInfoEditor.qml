import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id: _root

    required property var planMasterController
    required property var missionController
    required property var editorMap

    property real uiScale: 1.0
    property var _controllerVehicle: planMasterController.controllerVehicle
    property var _visualItems: missionController.visualItems
    property bool _noMissionItemsAdded: _visualItems ? _visualItems.count <= 1 : true
    property var _settingsItem: _visualItems && _visualItems.count > 0 ? _visualItems.get(0) : null
    property bool _multipleFirmware: !QGroundControl.singleFirmwareSupport
    property bool _multipleVehicleTypes: !QGroundControl.singleVehicleSupport
    property bool _allowFWVehicleTypeSelection: _noMissionItemsAdded && planMasterController.offline
    property bool _waypointsOnlyMode: QGroundControl.corePlugin.options.missionWaypointsOnly
    property real _fieldWidth: ScreenTools.defaultFontPixelWidth * 16 * uiScale
    property real _loopRepeatControlSize: Math.round(ScreenTools.defaultFontPixelHeight * 1.75 * uiScale)

    function _vehicleTypeText(vehicleType) {
        switch (vehicleType) {
        case "Fixed Wing":
            return qsTr("固定翼")
        case "Multi-Rotor":
        case "Multirotor":
            return qsTr("多旋翼")
        case "VTOL":
            return qsTr("VTOL")
        case "Rover":
            return qsTr("无人车/船")
        case "Sub":
            return qsTr("水下航行器")
        case "Airship":
            return qsTr("飞艇")
        case "Unknown":
            return qsTr("未知")
        default:
            return vehicleType
        }
    }

    function _setMissionLoopRepeatCountFromText(text) {
        const repeatCount = Math.max(1, Math.min(10, parseInt(text)))
        _root.missionController.missionLoopRepeatCount = isNaN(repeatCount) ? 1 : repeatCount
        loopRepeatField.text = _root.missionController.missionLoopRepeatCount.toString()
    }

    width:  parent ? parent.width : 0
    height: mainColumn.height + ScreenTools.defaultFontPixelHeight
    color:  theme.panelColor
    radius: theme.radius
    border.width: 1
    border.color: theme.borderColor

    QGCPalette { id: qgcPal; colorGroupEnabled: _root.enabled }
    PlanEditorTheme { id: theme }

    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.25

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            QGCLabel {
                text: qsTr("计划文件")
                color: theme.textColor
            }

            PlanTextField {
                id: planNameField
                placeholderText: qsTr("未命名")
                Layout.fillWidth: true

                Component.onCompleted: text = _root.planMasterController.currentPlanFileName

                Connections {
                    target: _root.planMasterController
                    function onCurrentPlanFileNameChanged() {
                        if (!planNameField.activeFocus) {
                            planNameField.text = _root.planMasterController.currentPlanFileName
                        }
                    }
                }

                onEditingFinished: _root.planMasterController.currentPlanFileName = text
            }
        }

        // ── Vehicle Info ──
        PlanSectionHeader {
            id: vehicleInfoSectionHeader
            Layout.fillWidth: true
            text: qsTr("飞行器信息")
            visible: !_root._waypointsOnlyMode
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth
            visible: vehicleInfoSectionHeader.visible && vehicleInfoSectionHeader.checked

            PlanFactComboBox {
                fact: QGroundControl.settingsManager.appSettings.offlineEditingFirmwareClass
                indexModel: false
                Layout.fillWidth: true
                visible: _root._multipleFirmware && _root._allowFWVehicleTypeSelection
            }
            QGCLabel {
                text: _root._controllerVehicle ? _root._controllerVehicle.firmwareTypeString : ""
                Layout.fillWidth: true
                visible: _root._multipleFirmware && !_root._allowFWVehicleTypeSelection
                color: theme.secondaryTextColor
            }

            PlanFactComboBox {
                fact: QGroundControl.settingsManager.appSettings.offlineEditingVehicleClass
                indexModel: false
                Layout.fillWidth: true
                visible: _root._multipleVehicleTypes && _root._allowFWVehicleTypeSelection
            }
            QGCLabel {
                text: _root._controllerVehicle ? _root._vehicleTypeText(_root._controllerVehicle.vehicleTypeString) : ""
                Layout.fillWidth: true
                visible: _root._multipleVehicleTypes && !_root._allowFWVehicleTypeSelection
                color: theme.secondaryTextColor
            }
        }

        // ── Expected Home Position ──
        PlanSectionHeader {
            id: plannedHomePositionSection
            Layout.fillWidth: true
            text: qsTr("预计 Home 位置")
        }

        GridLayout {
            Layout.fillWidth: true
            columnSpacing: ScreenTools.defaultFontPixelWidth
            columns: 2
            visible: plannedHomePositionSection.checked

            QGCLabel {
                text: qsTr("高度 (AMSL)")
                color: theme.secondaryTextColor
            }
            PlanFactTextField {
                fact: _root._settingsItem ? _root._settingsItem.plannedHomePositionAltitude : null
                Layout.fillWidth: true
                visible: _root._settingsItem && _root._settingsItem.terrainQueryFailed
            }
            QGCLabel {
                text: _root._settingsItem ? _root._settingsItem.plannedHomePositionAltitude.valueString + " " + _root._settingsItem.plannedHomePositionAltitude.units : ""
                Layout.fillWidth: true
                visible: !_root._settingsItem || !_root._settingsItem.terrainQueryFailed
                color: theme.textColor
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pointSize: ScreenTools.smallFontPointSize * _root.uiScale
            text: qsTr("实际位置/高度由飞行器在飞行时设置。")
            horizontalAlignment: Text.AlignHCenter
            visible: plannedHomePositionSection.checked
            color: theme.secondaryTextColor
        }

        PlanButton {
            text: qsTr("移至地图中心")
            Layout.alignment: Qt.AlignHCenter
            visible: plannedHomePositionSection.checked
            onClicked: {
                if (_root._settingsItem) {
                    _root._settingsItem.coordinate = _root.editorMap.center
                }
            }
        }

        PlanSectionHeader {
            id: missionLoopSection
            Layout.fillWidth: true
            text: qsTr("循环航线")
            visible: !_root._waypointsOnlyMode
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight * 0.25
            visible: missionLoopSection.visible && missionLoopSection.checked

            PlanCheckBox {
                text: qsTr("启用循环航线")
                checked: _root.missionController.missionLoopEnabled
                enabled: _root.missionController.missionLoopAvailable || checked
                uiScale: _root.uiScale
                onClicked: _root.missionController.missionLoopEnabled = checked
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth
                enabled: _root.missionController.missionLoopEnabled

                QGCLabel {
                    text: qsTr("循环次数")
                    color: theme.secondaryTextColor
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    id: loopRepeatMinusButton
                    Layout.preferredWidth: _root._loopRepeatControlSize
                    Layout.preferredHeight: _root._loopRepeatControlSize
                    Layout.alignment: Qt.AlignVCenter
                    radius: theme.radius
                    border.width: 1
                    border.color: theme.borderColor
                    color: !enabled ? theme.panelColor : loopRepeatMinusMouse.pressed ? theme.panelPressedColor : loopRepeatMinusMouse.containsMouse ? theme.panelHoverColor : theme.inputColor
                    enabled: _root.missionController.missionLoopRepeatCount > 1

                    QGCLabel {
                        anchors.centerIn: parent
                        text: "-"
                        color: parent.enabled ? theme.textColor : theme.secondaryTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: loopRepeatMinusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.enabled
                        onClicked: _root.missionController.missionLoopRepeatCount = _root.missionController.missionLoopRepeatCount - 1
                    }
                }

                PlanTextField {
                    id: loopRepeatField
                    text: _root.missionController.missionLoopRepeatCount.toString()
                    horizontalAlignment: TextInput.AlignHCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 10 }
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5 * _root.uiScale
                    Layout.preferredHeight: _root._loopRepeatControlSize
                    Layout.alignment: Qt.AlignVCenter
                    onEditingFinished: _root._setMissionLoopRepeatCountFromText(text)

                    Connections {
                        target: _root.missionController
                        function onMissionLoopChanged() {
                            if (!loopRepeatField.activeFocus) {
                                loopRepeatField.text = _root.missionController.missionLoopRepeatCount.toString()
                            }
                        }
                    }
                }

                Rectangle {
                    id: loopRepeatPlusButton
                    Layout.preferredWidth: _root._loopRepeatControlSize
                    Layout.preferredHeight: _root._loopRepeatControlSize
                    Layout.alignment: Qt.AlignVCenter
                    radius: theme.radius
                    border.width: 1
                    border.color: theme.borderColor
                    color: !enabled ? theme.panelColor : loopRepeatPlusMouse.pressed ? theme.panelPressedColor : loopRepeatPlusMouse.containsMouse ? theme.panelHoverColor : theme.inputColor
                    enabled: _root.missionController.missionLoopRepeatCount < 10

                    QGCLabel {
                        anchors.centerIn: parent
                        text: "+"
                        color: parent.enabled ? theme.textColor : theme.secondaryTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: loopRepeatPlusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.enabled
                        onClicked: _root.missionController.missionLoopRepeatCount = _root.missionController.missionLoopRepeatCount + 1
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: qsTr("总执行 %1 圈").arg(_root.missionController.missionLoopRepeatCount + 1)
                    color: theme.secondaryTextColor
                }
            }

            QGCLabel {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize * _root.uiScale
                text: _root.missionController.missionLoopStatusText
                color: _root.missionController.missionLoopConflict ? qgcPal.warningText : theme.secondaryTextColor
            }
        }
    }
}
