import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

/// Base class for Remote Control Calibration (supports both RC and Joystick)
ColumnLayout {
    required property var controller
    property Component additionalSetupComponent
    property Component additionalMonitorComponent
    property bool useDarkStyle: false

    // Controllers need access to these UI elements
    property alias statusText: statusText
    property alias cancelButton: cancelButton
    property alias nextButton: nextButton

    id: root
    spacing: ScreenTools.defaultFontPixelHeight

    property bool useDeadband: false

    property real _channelValueDisplayWidth: ScreenTools.defaultFontPixelWidth * 16
    property bool _deadbandActive: useDeadband
    readonly property color _darkPanelColor: "#2D2D2D"
    readonly property color _darkInputColor: "#252525"
    readonly property color _darkBorderColor: "#333333"
    readonly property color _darkPrimaryTextColor: "#FFFFFF"
    readonly property color _darkSecondaryTextColor: "#B0B0B0"
    readonly property color _darkDisabledTextColor: "#666666"
    readonly property color _darkAccentColor: "#2563EB"
    readonly property color _darkAccentHoverColor: "#1D4ED8"
    readonly property color _darkAccentPressedColor: "#1E40AF"
    readonly property color _darkButtonColor: "#333333"
    readonly property color _darkButtonHoverColor: "#3A3A3A"
    readonly property color _darkButtonPressedColor: "#2A2A2A"
    readonly property int _styleAnimDuration: 200

    QGCPalette { id: qgcPal; colorGroupEnabled: root.enabled }
    QGCPopupStyle { id: popupStyle }

    RowLayout {
        id: topControlsRow
        Layout.fillWidth: true
        spacing: ScreenTools.defaultFontPixelWidth

        // Left Column - Attitude Controls display
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight

            ColumnLayout {
                id: attitudeControlsLayout
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelHeight

                QGCLabel {
                    text: qsTr("Attitude Controls")
                    color: root.useDarkStyle ? root._darkPrimaryTextColor : qgcPal.text
                }

                Repeater {
                    model: [
                        { name: qsTr("Pitch"),      mapped: controller.pitchChannelMapped,      value: controller.adjustedPitchChannelValue,      deadband: controller.pitchDeadband },
                        { name: qsTr("Roll"),       mapped: controller.rollChannelMapped,       value: controller.adjustedRollChannelValue,       deadband: controller.rollDeadband },
                        { name: qsTr("Yaw"),        mapped: controller.yawChannelMapped,        value: controller.adjustedYawChannelValue,        deadband: controller.yawDeadband },
                        { name: qsTr("Throttle"),   mapped: controller.throttleChannelMapped,   value: controller.adjustedThrottleChannelValue,   deadband: controller.throttleDeadband }
                    ]

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: root.useDarkStyle ? root._darkPrimaryTextColor : qgcPal.text
                        }

                        RemoteControlChannelValueDisplay {
                            Layout.preferredWidth: root._channelValueDisplayWidth
                            mode: RemoteControlChannelValueDisplay.MappedValue
                            channelValueMin: controller.channelValueMin
                            channelValueMax: controller.channelValueMax
                            channelMapped: modelData.mapped
                            channelValue: modelData.value
                            deadbandValue: modelData.deadband
                            deadbandEnabled: root._deadbandActive
                            useDarkStyle: root.useDarkStyle
                        }
                    }
                }

                QGCLabel {
                    text: qsTr("Extension Controls")
                    color: root.useDarkStyle ? root._darkPrimaryTextColor : qgcPal.text
                    visible: controller.anyExtensionEnabled
                }

                Repeater {
                    model: [
                        { name: qsTr("Pitch"),  extensionEnabled: controller.pitchExtensionEnabled, mapped: controller.pitchExtensionChannelMapped, value: controller.adjustedPitchExtensionChannelValue,   deadband: controller.pitchExtensionDeadband },
                        { name: qsTr("Roll"),   extensionEnabled: controller.rollExtensionEnabled,  mapped: controller.rollExtensionChannelMapped,  value: controller.adjustedRollExtensionChannelValue,    deadband: controller.rollExtensionDeadband },
                        { name: qsTr("Aux 1"),  extensionEnabled: controller.aux1ExtensionEnabled,  mapped: controller.aux1ExtensionChannelMapped,  value: controller.adjustedAux1ExtensionChannelValue,    deadband: controller.aux1ExtensionDeadband },
                        { name: qsTr("Aux 2"),  extensionEnabled: controller.aux2ExtensionEnabled,  mapped: controller.aux2ExtensionChannelMapped,  value: controller.adjustedAux2ExtensionChannelValue,    deadband: controller.aux2ExtensionDeadband },
                        { name: qsTr("Aux 3"),  extensionEnabled: controller.aux3ExtensionEnabled,  mapped: controller.aux3ExtensionChannelMapped,  value: controller.adjustedAux3ExtensionChannelValue,    deadband: controller.aux3ExtensionDeadband },
                        { name: qsTr("Aux 4"),  extensionEnabled: controller.aux4ExtensionEnabled,  mapped: controller.aux4ExtensionChannelMapped,  value: controller.adjustedAux4ExtensionChannelValue,    deadband: controller.aux4ExtensionDeadband },
                        { name: qsTr("Aux 5"),  extensionEnabled: controller.aux5ExtensionEnabled,  mapped: controller.aux5ExtensionChannelMapped,  value: controller.adjustedAux5ExtensionChannelValue,    deadband: controller.aux5ExtensionDeadband },
                        { name: qsTr("Aux 6"),  extensionEnabled: controller.aux6ExtensionEnabled,  mapped: controller.aux6ExtensionChannelMapped,  value: controller.adjustedAux6ExtensionChannelValue,    deadband: controller.aux6ExtensionDeadband }
                    ]

                    RowLayout {
                        Layout.fillWidth: true
                        visible: modelData.extensionEnabled
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: root.useDarkStyle ? root._darkPrimaryTextColor : qgcPal.text
                        }

                        RemoteControlChannelValueDisplay {
                            Layout.preferredWidth: root._channelValueDisplayWidth
                            mode: RemoteControlChannelValueDisplay.MappedValue
                            channelValueMin: controller.channelValueMin
                            channelValueMax: controller.channelValueMax
                            channelMapped: modelData.mapped
                            channelValue: modelData.value
                            deadbandValue: modelData.deadband
                            deadbandEnabled: root._deadbandActive
                            useDarkStyle: root.useDarkStyle
                        }
                    }
                }
            }
        }

        // Right Column - Stick Display
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            readonly property real _maxPanelWidth: topControlsRow.width * 0.58
            readonly property real _minPanelWidth: ScreenTools.defaultFontPixelWidth * 20
            readonly property real _panelWidth: Math.max(_minPanelWidth, Math.min(stickDisplayContainer.implicitWidth, _maxPanelWidth))
            Layout.preferredWidth: _panelWidth
            Layout.minimumWidth: _minPanelWidth
            Layout.maximumWidth: _maxPanelWidth
            spacing: ScreenTools.defaultFontPixelHeight / 2

            Rectangle {
                id: stickDisplayContainer
                Layout.fillWidth: true
                implicitWidth: stickDisplayLayout.width + _margins * 2
                implicitHeight: stickDisplayLayout.height + _margins * 2
                border.color: root.useDarkStyle ? root._darkBorderColor : qgcPal.text
                border.width: 1
                color: root.useDarkStyle ? root._darkPanelColor : qgcPal.window
                radius: root.useDarkStyle ? popupStyle.cornerRadius : ScreenTools.defaultBorderRadius
                clip: true

                Behavior on color { ColorAnimation { duration: root._styleAnimDuration } }
                Behavior on border.color { ColorAnimation { duration: root._styleAnimDuration } }

                property real _margins: ScreenTools.defaultFontPixelHeight / 2
                property real _stickAdjust: leftStickDisplay.width / 2 - _margins * 1.25

                ColumnLayout {
                    id: stickDisplayLayout
                    anchors.leftMargin: stickDisplayContainer._margins
                    anchors.rightMargin: stickDisplayContainer._margins
                    anchors.topMargin: stickDisplayContainer._margins
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: stickDisplayContainer._margins

                    RowLayout {
                        id: modeControlsRow
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5

                        QGCComboBox {
                            id: transmitterModeComboBox
                            model: [
                                qsTr("Mode 1 (\u65e5\u672c\u624b)"),
                                qsTr("Mode 2 (\u7f8e\u56fd\u624b)"),
                                qsTr("Mode 3 (\u53cd\u7f8e\u624b)"),
                                qsTr("Mode 4 (\u53cd\u65e5\u624b)")
                            ]
                            Layout.preferredWidth: Math.min(ScreenTools.defaultFontPixelWidth * 14, modeControlsRow.width * 0.44)
                            Layout.maximumWidth: Math.min(ScreenTools.defaultFontPixelWidth * 15, modeControlsRow.width * 0.46)
                            enabled: !controller.calibrating
                            backgroundColor: root.useDarkStyle ? root._darkInputColor : qgcPal.button
                            borderColor: root.useDarkStyle ? root._darkBorderColor : qgcPal.buttonBorder
                            focusBorderColor: root.useDarkStyle ? root._darkAccentColor : qgcPal.buttonBorder
                            textColor: root.useDarkStyle ? root._darkPrimaryTextColor : qgcPal.buttonText
                            popupBackgroundColor: root.useDarkStyle ? "#1A1A1A" : qgcPal.window
                            popupBorderColor: root.useDarkStyle ? root._darkBorderColor : qgcPal.text
                            delegateSelectedBackgroundColor: root.useDarkStyle ? root._darkAccentColor : qgcPal.buttonHighlight
                            delegateSelectedTextColor: root.useDarkStyle ? root._darkPrimaryTextColor : qgcPal.buttonHighlightText
                            showFocusBorder: root.useDarkStyle
                            borderRadius: root.useDarkStyle ? popupStyle.cornerRadius : ScreenTools.defaultBorderRadius

                            onActivated: (index) => controller.transmitterMode = index + 1

                            Component.onCompleted: currentIndex = controller.transmitterMode - 1
                        }

                        QGCCheckBox {
                            id: centeredThrottleCheckBox
                            Layout.fillWidth: true
                            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 13
                            text: qsTr("Centered Throttle")
                            checked: controller.centeredThrottle
                            enabled: !controller.calibrating
                            visible: !controller.joystickMode
                            textColor: root.useDarkStyle ? root._darkSecondaryTextColor : qgcPal.buttonText
                            boxBackgroundColor: root.useDarkStyle ? root._darkInputColor : (enabled ? "white" : "transparent")
                            boxBorderColor: root.useDarkStyle ? root._darkBorderColor : qgcPal.buttonBorder
                            checkColor: root.useDarkStyle ? root._darkAccentColor : qgcPal.buttonHighlight
                            hoverColor: root.useDarkStyle ? "#3A3A3A" : qgcPal.buttonHighlight

                            onClicked: controller.centeredThrottle = checked
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        Layout.maximumWidth: modeControlsRow.width
                        visible: controller.calibrating
                        text: qsTr("\u6b63\u5728\u6821\u51c6\uff0c\u6a21\u5f0f\u4e0e\u6cb9\u95e8\u7c7b\u578b\u4f1a\u88ab\u9501\u5b9a\u3002\u8bf7\u5148\u7ed3\u675f/\u53d6\u6d88\u6821\u51c6\u540e\u518d\u9009\u62e9\u3002")
                        color: root.useDarkStyle ? "#F0BB6C" : qgcPal.warningText
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: stickDisplayContainer._margins * 2

                        Rectangle {
                            id: leftStickDisplay
                            Layout.alignment: Qt.AlignLeft
                            implicitWidth: ScreenTools.defaultFontPixelHeight * 5
                            implicitHeight: implicitWidth
                            radius: implicitWidth / 2
                            border.color: root.useDarkStyle ? root._darkBorderColor : qgcPal.buttonHighlight
                            border.width: 1
                            color: root.useDarkStyle ? root._darkInputColor : qgcPal.window

                            Rectangle {
                                x: parent.width / 2 + stickDisplayContainer._stickAdjust * controller.stickDisplayPositions[0] - width / 2
                                y: parent.height / 2 + stickDisplayContainer._stickAdjust * -controller.stickDisplayPositions[1] - height / 2
                                width: ScreenTools.defaultFontPixelHeight
                                height: width
                                radius: width / 2
                                color: root.useDarkStyle ? root._darkAccentColor : qgcPal.buttonHighlight
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignRight
                            implicitWidth: leftStickDisplay.implicitWidth
                            implicitHeight: implicitWidth
                            radius: implicitWidth / 2
                            border.color: root.useDarkStyle ? root._darkBorderColor : qgcPal.buttonHighlight
                            border.width: 1
                            color: root.useDarkStyle ? root._darkInputColor : qgcPal.window
                            visible: !controller.singleStickDisplay

                            Rectangle {
                                x: parent.width / 2 + stickDisplayContainer._stickAdjust * controller.stickDisplayPositions[2] - width / 2
                                y: parent.height / 2 + stickDisplayContainer._stickAdjust * -controller.stickDisplayPositions[3] - height / 2
                                width: ScreenTools.defaultFontPixelHeight
                                height: width
                                radius: width / 2
                                color: root.useDarkStyle ? root._darkAccentColor : qgcPal.buttonHighlight
                            }
                        }
                    }
                }
            }
        }
    }

    // Command Buttons and Status Text
    RowLayout {
        Layout.preferredWidth: parent.width
        spacing: ScreenTools.defaultFontPixelWidth

        QGCButton {
            id: cancelButton
            text: qsTr("Cancel")
            borderColor: root.useDarkStyle ? root._darkBorderColor : qgcPal.buttonBorder
            textColor: root.useDarkStyle ? root._darkPrimaryTextColor : qgcPal.buttonText
            backgroundColor: root.useDarkStyle ? (pressed ? root._darkButtonPressedColor : (hovered ? root._darkButtonHoverColor : root._darkButtonColor)) : qgcPal.button
            backRadius: root.useDarkStyle ? popupStyle.cornerRadius : ScreenTools.defaultBorderRadius
            showBorder: root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
            overlayColor: root.useDarkStyle ? "transparent" : qgcPal.buttonHighlight
            onClicked: controller.cancelButtonClicked()
        }

        QGCButton {
            id: nextButton
            primary: true
            text: qsTr("Calibrate")
            backgroundColor: root.useDarkStyle ? (pressed ? root._darkAccentPressedColor : (hovered ? root._darkAccentHoverColor : root._darkAccentColor)) : qgcPal.primaryButton
            borderColor: root.useDarkStyle ? root._darkBorderColor : qgcPal.buttonBorder
            textColor: root.useDarkStyle ? root._darkPrimaryTextColor : qgcPal.primaryButtonText
            backRadius: root.useDarkStyle ? popupStyle.cornerRadius : ScreenTools.defaultBorderRadius
            showBorder: root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
            overlayColor: root.useDarkStyle ? "transparent" : qgcPal.buttonHighlight

            onClicked: {
                if (text === qsTr("Calibrate")) {
                    if (controller.channelCount < controller.minChannelCount) {
                        let errorMessage = ""
                        let title = ""
                        if (controller.joystickMode) {
                            title = qsTr("Joystick Not Ready")
                            errorMessage = qsTr("%1 axes or more are needed to fly. Joystick is reporting %2 axes.").arg(controller.minChannelCount).arg(controller.channelCount)
                        } else {
                            title = qsTr("Not Ready")
                            errorMessage = controller.channelCount === 0 ? qsTr("Please turn on RC transmitter.") : qsTr("%1 channels or more are needed to fly.").arg(controller.minChannelCount)
                        }
                        QGroundControl.showMessageDialog(root, title, errorMessage)
                        return
                    } else if (!controller.joystickMode) {
                        QGroundControl.showMessageDialog(root, qsTr("Zero Trims"),
                                                        qsTr("Before calibrating you should zero all your trims and subtrims. Click Ok to start Calibration.\n\n%1").arg(
                                                            (QGroundControl.multiVehicleManager.activeVehicle.px4Firmware ? "" : qsTr("Please ensure all motor power is disconnected AND all props are removed from the vehicle."))),
                                                        Dialog.Ok,
                                                        function() { controller.nextButtonClicked() })
                        return
                    }
                }
                controller.nextButtonClicked()
            }
        }

        QGCLabel {
            id: statusText
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: root.useDarkStyle ? (enabled ? root._darkSecondaryTextColor : root._darkDisabledTextColor) : qgcPal.text
        }
    }

    Rectangle {
        id: separator
        Layout.fillWidth: true
        implicitHeight: 1
        color: root.useDarkStyle ? root._darkBorderColor : qgcPal.text
    }

    // Additional Setup + Channel Monitor
    RowLayout {
        id: additionalSetupRow
        Layout.fillWidth: true
        spacing: ScreenTools.defaultFontPixelWidth * 2

        readonly property real _setupMinWidth: ScreenTools.defaultFontPixelWidth * 17
        readonly property real _monitorMinWidth: ScreenTools.defaultFontPixelWidth * 14

        Item {
            Layout.fillWidth: true
            implicitHeight: 1
            visible: additionalSetupComponent === undefined
        }

        Loader {
            id: additionalSetupLoader
            readonly property real _preferredLoaderWidth: Math.max(implicitWidth, additionalSetupRow.width * 0.52)
            visible: additionalSetupComponent !== undefined
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            Layout.preferredWidth: _preferredLoaderWidth
            Layout.minimumWidth: additionalSetupRow._setupMinWidth
            Layout.maximumWidth: additionalSetupRow.width * 0.66
            sourceComponent: additionalSetupComponent
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            Layout.minimumWidth: additionalSetupRow._monitorMinWidth
            Layout.preferredWidth: Math.max(additionalSetupRow._monitorMinWidth, additionalSetupRow.width * 0.34)
            Layout.maximumWidth: additionalSetupRow.width * 0.46
            spacing: ScreenTools.defaultFontPixelHeight

            RemoteControlChannelMonitor {
                id: channelMonitor
                Layout.fillWidth: true
                twoColumn: false
                useDarkStyle: root.useDarkStyle
                channelCount: controller.channelCount
                channelValueMin: controller.channelValueMin
                channelValueMax: controller.channelValueMax

                Connections {
                    target: controller
                    onRawChannelValueChanged: (channel, channelValue) => channelMonitor.rawChannelValueChanged(channel, channelValue)
                }
            }

            Loader {
                id: additionalMonitorLoader
                Layout.preferredWidth: parent.width
                sourceComponent: additionalMonitorComponent
            }
        }
    }
}
