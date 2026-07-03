import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.VehicleSetup
import QGroundControl.FactControls

SetupPage {
    centerPageLoader: true
    pageComponent: joystickManager.activeJoystick ? pageComponent : noJoysticksComponent
    pageDescription: joystickManager.activeJoystick ? (vehicleComponent ? vehicleComponent.description : "") : ""

    Component {
        id: pageComponent

        Item {
            id: pageRoot
            width: availableWidth
            height: availableHeight
            property bool _qgcPopupChrome: true
            property real _margins: ScreenTools.defaultFontPixelHeight

            Rectangle {
                anchors.fill: parent
                color: "#202020"
                border.width: 1
                border.color: "#333333"
                radius: 8
            }

            QGCFlickable {
                id: contentFlick
                anchors.fill: parent
                anchors.margins: pageRoot._margins
                clip: true
                contentWidth: width
                contentHeight: Math.max(height, contentCard.implicitHeight + pageRoot._margins * 2)

                Rectangle {
                    id: contentCard
                    width: Math.min(contentFlick.width, ScreenTools.defaultFontPixelWidth * 118)
                    implicitHeight: contentLayout.implicitHeight + pageRoot._margins * 2
                    x: (contentFlick.width - width) / 2
                    y: (contentFlick.contentHeight - implicitHeight) / 2
                    color: "#2D2D2D"
                    border.width: 1
                    border.color: "#333333"
                    radius: 8

                    ColumnLayout {
                        id: contentLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: pageRoot._margins
                        spacing: ScreenTools.defaultFontPixelHeight / 2

                        property Fact activeJoystickNameFact: QGroundControl.settingsManager.joystickManagerSettings.activeJoystickName
                        property string activeJoystickName: activeJoystickNameFact.value
                        property var availableJoystickNames: joystickManager.availableJoystickNames
                        property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
                        property var activeJoystick: joystickManager.activeJoystick
                        property bool activeJoystickCalibrated: activeJoystick ? activeJoystick.settings.calibrated.rawValue : false

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth
                            visible: joystickCombo.visible || calibrationRequiredLabel.visible

                            QGCComboBox {
                                id: joystickCombo
                                sizeToContents: true
                                visible: activeJoystickName !== "" && QGroundControl.corePlugin.options.allowJoystickSelection

                                onActivated: (index) => { activeJoystickNameFact.rawValue = textAt(index) }

                                function _buildModel() {
                                    const availableNames = joystickManager.availableJoystickNames || [];
                                    const modelNames = [...availableNames];
                                    if (activeJoystickName && !modelNames.includes(activeJoystickName)) {
                                        modelNames.push(activeJoystickName);
                                    }
                                    joystickCombo.model = modelNames;
                                }

                                function _selectActiveJoystick() {
                                    let index = joystickCombo.find(activeJoystickName)
                                    if (index === -1) {
                                        console.warn("Internal error: Active joystick name not in combo", activeJoystickName)
                                    } else {
                                        joystickCombo.currentIndex = index
                                    }
                                }

                                function _recalc() {
                                    _buildModel()
                                    _selectActiveJoystick()
                                }

                                Component.onCompleted: _recalc()
                                Connections { target: contentLayout; function onActiveJoystickNameChanged() { joystickCombo._recalc() } }
                                Connections { target: joystickManager; function onAvailableJoystickNamesChanged() { joystickCombo._recalc() } }
                            }

                            QGCCheckBox {
                                text: qsTr("启用")
                                checked: joystickManager.activeJoystickEnabledForActiveVehicle
                                enabled: activeJoystickCalibrated

                                onClicked: joystickManager.activeJoystickEnabledForActiveVehicle = checked
                            }

                            QGCLabel {
                                font.pointSize: ScreenTools.smallFontPointSize
                                color: "#B0B0B0"
                                text: qsTr("当前不可用")
                                visible: !activeJoystick
                            }

                            QGCLabel {
                                id: calibrationRequiredLabel
                                text: activeJoystickCalibrated ? qsTr("已校准") : qsTr("需要校准")
                                enabled: !activeJoystickCalibrated
                            }
                        }

                        Loader {
                            id: remoteControlCalibrationLoader
                            Layout.fillWidth: true
                            sourceComponent: activeJoystick && !activeVehicle.armed ? remoteControlCalibrationComponent : null
                        }

                        Component {
                            id: remoteControlCalibrationComponent

                            RemoteControlCalibration {
                                id: remoteControlCalibration

                                controller: JoystickConfigController {
                                    joystick: joystickManager.activeJoystick
                                    statusText: remoteControlCalibration.statusText
                                    cancelButton: remoteControlCalibration.cancelButton
                                    nextButton: remoteControlCalibration.nextButton
                                    joystickMode: true
                                }

                                useDeadband: controller && controller.joystick && controller.joystick.settings.useDeadband.rawValue

                                additionalSetupComponent: _activeJoystick ? _additionalSetupComponent : null
                                additionalMonitorComponent: _activeJoystick ? _additionalMonitorComponent : null

                                property var _controller: controller
                                property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
                                property var _activeJoystick: _controller.joystick
                                property bool _requiresCalibration: _activeJoystick ? (_activeJoystick.requiresCalibration && !_activeJoystick.settings.calibrated.rawValue) : false

                                Component.onCompleted: controller.start()

                                Connections {
                                    target: controller

                                    function onCalibrationCompleted() {
                                        if (joystickManager.activeJoystickEnabledForActiveVehicle) {
                                            return;
                                        }
                                        QGroundControl.showMessageDialog(
                                                    contentLayout,
                                                    qsTr("启用摇杆"),
                                                    qsTr("%1 已完成校准。现在启用吗？").arg(_activeJoystick.name),
                                                    Dialog.Yes | Dialog.No,
                                                    function() { joystickManager.activeJoystickEnabledForActiveVehicle = true });
                                    }
                                }

                                Component {
                                    id: _additionalSetupComponent

                                    ColumnLayout {
                                        spacing: ScreenTools.defaultFontPixelHeight / 2
                                        enabled: !controller.calibrating

                                        QGCTabBar {
                                            id: tabBar
                                            Layout.fillWidth: true

                                            QGCTabButton {
                                                text: qsTr("按钮")
                                                checked: true
                                            }

                                            QGCTabButton {
                                                text: qsTr("设置")
                                                checked: false
                                            }
                                        }

                                        JoystickComponentButtons {
                                            id: joystickButtons
                                            Layout.fillWidth: true
                                            joystick: _activeJoystick
                                            controller: _controller
                                            visible: tabBar.currentIndex === 0
                                        }

                                        JoystickComponentSettings {
                                            id: joystickSettings
                                            Layout.fillWidth: true
                                            joystick: _activeJoystick
                                            visible: tabBar.currentIndex === 1
                                        }
                                    }
                                }

                                Component {
                                    id: _additionalMonitorComponent

                                    JoystickComponentButtonMonitor {
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: noJoysticksComponent
        Item {
            width: availableWidth
            height: availableHeight
            property bool _qgcPopupChrome: true

            Rectangle {
                anchors.fill: parent
                color: "#202020"
                border.width: 1
                border.color: "#333333"
                radius: 8
            }

            Rectangle {
                width: Math.min(parent.width * 0.9, ScreenTools.defaultFontPixelWidth * 82)
                implicitHeight: centeredTextColumn.implicitHeight + ScreenTools.defaultFontPixelHeight * 2
                anchors.centerIn: parent
                color: "#2D2D2D"
                border.width: 1
                border.color: "#333333"
                radius: 8

                ColumnLayout {
                    id: centeredTextColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: ScreenTools.defaultFontPixelHeight
                    spacing: ScreenTools.defaultFontPixelHeight * 0.75

                    QGCLabel {
                        Layout.fillWidth: true
                        text: qsTr("配置轴校准、按键映射和输入设置。")
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        text: qsTr("未检测到摇杆或游戏手柄。")
                        color: "#B0B0B0"
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
