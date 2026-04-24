import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

AnalyzePage {
    id:                 vibrationPage
    pageComponent:      pageComponent
    pageDescription:    qsTr("Analyze vibration associated with your vehicle.")
    allowPopout:        true

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle : QGroundControl.multiVehicleManager.offlineEditingVehicle
    property bool   _available:     !isNaN(_activeVehicle.vibration.xAxis.rawValue)
    property real   _margins:       ScreenTools.defaultFontPixelWidth / 2
    property real   _barWidth:      ScreenTools.defaultFontPixelWidth * 7
    property real   _barHeight:     ScreenTools.defaultFontPixelHeight * 10
    property real   _xValue:        _activeVehicle.vibration.xAxis.rawValue
    property real   _yValue:        _activeVehicle.vibration.yAxis.rawValue
    property real   _zValue:        _activeVehicle.vibration.zAxis.rawValue

    readonly property real _barMinimum:     0.0
    readonly property real _barMaximum:     90.0
    readonly property real _barBadValue:    60.0
    readonly property real _barMidValue:    30.0

    AnalyzePalette { id: analyzePalette }

    Component {
        id: pageComponent

        Item {
            width:  childrenRect.width
            height: childrenRect.height

            RowLayout {
                id:         barRow
                spacing:    ScreenTools.defaultFontPixelWidth * 2

                ColumnLayout {
                    Rectangle {
                        id:                 xBar
                        height:             _barHeight
                        width:              _barWidth
                        Layout.alignment:   Qt.AlignHCenter
                        color:              analyzePalette.inputSurface
                        radius:             analyzePalette.cornerRadius
                        border.width:       analyzePalette.borderWidth
                        border.color:       analyzePalette.border

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width:          parent.width
                            height:         parent.height * (Math.min(_barMaximum, _xValue) / (_barMaximum - _barMinimum))
                            color:          analyzePalette.textPrimary
                            radius:         analyzePalette.cornerRadius
                        }

                        // Max vibe indication line at 60
                        Rectangle {
                            anchors.topMargin:      parent.height * (1.0 - ((_barBadValue - _barMinimum) / (_barMaximum - _barMinimum)))
                            anchors.top:            parent.top
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            width:                  parent.width
                            height:                 1
                            color:                  analyzePalette.accent
                            opacity:                0.8
                        }

                        // Mid vibe indication line at 30
                        Rectangle {
                            anchors.topMargin:      parent.height * (1.0 - ((_barMidValue - _barMinimum) / (_barMaximum - _barMinimum)))
                            anchors.top:            parent.top
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            width:                  parent.width
                            height:                 1
                            color:                  analyzePalette.accent
                            opacity:                0.5
                        }
                    }

                    QGCLabel {
                        Layout.alignment:   Qt.AlignHCenter
                        text:               qsTr("X (%1)").arg(_xValue.toFixed(0))
                        color:              analyzePalette.textPrimary
                    }
                }

                ColumnLayout {
                    Rectangle {
                        height:             _barHeight
                        width:              _barWidth
                        Layout.alignment:   Qt.AlignHCenter
                        color:              analyzePalette.inputSurface
                        radius:             analyzePalette.cornerRadius
                        border.width:       analyzePalette.borderWidth
                        border.color:       analyzePalette.border

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width:          parent.width
                            height:         parent.height * (Math.min(_barMaximum, _yValue) / (_barMaximum - _barMinimum))
                            color:          analyzePalette.textPrimary
                            radius:         analyzePalette.cornerRadius
                        }

                        // Max vibe indication line at 60
                        Rectangle {
                            anchors.topMargin:      parent.height * (1.0 - ((_barBadValue - _barMinimum) / (_barMaximum - _barMinimum)))
                            anchors.top:            parent.top
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            width:                  parent.width
                            height:                 1
                            color:                  analyzePalette.accent
                            opacity:                0.8
                        }

                        // Mid vibe indication line at 30
                        Rectangle {
                            anchors.topMargin:      parent.height * (1.0 - ((_barMidValue - _barMinimum) / (_barMaximum - _barMinimum)))
                            anchors.top:            parent.top
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            width:                  parent.width
                            height:                 1
                            color:                  analyzePalette.accent
                            opacity:                0.5
                        }
                    }

                    QGCLabel {
                        Layout.alignment:   Qt.AlignHCenter
                        text:               qsTr("Y (%1)").arg(_yValue.toFixed(0))
                        color:              analyzePalette.textPrimary
                    }
                }

                ColumnLayout {
                    Rectangle {
                        height:             _barHeight
                        width:              _barWidth
                        Layout.alignment:   Qt.AlignHCenter
                        color:              analyzePalette.inputSurface
                        radius:             analyzePalette.cornerRadius
                        border.width:       analyzePalette.borderWidth
                        border.color:       analyzePalette.border

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width:          parent.width
                            height:         parent.height * (Math.min(_barMaximum, _zValue) / (_barMaximum - _barMinimum))
                            color:          analyzePalette.textPrimary
                            radius:         analyzePalette.cornerRadius
                        }

                        // Max vibe indication line at 60
                        Rectangle {
                            anchors.topMargin:      parent.height * (1.0 - ((_barBadValue - _barMinimum) / (_barMaximum - _barMinimum)))
                            anchors.top:            parent.top
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            width:                  parent.width
                            height:                 1
                            color:                  analyzePalette.accent
                            opacity:                0.8
                        }

                        // Mid vibe indication line at 30
                        Rectangle {
                            anchors.topMargin:      parent.height * (1.0 - ((_barMidValue - _barMinimum) / (_barMaximum - _barMinimum)))
                            anchors.top:            parent.top
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            width:                  parent.width
                            height:                 1
                            color:                  analyzePalette.accent
                            opacity:                0.5
                        }
                    }

                    QGCLabel {
                        Layout.alignment:   Qt.AlignHCenter
                        text:               qsTr("Z (%1)").arg(_zValue.toFixed(0))
                        color:              analyzePalette.textPrimary
                    }
                }
            }

            Column {
                anchors.margins:    ScreenTools.defaultFontPixelWidth
                anchors.left:       barRow.right

                QGCLabel {
                    text: qsTr("Clip count")
                    color: analyzePalette.textPrimary
                }

                QGCLabel {
                    text: qsTr("Accel 1: %1").arg(_activeVehicle.vibration.clipCount1.rawValue)
                    color: analyzePalette.textSecondary
                }

                QGCLabel {
                    text: qsTr("Accel 2: %1").arg(_activeVehicle.vibration.clipCount2.rawValue)
                    color: analyzePalette.textSecondary
                }

                QGCLabel {
                    text: qsTr("Accel 3: %1").arg(_activeVehicle.vibration.clipCount3.rawValue)
                    color: analyzePalette.textSecondary
                }
            }

            Rectangle {
                anchors.fill:   parent
                color:          analyzePalette.backgroundTop
                opacity:        0.75
                visible:        !_available

                QGCLabel {
                    anchors.fill:           parent
                    horizontalAlignment:    Text.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    text:                   qsTr("Not Available")
                    color:                  analyzePalette.textSecondary
                }
            }
        }
    }
}
