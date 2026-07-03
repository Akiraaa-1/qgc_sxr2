import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.VehicleSetup
import QGroundControl.FactControls

ColumnLayout {
    spacing: _margins

    required property var joystick

    readonly property var _joystickSettings: joystick.settings
    readonly property real _margins: ScreenTools.defaultFontPixelHeight / 2

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: _margins
        Layout.rightMargin: _margins
        spacing: _margins

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("Center stick is zero throttle")
            fact: _joystickSettings.throttleModeCenterZero
            visible: fact.userVisible
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("Center throttle smoothing")
            fact: _joystickSettings.throttleSmoothing
            visible: fact.userVisible && _joystickSettings.throttleModeCenterZero.rawValue
        }

        FactTextFieldSlider {
            Layout.fillWidth: true
            label: fact.shortDescription
            fact: _joystickSettings.exponentialPct
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("Negative thrust")
            fact: _joystickSettings.negativeThrust
            visible: globals.activeVehicle.supports.negativeThrust && fact.userVisible
        }

        QGCCheckBoxSlider {
            id: advancedSettingsCheckbox
            Layout.fillWidth: true
            text: qsTr("Advanced Settings")
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Advanced Settings")
        visible: advancedSettingsCheckbox.checked

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("Circle correction")
            fact: _joystickSettings.circleCorrection
            visible: fact.userVisible
        }

        FactTextFieldSlider {
            Layout.fillWidth: true
            label: fact.shortDescription
            fact: _joystickSettings.axisFrequencyHz
            visible: fact.userVisible
        }

        FactTextFieldSlider {
            Layout.fillWidth: true
            label: fact.shortDescription
            fact: _joystickSettings.buttonFrequencyHz
            visible: fact.userVisible
        }

        ColumnLayout {
            Layout.preferredWidth: parent.width
            spacing: 0
            visible: advancedSettingsCheckbox.checked

            FactCheckBoxSlider {
                text: qsTr("Deadbands")
                fact: _joystickSettings.useDeadband
                visible: fact.userVisible
            }

            QGCLabel{
                Layout.fillWidth: true
                font.pointSize: ScreenTools.smallFontPointSize
                wrapMode: Text.WordWrap
                text: qsTr("Deadbands can be set during the first step of calibration by lightly touching each axis.")
            }
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("MANUAL_CONTROL Pitch Extension")
            fact: _joystickSettings.enableManualControlPitchExtension
            visible: fact.userVisible
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("MANUAL_CONTROL Roll Extension")
            fact: _joystickSettings.enableManualControlRollExtension
            visible: fact.userVisible
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("MANUAL_CONTROL Auxiliary 1")
            fact: _joystickSettings.enableManualControlAux1
            visible: fact.userVisible
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("MANUAL_CONTROL Auxiliary 2")
            fact: _joystickSettings.enableManualControlAux2
            visible: fact.userVisible
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("MANUAL_CONTROL Auxiliary 3")
            fact: _joystickSettings.enableManualControlAux3
            visible: fact.userVisible
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("MANUAL_CONTROL Auxiliary 4")
            fact: _joystickSettings.enableManualControlAux4
            visible: fact.userVisible
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("MANUAL_CONTROL Auxiliary 5")
            fact: _joystickSettings.enableManualControlAux5
            visible: fact.userVisible
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("MANUAL_CONTROL Auxiliary 6")
            fact: _joystickSettings.enableManualControlAux6
            visible: fact.userVisible
        }
    }
}
