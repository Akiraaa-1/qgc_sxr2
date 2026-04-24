import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.PlanView

// Camera section for mission item editors
Column {
    required property var missionItem

    property alias buttonGroup: cameraSectionHeader.buttonGroup
    property alias showSpacer:  cameraSectionHeader.showSpacer
    property alias checked:     cameraSectionHeader.checked
    property bool showSectionHeader: true

    spacing: _margin

    property var    _camera:        missionItem.cameraSection
    property real   _fieldWidth:    ScreenTools.defaultFontPixelWidth * 16
    property real   _margin:        ScreenTools.defaultFontPixelWidth / 2

    PlanEditorTheme { id: theme }

    PlanSectionHeader {
        id:             cameraSectionHeader
        width:          parent.width
        text:           qsTr("Camera")
        checked:        false
        visible:        showSectionHeader
    }

    Column {
        width:      parent.width
        spacing:    _margin
        visible:    !showSectionHeader || cameraSectionHeader.checked

        PlanLabelledFactComboBox {
            id:         cameraActionCombo
            width:      parent.width
            label:      qsTr("Action")
            fact:       _camera.cameraAction
            indexModel: false
        }

        PlanLabelledFactTextField {
            width:      parent.width
            label:      qsTr("Time")
            fact:       _camera.cameraPhotoIntervalTime
            visible:    _camera.cameraAction.rawValue === 1
        }

        PlanLabelledFactTextField {
            width:      parent.width
            label:      qsTr("Distance")
            fact:       _camera.cameraPhotoIntervalDistance
            visible:    _camera.cameraAction.rawValue === 2
        }

        RowLayout {
            width:      parent.width
            spacing:    ScreenTools.defaultFontPixelWidth
            visible:    _camera.cameraModeSupported

            PlanCheckBox {
                id:                 modeCheckBox
                text:               qsTr("Mode")
                checked:            _camera.specifyCameraMode
                onClicked:          _camera.specifyCameraMode = checked
            }

            PlanFactComboBox {
                fact:               _camera.cameraMode
                indexModel:         false
                enabled:            modeCheckBox.checked
                Layout.fillWidth:   true
            }
        }

        PlanCheckBox {
            id:                 gimbalCheckBox
            text:               qsTr("Gimbal")
            checked:            _camera.specifyGimbal
            onClicked:          _camera.specifyGimbal = checked
        }

        PlanFactTextFieldSlider {
            width:          parent.width
            label:          qsTr("Pitch")
            fact:           _camera.gimbalPitch
            enabled:        gimbalCheckBox.checked
        }

        PlanFactTextFieldSlider {
            width:          parent.width
            label:          qsTr("Yaw")
            fact:           _camera.gimbalYaw
            enabled:        gimbalCheckBox.checked
        }
    }
}
