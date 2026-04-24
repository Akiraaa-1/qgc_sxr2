import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id: _root

    required property var missionController

    width:  parent ? parent.width : 0
    height: mainColumn.height + (_margins * 2)
    color:  theme.panelColor
    radius: theme.radius
    border.width: 1
    border.color: theme.borderColor

    property real _margins:        ScreenTools.defaultFontPixelWidth / 2
    property real _textFieldWidth: ScreenTools.defaultFontPixelWidth * 20
    property real _labelWidth:     ScreenTools.defaultFontPixelWidth * 14
    property bool _hasHome:        missionController ? missionController.plannedHomePosition.isValid : false

    PlanEditorTheme { id: theme }

    TransformPositionController {
        id: positionController
        Component.onCompleted: {
            if (_hasHome) {
                coordinate = _root.missionController.plannedHomePosition
                initValues()
            }
        }
    }

    Connections {
        target: _root.missionController
        function onPlannedHomePositionChanged() {
            positionController.coordinate = _root.missionController.plannedHomePosition
            positionController.initValues()
        }
    }

    ColumnLayout {
        id:              mainColumn
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.top:     parent.top
        anchors.margins: _margins
        spacing:         ScreenTools.defaultFontPixelHeight * 0.5

        // ── Offset Mission ──
        PlanSectionHeader {
            id:               offsetSection
            Layout.fillWidth: true
            text:             qsTr("Offset Mission")
            checked:          false
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing:          _margins
            visible:          offsetSection.checked

            PlanLabelledFactTextField {
                id:                      eastField
                label:                   qsTr("East")
                fact:                    positionController.offsetEast
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
            }

            PlanLabelledFactTextField {
                id:                      northField
                label:                   qsTr("North")
                fact:                    positionController.offsetNorth
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
            }

            PlanLabelledFactTextField {
                id:                      upField
                label:                   qsTr("Up")
                fact:                    positionController.offsetUp
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
            }

            PlanCheckBox {
                id:   offsetTakeoffCheck
                text: qsTr("Also move takeoff items")
            }

            PlanCheckBox {
                id:   offsetLandingCheck
                text: qsTr("Also move landing items")
            }

            QGCLabel {
                Layout.fillWidth:    true
                Layout.maximumWidth: _labelWidth + _textFieldWidth
                wrapMode:            Text.WordWrap
                font.pointSize:      ScreenTools.smallFontPointSize
                text:                qsTr("Note: Home altitude is not modified.")
                color:               theme.secondaryTextColor
            }

            PlanButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Apply Offset")
                enabled:          !eastField.textField.validationError
                                  && !northField.textField.validationError
                                  && !upField.textField.validationError

                onClicked: {
                    _root.missionController.offsetMission(
                        positionController.offsetEast.rawValue,
                        positionController.offsetNorth.rawValue,
                        positionController.offsetUp.rawValue,
                        offsetTakeoffCheck.checked,
                        offsetLandingCheck.checked
                    )
                }
            }
        }

        // ── Reposition Mission ──
        PlanSectionHeader {
            id:               repositionSection
            Layout.fillWidth: true
            text:             qsTr("Reposition Mission")
            checked:          false
        }

        ColumnLayout {
            id:               repositionContent
            Layout.fillWidth: true
            spacing:          _margins
            visible:          repositionSection.checked

            QGCLabel {
                Layout.fillWidth: true
                wrapMode:         Text.WordWrap
                font.pointSize:   ScreenTools.smallFontPointSize
                text:             qsTr("Home position must be set to reposition the mission.")
                visible:          !_hasHome
                color:            theme.secondaryTextColor
            }

            property bool _showGeographic: coordinateSystemCombo.currentIndex === 0
            property bool _showUTM:        coordinateSystemCombo.currentIndex === 1
            property bool _showMGRS:       coordinateSystemCombo.currentIndex === 2
            property bool _showVehicle:    coordinateSystemCombo.currentIndex === 3

            ColumnLayout {
                Layout.fillWidth: true
                spacing:          0

                QGCLabel {
                    text: qsTr("Coordinate System")
                    color: theme.secondaryTextColor
                }

                PlanComboBox {
                    id:               coordinateSystemCombo
                    Layout.fillWidth: true
                    model:            globals.activeVehicle
                                      ? [ qsTr("Geographic"), qsTr("Universal Transverse Mercator"), qsTr("Military Grid Reference"), qsTr("Vehicle Position") ]
                                      : [ qsTr("Geographic"), qsTr("Universal Transverse Mercator"), qsTr("Military Grid Reference") ]
                }
            }

            PlanLabelledFactTextField {
                id:                      latitudeField
                label:                   qsTr("Latitude")
                fact:                    positionController.latitude
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showGeographic
            }

            PlanLabelledFactTextField {
                id:                      longitudeField
                label:                   qsTr("Longitude")
                fact:                    positionController.longitude
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showGeographic
            }

            PlanButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Move to Position")
                enabled:          _hasHome && !latitudeField.textField.validationError && !longitudeField.textField.validationError
                visible:          repositionContent._showGeographic
                onClicked: {
                    positionController.setFromGeo()
                    _root.missionController.repositionMission(positionController.coordinate)
                }
            }

            PlanLabelledFactTextField {
                id:                      zoneField
                label:                   qsTr("Zone")
                fact:                    positionController.zone
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showUTM
            }

            PlanLabelledFactComboBox {
                label:            qsTr("Hemisphere")
                fact:             positionController.hemisphere
                indexModel:       false
                Layout.fillWidth: true
                visible:          repositionContent._showUTM
            }

            PlanLabelledFactTextField {
                id:                      eastingField
                label:                   qsTr("Easting")
                fact:                    positionController.easting
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showUTM
            }

            PlanLabelledFactTextField {
                id:                      northingField
                label:                   qsTr("Northing")
                fact:                    positionController.northing
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showUTM
            }

            PlanButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Move to Position")
                enabled:          _hasHome && !zoneField.textField.validationError && !eastingField.textField.validationError && !northingField.textField.validationError
                visible:          repositionContent._showUTM
                onClicked: {
                    positionController.setFromUTM()
                    _root.missionController.repositionMission(positionController.coordinate)
                }
            }

            PlanLabelledFactTextField {
                id:                      mgrsField
                label:                   qsTr("MGRS")
                fact:                    positionController.mgrs
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
                visible:                 repositionContent._showMGRS
            }

            PlanButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Move to Position")
                enabled:          _hasHome && !mgrsField.textField.validationError
                visible:          repositionContent._showMGRS
                onClicked: {
                    positionController.setFromMGRS()
                    _root.missionController.repositionMission(positionController.coordinate)
                }
            }

            PlanButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Move to Vehicle Position")
                enabled:          _hasHome
                visible:          repositionContent._showVehicle
                onClicked: {
                    positionController.setFromVehicle()
                    _root.missionController.repositionMission(positionController.coordinate)
                }
            }
        }

        // ── Rotate Mission ──
        PlanSectionHeader {
            id:               rotateSection
            Layout.fillWidth: true
            text:             qsTr("Rotate Mission")
            checked:          false
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing:          _margins
            visible:          rotateSection.checked

            QGCLabel {
                Layout.fillWidth: true
                wrapMode:         Text.WordWrap
                font.pointSize:   ScreenTools.smallFontPointSize
                text:             qsTr("Home position must be set to rotate the mission.")
                visible:          !_hasHome
            }

            PlanLabelledFactTextField {
                id:                      degreesCWField
                label:                   qsTr("Clockwise")
                fact:                    positionController.rotateDegreesCW
                textFieldPreferredWidth: _textFieldWidth
                Layout.fillWidth:        true
            }

            PlanCheckBox {
                id:   rotateTakeoffCheck
                text: qsTr("Also move takeoff items")
            }

            PlanCheckBox {
                id:   rotateLandingCheck
                text: qsTr("Also move landing items")
            }

            QGCLabel {
                Layout.fillWidth:    true
                Layout.maximumWidth: _labelWidth + _textFieldWidth
                wrapMode:            Text.WordWrap
                font.pointSize:      ScreenTools.smallFontPointSize
                text:                qsTr("Note: Complex items are rotated by moving their reference coordinate: their geometry and orientation are not changed.")
            }

            PlanButton {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("Apply Rotation")
                enabled:          _hasHome && !degreesCWField.textField.validationError

                onClicked: {
                    _root.missionController.rotateMission(
                        positionController.rotateDegreesCW.rawValue,
                        rotateTakeoffCheck.checked,
                        rotateLandingCheck.checked
                    )
                }
            }
        }
    }
}
