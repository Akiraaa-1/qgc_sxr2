import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

SetupPage {
    id:                 motorPage
    pageComponent:      pageComponent
    centerPageLoader:   true

    property bool userLetterMotorIndices: false
    property bool _qgcPopupChrome: true

    readonly property int _barHeight:           10
    readonly property int _barWidth:            5
    readonly property int _sliderWidth:         15
    readonly property int _motorTimeoutSecs:    3

    QGCPopupStyle { id: popupStyle }

    function motorIndexToString(motorIndex) {
        let asciiA = 65;
        if (userLetterMotorIndices) {
            return String.fromCharCode(asciiA + motorIndex);
        } else {
            return motorIndex + 1;
        }
    }

    FactPanelController {
        id: controller
    }

    Component {
        id: pageComponent

        Item {
            id: pageRoot

            readonly property real _outerMargin:       ScreenTools.defaultFontPixelHeight
            readonly property real _panelPadding:      ScreenTools.defaultFontPixelHeight * 1.1
            readonly property real _sectionSpacing:    ScreenTools.defaultFontPixelHeight * 0.8
            readonly property real _contentMinWidth:   ScreenTools.defaultFontPixelWidth * 36
            readonly property real _contentMaxWidth:   ScreenTools.defaultFontPixelWidth * 64
            readonly property real _availableWidth:    Math.max(ScreenTools.defaultFontPixelWidth * 28, motorPage.availableWidth - (_outerMargin * 2))
            readonly property real _panelWidth:        Math.min(_contentMaxWidth, Math.max(_contentMinWidth, _availableWidth))

            implicitWidth:  Math.max(_panelWidth + (_outerMargin * 2), motorPage.availableWidth)
            implicitHeight: Math.max(panelFrame.height + (_outerMargin * 2), motorPage.availableHeight)
            width:          implicitWidth
            height:         implicitHeight

            Rectangle {
                anchors.fill: parent
                radius: popupStyle.cornerRadius
                border.color: popupStyle.borderColor
                border.width: 1
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: popupStyle.popupBackground }
                    GradientStop { position: 1.0; color: "#222222" }
                }
            }

            Rectangle {
                id: panelFrame
                width: pageRoot._panelWidth
                height: contentColumn.implicitHeight + (pageRoot._panelPadding * 2)
                anchors.centerIn: parent
                radius: popupStyle.cornerRadius
                color: popupStyle.panelBackground
                border.color: popupStyle.borderColor
                border.width: 1

                Column {
                    id: contentColumn
                    anchors.top: parent.top
                    anchors.topMargin: pageRoot._panelPadding
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: panelFrame.width - (pageRoot._panelPadding * 2)
                    spacing: pageRoot._sectionSpacing

                    Rectangle {
                        width: parent.width
                        height: warningLabel.contentHeight + (ScreenTools.defaultFontPixelHeight * 0.8)
                        visible: controller.vehicle.motorCount == -1
                        radius: popupStyle.cornerRadius
                        color: popupStyle.inputBackground
                        border.color: popupStyle.borderColor
                        border.width: 1

                        QGCLabel {
                            id: warningLabel
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.4
                            wrapMode: Text.WordWrap
                            color: qgcPal.warningText
                            text: qsTr("Warning: Unable to determine motor count")
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: sliderColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.9)
                        radius: popupStyle.cornerRadius
                        color: popupStyle.inputBackground
                        border.color: popupStyle.borderColor
                        border.width: 1

                        Column {
                            id: sliderColumn
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.45
                            spacing: ScreenTools.defaultFontPixelHeight * 0.5

                            QGCLabel {
                                text: qsTr("Motor Output")
                                font.pointSize: ScreenTools.mediumFontPointSize
                            }

                            ValueSlider {
                                id:                 sliderThrottle
                                width:              parent.width
                                enabled:            safetySwitch.checked
                                label:              qsTr("Throttle")
                                from:               0
                                to:                 100
                                majorTickStepSize:  5
                                decimalPlaces:      0
                                unitsString:        qsTr("%")
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: infoLabel.contentHeight + (ScreenTools.defaultFontPixelHeight * 0.8)
                        radius: popupStyle.cornerRadius
                        color: popupStyle.inputBackground
                        border.color: popupStyle.borderColor
                        border.width: 1

                        QGCLabel {
                            id: infoLabel
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.4
                            wrapMode: Text.WordWrap
                            color: popupStyle.secondaryTextColor
                            text: qsTr("Make sure you remove all props.")
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: buttonColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.9)
                        radius: popupStyle.cornerRadius
                        color: popupStyle.inputBackground
                        border.color: popupStyle.borderColor
                        border.width: 1
                        opacity: enabled ? 1 : 0.78
                        enabled: safetySwitch.checked

                        Behavior on opacity { NumberAnimation { duration: popupStyle.stateAnimationDuration } }

                        Column {
                            id: buttonColumn
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.45
                            spacing: ScreenTools.defaultFontPixelHeight * 0.5

                            QGCLabel {
                                text: qsTr("Motors")
                                font.pointSize: ScreenTools.mediumFontPointSize
                            }

                            Flow {
                                id: buttonFlow
                                width: parent.width
                                spacing: ScreenTools.defaultFontPixelWidth * 1.5

                                Repeater {
                                    id:         buttonRepeater
                                    model:      controller.vehicle.motorCount === -1 ? 8 : controller.vehicle.motorCount

                                    QGCButton {
                                        id:         button
                                        width:      Math.max(ScreenTools.implicitButtonWidth, ScreenTools.defaultFontPixelWidth * 6.5)
                                        text:       motorIndexToString(index)
                                        onClicked:  {
                                            controller.vehicle.motorTest(index + 1, sliderThrottle.value, sliderThrottle.value === 0 ? 0 : _motorTimeoutSecs, true)
                                        }
                                    }
                                }

                                QGCButton {
                                    id:       allButton
                                    width:    Math.max(implicitWidth, ScreenTools.defaultFontPixelWidth * 11)
                                    text:     qsTr("All")
                                    primary:  enabled
                                    onClicked: {
                                        for (var motorIndex=0; motorIndex<buttonRepeater.count; motorIndex++) {
                                            controller.vehicle.motorTest(motorIndex + 1, sliderThrottle.value, sliderThrottle.value === 0 ? 0 : _motorTimeoutSecs, true)
                                        }
                                    }
                                }

                                QGCButton {
                                    id:      allStopButton
                                    width:   Math.max(implicitWidth, ScreenTools.defaultFontPixelWidth * 11)
                                    text:    qsTr("Stop")
                                    onClicked: {
                                        for (var motorIndex=0; motorIndex<buttonRepeater.count; motorIndex++) {
                                            controller.vehicle.motorTest(motorIndex + 1, 0, 0, true)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.max(safetySwitch.implicitHeight, safetyStatus.contentHeight) + (ScreenTools.defaultFontPixelHeight * 0.8)
                        radius: popupStyle.cornerRadius
                        color: popupStyle.inputBackground
                        border.color: popupStyle.borderColor
                        border.width: 1

                        Row {
                            id: safetyRow
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.4
                            spacing: ScreenTools.defaultFontPixelWidth * 1.4

                            Switch {
                                id: safetySwitch
                                anchors.verticalCenter: parent.verticalCenter
                                width: ScreenTools.defaultFontPixelWidth * 7
                                height: ScreenTools.defaultFontPixelHeight * 1.5
                                hoverEnabled: !ScreenTools.isMobile

                                indicator: Rectangle {
                                    implicitWidth: ScreenTools.defaultFontPixelWidth * 7
                                    implicitHeight: ScreenTools.defaultFontPixelHeight * 1.5
                                    width: safetySwitch.width
                                    height: safetySwitch.height
                                    radius: height / 2
                                    color: safetySwitch.checked ? popupStyle.accentColor : popupStyle.inputBackground
                                    border.color: safetySwitch.checked ? popupStyle.accentColor : popupStyle.borderColor
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }
                                    Behavior on border.color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: popupStyle.hoverColor(parent.color)
                                        opacity: safetySwitch.hovered ? 0.18 : 0

                                        Behavior on opacity { NumberAnimation { duration: popupStyle.stateAnimationDuration } }
                                    }

                                    Rectangle {
                                        width: parent.height - 4
                                        height: width
                                        y: 2
                                        x: safetySwitch.checked ? parent.width - width - 2 : 2
                                        radius: width / 2
                                        color: safetySwitch.enabled ? popupStyle.primaryTextColor : popupStyle.disabledTextColor

                                        Behavior on x { NumberAnimation { duration: popupStyle.stateAnimationDuration } }
                                        Behavior on color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }
                                    }
                                }

                                contentItem: Item {
                                    implicitWidth: 0
                                    implicitHeight: 0
                                }

                                onClicked: {
                                    if (!checked) {
                                        sliderThrottle.setValue(0);
                                    }
                                }
                            }

                            QGCLabel {
                                id: safetyStatus
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - safetySwitch.width - parent.spacing - (ScreenTools.defaultFontPixelWidth * 0.5)
                                wrapMode: Text.WordWrap
                                color: safetySwitch.checked ? qgcPal.warningText : popupStyle.secondaryTextColor
                                text: safetySwitch.checked ? qsTr("Careful : Motors are enabled") : qsTr("Propellers are removed - Enable slider and motors")
                            }
                        }
                    }
                }
            }
        }
    } // Component
} // SetupPage
