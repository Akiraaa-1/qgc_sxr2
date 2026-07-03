import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

/// Base view control for all Setup pages
Item {
    id:             setupView
    enabled:        !_disableDueToArmed && !_disableDueToFlying

    property alias  pageComponent:          pageLoader.sourceComponent
    property string pageName:               vehicleComponent ? vehicleComponent.name : ""
    property string pageDescription:        vehicleComponent ? vehicleComponent.description : ""
    property real   availableWidth:         centerPageLoader ? width : (width - pageLoader.x)
    property real   availableHeight:        height - pageLoader.y
    property bool   centerPageLoader:       false
    property bool   centerDescriptionText:  false
    property real   headerRightInset:       0
    property bool   showAdvanced:           false
    property alias  advanced:               advancedCheckBox.checked
    property string sectionNameFilter:       ""

    function sectionVisible(name) {
        if (pageLoader.item && typeof pageLoader.item.sectionVisible === "function") {
            return pageLoader.item.sectionVisible(name)
        }
        return true
    }

    onSectionNameFilterChanged: {
        if (pageLoader.item && typeof pageLoader.item.sectionNameFilter !== "undefined") {
            pageLoader.item.sectionNameFilter = sectionNameFilter
        }
    }

    property bool   _vehicleIsRover:        globals.activeVehicle ? globals.activeVehicle.rover : false
    property bool   _vehicleArmed:          globals.activeVehicle ? globals.activeVehicle.armed : false
    property bool   _vehicleFlying:         globals.activeVehicle ? globals.activeVehicle.flying : false
    property bool   _disableDueToArmed:     vehicleComponent ? (!vehicleComponent.allowSetupWhileArmed && _vehicleArmed) : false
    // FIXME: The _vehicleIsRover checkl is a hack to work around https://github.com/PX4/Firmware/issues/10969
    property bool   _disableDueToFlying:    vehicleComponent ? (!_vehicleIsRover && !vehicleComponent.allowSetupWhileFlying && _vehicleFlying) : false
    property string _disableReason:         _disableDueToArmed ? qsTr("armed") : qsTr("flying")
    property real   _margins:               ScreenTools.defaultFontPixelHeight * 0.5
    readonly property var _centeredDescriptions: [
        "Configure and calibrate gyroscope, accelerometer, magnetometer, and airspeed sensors.",
        qsTr("Configure and calibrate gyroscope, accelerometer, magnetometer, and airspeed sensors."),
        "Configure battery parameters, ESC calibration, and UAVCAN bus settings.",
        qsTr("Configure battery parameters, ESC calibration, and UAVCAN bus settings."),
        "Configure failsafe actions, geofence, return to launch, and land mode settings.",
        qsTr("Configure failsafe actions, geofence, return to launch, and land mode settings.")
    ]
    readonly property bool _centerPageDescription: false
    readonly property bool _shouldCenterDescription: centerDescriptionText
        || _centeredDescriptions.indexOf(pageDescription) !== -1

    Component.onCompleted: {
        if(pageLoader.item && pageLoader.item.setupPageCompleted) {
            pageLoader.item.setupPageCompleted()
        }
        if (pageLoader.item && typeof pageLoader.item.sectionNameFilter !== "undefined") {
            pageLoader.item.sectionNameFilter = sectionNameFilter
        }
    }

    QGCFlickable {
        anchors.fill:   parent
        contentWidth:   Math.max(availableWidth, pageLoader.x + pageLoader.item.width)
        contentHeight:  Math.max(availableHeight, pageLoader.y + pageLoader.item.height)
        clip:           true

        RowLayout {
            id:                 headingRow
            width:              Math.max(0, (setupView._shouldCenterDescription ? setupView.width : availableWidth) - setupView.headerRightInset)
            height:             visible ? implicitHeight : 0
            spacing:            _margins
            layoutDirection:    Qt.RightToLeft
            visible:            showAdvanced || (pageDescription !== "" && !ScreenTools.isShortScreen)

            QGCCheckBox {
                id:         advancedCheckBox
                text:       qsTr("Advanced")
                visible:    showAdvanced
            }

            ColumnLayout {
                spacing:            _margins
                Layout.fillWidth:   true

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    text:               pageDescription
                    horizontalAlignment: setupView._shouldCenterDescription ? Text.AlignHCenter : Text.AlignLeft
                    visible:            pageDescription !== "" && !ScreenTools.isShortScreen
                }

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    text:               qsTr("Disabled while the vehicle is %1").arg(_disableReason)
                    color:              qgcPal.warningText
                    visible:            !setupView.enabled && !ScreenTools.isShortScreen
                }
            }
        }

        Loader {
            id:                 pageLoader
            anchors.topMargin:  _margins
            anchors.top:        headingRow.bottom
            x:                  (setupView.centerPageLoader && pageLoader.item)
                                    ? Math.max(0, (setupView.width - pageLoader.item.width) / 2)
                                    : 0
        }

        // Overlay to display when vehicle is armed and this setup page needs
        // to be disabled
        Rectangle {
            visible:            !setupView.enabled
            anchors.fill:       parent
            color:              "black"
            opacity:            0.5
        }
    }
}
