import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.PlanView

ColumnLayout {
    spacing: _margin
    visible: tabBar.currentIndex === 2

    property var missionItem

    PlanEditorTheme { id: theme }

    MouseArea {
        Layout.preferredWidth:  childrenRect.width
        Layout.preferredHeight: childrenRect.height

        onClicked: {
            var removeModes = []
            var updateFunction = function(altFrame){ missionItem.cameraCalc.distanceMode = altFrame }
            removeModes.push(QGroundControl.AltitudeFrameMixed)
            if (!missionItem.masterController.controllerVehicle.supports.terrainFrame) {
                removeModes.push(QGroundControl.AltitudeFrameTerrain)
            }
            if (!QGroundControl.corePlugin.options.showMissionAbsoluteAltitude || !missionItem.cameraCalc.isManualCamera) {
                removeModes.push(QGroundControl.AltitudeFrameAbsolute)
            }
            altFrameDialogFactory.open({ currentAltFrame: missionItem.cameraCalc.distanceMode, rgRemoveModes: removeModes, updateAltFrameFn: updateFunction })
        }

        QGCPopupDialogFactory {
            id: altFrameDialogFactory

            dialogComponent: altFrameDialogComponent
        }

        Component { id: altFrameDialogComponent; AltFrameDialog { } }

        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth / 2

            QGCLabel {
                text:   QGroundControl.altitudeFrameShortDescription(missionItem.cameraCalc.distanceMode)
                color:  theme.textColor
            }
            QGCColoredImage {
                height:     ScreenTools.defaultFontPixelHeight / 2
                width:      height
                source:     "/res/DropArrow.svg"
                color:      theme.secondaryTextColor
            }
        }
    }

    GridLayout {
        Layout.fillWidth:   true
        columnSpacing:      _margin
        rowSpacing:         _margin
        columns:            2
        enabled:            missionItem.cameraCalc.distanceMode === QGroundControl.AltitudeFrameCalcAboveTerrain

        QGCLabel { text: qsTr("Tolerance"); color: theme.secondaryTextColor }
        PlanFactTextField {
            fact:               missionItem.terrainAdjustTolerance
            Layout.fillWidth:   true
        }

        QGCLabel { text: qsTr("Max Climb Rate"); color: theme.secondaryTextColor }
        PlanFactTextField {
            fact:               missionItem.terrainAdjustMaxClimbRate
            Layout.fillWidth:   true
        }

        QGCLabel { text: qsTr("Max Descent Rate"); color: theme.secondaryTextColor }
        PlanFactTextField {
            fact:               missionItem.terrainAdjustMaxDescentRate
            Layout.fillWidth:   true
        }
    }
}
