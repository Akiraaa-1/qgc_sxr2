import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id:     geoFenceEditorRect
    height: geoFenceItems.y + geoFenceItems.height + (_margin * 2)
    radius: theme.radius
    color:  theme.panelColor
    border.width: 1
    border.color: theme.borderColor

    property var    myGeoFenceController
    property var    flightMap

    readonly property real  _editFieldWidth:    Math.min(width - _margin * 2, ScreenTools.defaultFontPixelWidth * 15)
    readonly property real  _margin:            ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _radius:            ScreenTools.defaultFontPixelWidth / 2

    PlanEditorTheme { id: theme }

    QGCLabel {
        id:                 geoFenceLabel
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.top:        parent.top
        text:               qsTr("GeoFence")
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        color:              theme.textColor
    }

    Rectangle {
        id:                 geoFenceItems
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        geoFenceLabel.bottom
        height:             fenceColumn.y + fenceColumn.height + (_margin * 2)
        color:              theme.panelColor
        radius:             theme.radius
        border.width:       1
        border.color:       theme.borderColor

        Column {
            id:                 fenceColumn
            anchors.margins:    _margin
            anchors.top:        parent.top
            anchors.left:       parent.left
            anchors.right:      parent.right
            spacing:            _margin

            QGCLabel {
                anchors.left:       parent.left
                anchors.right:      parent.right
                wrapMode:           Text.WordWrap
                font.pointSize:     myGeoFenceController.supported ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize
                text:               myGeoFenceController.supported ?
                                        qsTr("GeoFencing allows you to set a virtual fence around the area you want to fly in.") :
                                        qsTr("This vehicle does not support GeoFence.")
                color:              theme.secondaryTextColor
            }

            Column {
                anchors.left:       parent.left
                anchors.right:      parent.right
                spacing:            _margin
                visible:            myGeoFenceController.supported

                Repeater {
                    model: myGeoFenceController.params

                    Item {
                        width:  fenceColumn.width
                        height: textField.height

                        property bool showCombo: modelData.enumStrings.length > 0

                        QGCLabel {
                            id:                 textFieldLabel
                            anchors.baseline:   textField.baseline
                            text:               myGeoFenceController.paramLabels[index]
                            color:              theme.secondaryTextColor
                        }

                        PlanFactTextField {
                            id:             textField
                            anchors.right:  parent.right
                            width:          _editFieldWidth
                            showUnits:      true
                            fact:           modelData
                            visible:        !parent.showCombo
                        }

                        PlanFactComboBox {
                            id:             comboField
                            anchors.right:  parent.right
                            width:          _editFieldWidth
                            indexModel:     false
                            fact:           showCombo ? modelData : _nullFact
                            visible:        parent.showCombo

                            property var _nullFact: Fact { }
                        }
                    }
                }

                PlanSectionHeader {
                    id:             insertSection
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("Insert GeoFence")
                }

                PlanButton {
                    Layout.fillWidth:   true
                    text:               qsTr("Polygon Fence")

                    onClicked: {
                        var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                        var topLeftCoord = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false /* clipToViewPort */)
                        var bottomRightCoord = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false /* clipToViewPort */)
                        myGeoFenceController.addInclusionPolygon(topLeftCoord, bottomRightCoord)
                    }
                }

                PlanButton {
                    Layout.fillWidth:   true
                    text:               qsTr("Circular Fence")

                    onClicked: {
                        var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                        var topLeftCoord = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false /* clipToViewPort */)
                        var bottomRightCoord = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false /* clipToViewPort */)
                        myGeoFenceController.addInclusionCircle(topLeftCoord, bottomRightCoord)
                    }
                }

                PlanSectionHeader {
                    id:             polygonSection
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("Polygon Fences")
                }

                QGCLabel {
                    text:       qsTr("None")
                    visible:    polygonSection.checked && myGeoFenceController.polygons.count === 0
                    color:      theme.secondaryTextColor
                }

                GridLayout {
                    Layout.fillWidth:   true
                    columns:            3
                    flow:               GridLayout.TopToBottom
                    visible:            polygonSection.checked && myGeoFenceController.polygons.count > 0

                    QGCLabel {
                        text:               qsTr("Inclusion")
                        Layout.column:      0
                        Layout.alignment:   Qt.AlignHCenter
                        color:              theme.secondaryTextColor
                    }

                    Repeater {
                        model: myGeoFenceController.polygons

                        PlanCheckBox {
                            checked:            object.inclusion
                            onClicked:          object.inclusion = checked
                            Layout.alignment:   Qt.AlignHCenter
                        }
                    }

                    QGCLabel {
                        text:               qsTr("Edit")
                        Layout.column:      1
                        Layout.alignment:   Qt.AlignHCenter
                        color:              theme.secondaryTextColor
                    }

                    Repeater {
                        model: myGeoFenceController.polygons

                        PlanRadioButton {
                            checked:            _interactive
                            Layout.alignment:   Qt.AlignHCenter

                            property bool _interactive: object.interactive

                            on_InteractiveChanged: checked = _interactive

                            onClicked: {
                                myGeoFenceController.clearAllInteractive()
                                object.interactive = checked
                            }
                        }
                    }

                    QGCLabel {
                        text:               qsTr("Delete")
                        Layout.column:      2
                        Layout.alignment:   Qt.AlignHCenter
                        color:              theme.secondaryTextColor
                    }

                    Repeater {
                        model: myGeoFenceController.polygons

                        PlanButton {
                            text:               qsTr("Del")
                            Layout.alignment:   Qt.AlignHCenter
                            onClicked:          myGeoFenceController.deletePolygon(index)
                        }
                    }
                } // GridLayout

                PlanSectionHeader {
                    id:             circleSection
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("Circular Fences")
                }

                QGCLabel {
                    text:       qsTr("None")
                    visible:    circleSection.checked && myGeoFenceController.circles.count === 0
                    color:      theme.secondaryTextColor
                }

                GridLayout {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    columns:            4
                    flow:               GridLayout.TopToBottom
                    visible:            polygonSection.checked && myGeoFenceController.circles.count > 0

                    QGCLabel {
                        text:               qsTr("Inclusion")
                        Layout.column:      0
                        Layout.alignment:   Qt.AlignHCenter
                        color:              theme.secondaryTextColor
                    }

                    Repeater {
                        model: myGeoFenceController.circles

                        PlanCheckBox {
                            checked:            object.inclusion
                            onClicked:          object.inclusion = checked
                            Layout.alignment:   Qt.AlignHCenter
                        }
                    }

                    QGCLabel {
                        text:               qsTr("Edit")
                        Layout.column:      1
                        Layout.alignment:   Qt.AlignHCenter
                        color:              theme.secondaryTextColor
                    }

                    Repeater {
                        model: myGeoFenceController.circles

                        PlanRadioButton {
                            checked:            _interactive
                            Layout.alignment:   Qt.AlignHCenter

                            property bool _interactive: object.interactive

                            on_InteractiveChanged: checked = _interactive

                            onClicked: {
                                myGeoFenceController.clearAllInteractive()
                                object.interactive = checked
                            }
                        }
                    }

                    QGCLabel {
                        text:               qsTr("Radius")
                        Layout.column:      2
                        Layout.alignment:   Qt.AlignHCenter
                        color:              theme.secondaryTextColor
                    }

                    Repeater {
                        model: myGeoFenceController.circles

                        PlanFactTextField {
                            fact:               object.radius
                            Layout.fillWidth:   true
                            Layout.alignment:   Qt.AlignHCenter
                        }
                    }

                    QGCLabel {
                        text:               qsTr("Delete")
                        Layout.column:      3
                        Layout.alignment:   Qt.AlignHCenter
                        color:              theme.secondaryTextColor
                    }

                    Repeater {
                        model: myGeoFenceController.circles

                        PlanButton {
                            text:               qsTr("Del")
                            Layout.alignment:   Qt.AlignHCenter
                            onClicked:          myGeoFenceController.deleteCircle(index)
                        }
                    }
                } // GridLayout

                PlanSectionHeader {
                    id:             breachReturnSection
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("Breach Return Point")
                }

                PlanButton {
                    text:               qsTr("Add Breach Return Point")
                    visible:            breachReturnSection.visible && !myGeoFenceController.breachReturnPoint.isValid
                    anchors.left:       parent.left
                    anchors.right:      parent.right

                    onClicked: myGeoFenceController.breachReturnPoint = flightMap.center
                }

                PlanButton {
                    text:               qsTr("Remove Breach Return Point")
                    visible:            breachReturnSection.visible && myGeoFenceController.breachReturnPoint.isValid
                    anchors.left:       parent.left
                    anchors.right:      parent.right

                    onClicked: myGeoFenceController.breachReturnPoint = QtPositioning.coordinate()
                }

                ColumnLayout {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    spacing:            _margin
                    visible:            breachReturnSection.visible && myGeoFenceController.breachReturnPoint.isValid

                    QGCLabel {
                        text: qsTr("Altitude")
                        color: theme.secondaryTextColor
                    }

                    PlanFactTextField {
                        fact: myGeoFenceController.breachReturnAltitude
                    }
                }

            }
        }
    }
}
