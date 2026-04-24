import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

// Statistics section for TransectStyleComplexItems
Grid {
    // The following properties must be available up the hierarchy chain
    //property var    missionItem       ///< Mission Item for editor

    columns:        2
    columnSpacing:  ScreenTools.defaultFontPixelWidth

    PlanEditorTheme { id: theme }

    QGCLabel { text: qsTr("Survey Area"); color: theme.secondaryTextColor }
    QGCLabel { text: QGroundControl.unitsConversion.squareMetersToAppSettingsAreaUnits(missionItem.coveredArea).toFixed(2) + " " + QGroundControl.unitsConversion.appSettingsAreaUnitsString; color: theme.textColor }

    QGCLabel { text: qsTr("Photo Count"); color: theme.secondaryTextColor }
    QGCLabel { text: missionItem.cameraShots; color: theme.textColor }

    QGCLabel { text: qsTr("Photo Interval"); color: theme.secondaryTextColor }
    QGCLabel { text: missionItem.timeBetweenShots.toFixed(1) + " " + qsTr("secs"); color: theme.textColor }

    QGCLabel { text: qsTr("Trigger Distance"); color: theme.secondaryTextColor }
    QGCLabel { text: missionItem.cameraCalc.adjustedFootprintFrontal.valueString + " " + missionItem.cameraCalc.adjustedFootprintFrontal.units; color: theme.textColor }
}
