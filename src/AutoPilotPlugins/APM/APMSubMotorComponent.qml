import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

SetupPage {
    id:             motorPage
    pageComponent:  pageComponent
    enabled:        true

    readonly property int _barHeight:       10
    readonly property int _barWidth:        5
    readonly property int _sliderHeight:    10

    property int neutralValue: 50;
    property int _lastIndex: 0;
    property bool canRunManualTest: controller.vehicle.flightMode !== controller.vehicle.motorDetectionFlightMode && controller.vehicle.armed && motorPage.visible && setupView.visible
    property var shouldRunManualTest: false // Does the operator intend to run the motor test?

    APMSubMotorComponentController {
        id:             controller
    }

    function setMotorDirection(num, reversed) {
        var fact = controller.getParameterFact(-1, "MOT_" + num + "_DIRECTION")
        fact.value = reversed ? -1 : 1;
    }

    Component.onCompleted: controller.vehicle.armed = false

    Component {
        id: pageComponent

        Column {
            spacing: 10

            Row {
                id:         motorSliders
                enabled:    canRunManualTest && shouldRunManualTest
                spacing:    ScreenTools.defaultFontPixelWidth * 4

                Column {
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    Row {
                        id: sliderRow
                        spacing:    ScreenTools.defaultFontPixelWidth * 4

                        Repeater {
                            id:         sliderRepeater
                            model:      controller.vehicle.motorCount == -1 ? 8 : controller.vehicle.motorCount

                            Column {
                                property alias motorSlider: slider
                                spacing:    ScreenTools.defaultFontPixelWidth

                                QGCLabel {
                                    anchors.horizontalCenter:   parent.horizontalCenter
                                    text:                       index + 1
                                }

                                QGCSlider {
                                    id:                         slider
                                    height:                     ScreenTools.defaultFontPixelHeight * _sliderHeight
                                    orientation:                Qt.Vertical
                                    to:               100
                                    value:                      neutralValue

                                    // Give slider 'center sprung' behavior
                                    onPressedChanged: {
                                        if (!slider.pressed) {
                                            slider.value = neutralValue
                                        }
                                        _lastIndex = index
                                    }
                                    // Disable mouse scroll
                                    MouseArea {
                                        anchors.fill: parent
                                        onWheel: (wheel) => {
                                            // do nothing
                                            wheel.accepted = true;
                                        }
                                        onPressed: (mouse) => {
                                            // propogate/accept
                                            mouse.accepted = false;
                                        }
                                        onReleased: (mouse) => {
                                            // propogate/accept
                                            mouse.accepted = false;
                                        }
                                    }
                                }
                            } // Column
                        } // Repeater
                    } // Row

                    QGCLabel {
                        width: parent.width
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        wrapMode:       Text.WordWrap
                        text:           qsTr("Reverse Motor Direction")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }
                    Rectangle {
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 3
                        width:              parent.width
                        height:             1
                        color:              qgcPal.text
                    }

                    Row {
                        anchors.margins: ScreenTools.defaultFontPixelWidth

                        Repeater {
                            id:         cbRepeater
                            model:      controller.vehicle.motorCount == -1 ? 8 : controller.vehicle.motorCount

                            Column {
                                spacing:    ScreenTools.defaultFontPixelWidth

                                QGCCheckBox {
                                    width: sliderRow.width / (controller.vehicle.motorCount - 0.5)
                                    checked: controller.getParameterFact(-1, "MOT_" + (index + 1) + "_DIRECTION").value == -1
                                    onClicked: {
                                        sliderRepeater.itemAt(index).motorSlider.value = neutralValue
                                        setMotorDirection(index + 1, checked)
                                    }
                                }
                            } // Column
                        } // Repeater
                    } // Row
                } // Column

                // Display the frame currently in use with motor numbers
                APMSubMotorDisplay {
                    anchors.top:    parent.top
                    anchors.bottom: parent.bottom
                    width:          height
                    frameType: controller.getParameterFact(-1, "FRAME_CONFIG").value
                }
            } // Row

            QGCLabel {
                anchors.left:   parent.left
                anchors.right:  parent.right
                wrapMode:       Text.WordWrap
                text:           qsTr("移动滑块会让电机转动。请确保电机和螺旋桨周围没有障碍物！电机旋转方向取决于电机三相与 ESC 的实际接线方式（如果任意两根线互换，旋转方向也会翻转）。由于无法保证三相接线顺序，电机方向必须在软件中配置。当滑块向下移动时，推进器应将空气/水朝着线缆进入壳体的方向推动。勾选复选框可反转对应推进器的方向。\n\n"
                                     + "Blue Robotics 推进器依靠水润滑，不适合在空气中长时间运行。低速、短时在空气中测试是可以的，但长时间运行可能导致过热和永久损坏。由于没有水润滑，在空气中运行时也可能会出现一些不太悦耳的声音，这属于正常现象。")
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth
                Switch {
                    id: safetySwitch
                    onToggled: {
                        if (controller.vehicle.armed) {
                            shouldRunManualTest = false
                            enabled = false
                            coolDownTimer.start()
                        }

                        controller.vehicle.armed = checked
                        checked = controller.vehicle.armed // Makes the switch stay off if it's not possible to arm
                    }
                }

                // Make sure external changes to Armed are reflected on the switch
                Connections {
                    target: controller.vehicle
                    onArmedChanged:
                    {
                        safetySwitch.checked = armed
                            if (!armed) {
                                shouldRunManualTest = false
                                safetySwitch.enabled = false
                                coolDownTimer.start()
                            } else {
                                shouldRunManualTest = true
                            }
                            for (var sliderIndex=0; sliderIndex<sliderRepeater.count; sliderIndex++) {
                                sliderRepeater.itemAt(sliderIndex).motorSlider.value = neutralValue
                            }
                        }
                }

                QGCLabel {
                    anchors.verticalCenter: safetySwitch.verticalCenter
                    color:  qgcPal.warningText
                    text:   coolDownTimer.running
                                ? qsTr("A 10 second coooldown is required before testing again, please stand by...")
                                : qsTr("滑动此开关可解锁飞行器并启用电机测试（注意！）")
                }
            } // Row

            QGCLabel {
                visible:             controller.vehicle.versionCompare(4, 0, 0) >= 0
                width:               parent.width
                anchors.left:        parent.left
                anchors.right:       parent.right
                font.pointSize:      ScreenTools.largeFontPointSize
                text:                qsTr("Automatic Motor Direction Detection")
            }

            QGCLabel {
                visible:        controller.vehicle.versionCompare(4, 0, 0) >= 0
                anchors.left:   parent.left
                anchors.right:  parent.right
                wrapMode:       Text.WordWrap
                text:           qsTr("This will attempt to automatically detect the direction (normal/reversed) of your thrusters.\n"
                                   + "Please place your vehicle in water, click the button, and wait. Note that the thrusters still need "
                                   + "to be connected to the correct outputs (thrusters 2 and 3 can't be swapped, for example).")
            }

            Row {
                visible:    controller.vehicle.versionCompare(4, 0, 0) >= 0
                spacing:    ScreenTools.defaultFontPixelWidth

                Column {
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    QGCButton {
                        id: startAutoDetection
                        text: "Auto-Detect Directions"
                        enabled: controller.vehicle.flightMode !== controller.vehicle.motorDetectionFlightMode

                        onClicked: function() {
                            controller.vehicle.flightMode = controller.vehicle.motorDetectionFlightMode
                            controller.vehicle.armed = true
                        }
                    }
                }
                Column {
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    Flickable {
                        id: flickable
                        width: 500
                        height: Math.min(contentHeight, 200)
                        contentWidth: width
                        contentHeight: textArea.implicitHeight
                        clip: true

                        TextArea {
                            id: textArea
                            anchors.fill: parent
                            color:  qgcPal.text
                            text: controller.motorDetectionMessages
                            wrapMode: Text.WordWrap
                            background: Rectangle {
                                color: qgcPal.window
                            }
                            onTextChanged: function() {
                                flickable.flick(0, -300)
                            }
                        }
                        ScrollBar.vertical: ScrollBar {}
                    }
                }
            }

            // Repeats the command signal and updates the checkbox every 50 ms
            Timer {
                id: timer
                interval:       50
                repeat:         true
                running:        canRunManualTest && shouldRunManualTest

                onTriggered: {
                    if (controller.vehicle.armed) {
                            var slider = sliderRepeater.itemAt(_lastIndex)

                            var reversed = controller.getParameterFact(-1, "MOT_" + (_lastIndex + 1) + "_DIRECTION").value == -1

                            if (reversed) {
                                controller.vehicle.motorTest(_lastIndex, 100 - slider.motorSlider.value, 0, false)
                            } else {
                                controller.vehicle.motorTest(_lastIndex, slider.motorSlider.value, 0, false)
                            }
                    }
                }
            }
            Timer {
                id: coolDownTimer
                interval:       11000
                repeat:         false

                onTriggered: {
                    safetySwitch.enabled = true
                }
            }
        } // Column
    } // Component
} // SetupPage
