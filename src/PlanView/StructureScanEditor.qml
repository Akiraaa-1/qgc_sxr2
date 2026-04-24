import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlightMap
import QGroundControl.PlanView

// Editor for Survery mission items
Rectangle {
    id:         _root
    height:     visible ? (editorColumn.height + (_margin * 2)) : 0
    width:      availableWidth
    color:      theme.panelColor
    radius:     theme.radius
    border.width: 1
    border.color: theme.borderColor

    required property var missionItem
    required property real availableWidth

    property real   _margin:                    ScreenTools.defaultFontPixelWidth / 2
    property real   _fieldWidth:                ScreenTools.defaultFontPixelWidth * 10.5
    property var    _vehicle:                   QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle : QGroundControl.multiVehicleManager.offlineEditingVehicle
    property real   _cameraMinTriggerInterval:  missionItem.cameraCalc.minTriggerInterval.rawValue

    PlanEditorTheme { id: theme }

    function polygonCaptureStarted() {
        missionItem.clearPolygon()
    }

    function polygonCaptureFinished(coordinates) {
        for (var i=0; i<coordinates.length; i++) {
            missionItem.addPolygonCoordinate(coordinates[i])
        }
    }

    function polygonAdjustVertex(vertexIndex, vertexCoordinate) {
        missionItem.adjustPolygonCoordinate(vertexIndex, vertexCoordinate)
    }

    function polygonAdjustStarted() { }
    function polygonAdjustFinished() { }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    ColumnLayout {
        id:                 editorColumn
        anchors.margins:    _margin
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right

        QGCLabel {
                id:                 wizardLabel
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                horizontalAlignment:    Text.AlignHCenter
                text:               qsTr("Use the Polygon Tools to create the polygon which outlines the structure.")
                visible:        !missionItem.structurePolygon.isValid || missionItem.wizardMode
                color:          theme.secondaryTextColor
            }

        ColumnLayout {
            Layout.fillWidth:   true
            spacing:        _margin
            visible:        !wizardLabel.visible

            QGCTabBar {
                id:             tabBar
                Layout.fillWidth:   true

                Component.onCompleted: currentIndex = 0

                PlanTabButton { text: qsTr("Grid") }
                PlanTabButton { text: qsTr("Camera") }
            }

            ColumnLayout {
                Layout.fillWidth:   true
                spacing:            _margin
                visible:            tabBar.currentIndex == 0

                QGCLabel {
                    Layout.fillWidth:   true
                    text:           qsTr("Note: Polygon respresents structure surface not vehicle flight path.")
                    wrapMode:       Text.WordWrap
                    font.pointSize: ScreenTools.smallFontPointSize
                    color:          theme.secondaryTextColor
                }

                QGCLabel {
                    Layout.fillWidth:   true
                    text:           qsTr("WARNING: Photo interval is below minimum interval (%1 secs) supported by camera.").arg(_cameraMinTriggerInterval.toFixed(1))
                    wrapMode:       Text.WordWrap
                    color:          qgcPal.warningText
                    visible:        missionItem.cameraShots > 0 && _cameraMinTriggerInterval !== 0 && _cameraMinTriggerInterval > missionItem.timeBetweenShots
                }

                CameraCalcGrid {
                    Layout.fillWidth:   true
                    cameraCalc:                     missionItem.cameraCalc
                    vehicleFlightIsFrontal:         false
                    distanceToSurfaceLabel:         qsTr("Scan Distance")
                    frontalDistanceLabel:           qsTr("Layer Height")
                    sideDistanceLabel:              qsTr("Trigger Distance")
                }

                PlanSectionHeader {
                    id:             scanHeader
                    Layout.fillWidth:   true
                    text:           qsTr("Scan")
                }

                ColumnLayout {
                    Layout.fillWidth:   true
                    spacing:        _margin
                    visible:        scanHeader.checked

                    GridLayout {
                        Layout.fillWidth:   true
                        columnSpacing:  _margin
                        rowSpacing:     _margin
                        columns:        2

                        PlanFactComboBox {
                            fact:               missionItem.startFromTop
                            indexModel:         true
                            model:              [ qsTr("Start Scan From Bottom"), qsTr("Start Scan From Top") ]
                            Layout.columnSpan:  2
                            Layout.fillWidth:   true
                        }

                        QGCLabel {
                            text:       qsTr("Structure Height")
                            color:      theme.secondaryTextColor
                        }
                        PlanFactTextField {
                            fact:               missionItem.structureHeight
                            Layout.fillWidth:   true
                        }

                        QGCLabel { text: qsTr("Scan Bottom Alt"); color: theme.secondaryTextColor }
                        PlanAltitudeFactTextField {
                            fact:               missionItem.scanBottomAlt
                            altitudeFrame:       QGroundControl.AltitudeFrameRelative
                            Layout.fillWidth:   true
                        }

                        QGCLabel { text: qsTr("Entrance/Exit Alt"); color: theme.secondaryTextColor }
                        PlanAltitudeFactTextField {
                            fact:               missionItem.entranceAlt
                            altitudeFrame:       QGroundControl.AltitudeFrameRelative
                            Layout.fillWidth:   true
                        }

                        QGCLabel {
                            text:       qsTr("Gimbal Pitch")
                            visible:    missionItem.cameraCalc.isManualCamera
                            color:      theme.secondaryTextColor
                        }
                        PlanFactTextField {
                            fact:               missionItem.gimbalPitch
                            Layout.fillWidth:   true
                            visible:            missionItem.cameraCalc.isManualCamera
                        }
                    }

                    Item {
                        height: ScreenTools.defaultFontPixelHeight / 2
                        width:  1
                    }

                    PlanButton {
                        text:       qsTr("Rotate entry point")
                        onClicked:  missionItem.rotateEntryPoint()
                    }
                } // Column - Scan

                PlanSectionHeader {
                    id:             statsHeader
                    Layout.fillWidth:   true
                    text:           qsTr("Statistics")
                }

                Grid {
                    columns:        2
                    columnSpacing:  ScreenTools.defaultFontPixelWidth
                    visible:        statsHeader.checked

                    QGCLabel { text: qsTr("Layers"); color: theme.secondaryTextColor }
                    QGCLabel { text: missionItem.layers.valueString; color: theme.textColor }

                    QGCLabel { text: qsTr("Layer Height"); color: theme.secondaryTextColor }
                    QGCLabel { text: missionItem.cameraCalc.adjustedFootprintFrontal.valueString + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString; color: theme.textColor }

                    QGCLabel { text: qsTr("Top Layer Alt"); color: theme.secondaryTextColor }
                    QGCLabel { text: QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(missionItem.topFlightAlt).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString; color: theme.textColor }

                    QGCLabel { text: qsTr("Bottom Layer Alt"); color: theme.secondaryTextColor }
                    QGCLabel { text: QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(missionItem.bottomFlightAlt).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString; color: theme.textColor }

                    QGCLabel { text: qsTr("Photo Count"); color: theme.secondaryTextColor }
                    QGCLabel { text: missionItem.cameraShots; color: theme.textColor }

                    QGCLabel { text: qsTr("Photo Interval"); color: theme.secondaryTextColor }
                    QGCLabel { text: missionItem.timeBetweenShots.toFixed(1) + " " + qsTr("secs"); color: theme.textColor }

                    QGCLabel { text: qsTr("Trigger Distance"); color: theme.secondaryTextColor }
                    QGCLabel { text: missionItem.cameraCalc.adjustedFootprintSide.valueString + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString; color: theme.textColor }
                }
            } // Grid Column

            ColumnLayout {
                Layout.fillWidth:   true
                spacing:            _margin
                visible:            tabBar.currentIndex == 1

                CameraCalcCamera {
                    Layout.fillWidth:   true
                    cameraCalc: missionItem.cameraCalc
                }
            }
        }
    }
}
