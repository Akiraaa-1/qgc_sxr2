import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    required property var planMasterController

    id: missionStats
    implicitWidth: Math.max(contentFlickable.contentWidth, mainLayout.implicitWidth + (_margins * 2))
    implicitHeight: Math.max(mainLayout.implicitHeight + (_margins * 2), ScreenTools.defaultFontPixelHeight * 8)
    color: "#AA1F1F1F"
    border.width: 1
    border.color: "#333333"
    radius: 8
    clip: true

    property var _planMasterController: planMasterController
    property color _windowColor: QGroundControl.globalPalette.window
    property var _currentMissionItem: _planMasterController.missionController.currentPlanViewItem ///< Mission item to display status for

    property var missionItems: _controllerValid ? _planMasterController.missionController.visualItems : undefined
    property real missionPlannedDistance: _controllerValid ? _planMasterController.missionController.missionPlannedDistance : NaN
    property real missionTime: _controllerValid ? _planMasterController.missionController.missionTime : 0
    property real missionMaxTelemetry: _controllerValid ? _planMasterController.missionController.missionMaxTelemetry : NaN
    property real missionBatteryPercentRemaining: _controllerValid ? _planMasterController.missionController.missionBatteryPercentRemaining : -1
    property bool _controllerValid: _planMasterController !== undefined && _planMasterController !== null

    property bool _currentMissionItemValid: _currentMissionItem && _currentMissionItem !== undefined && _currentMissionItem !== null
    property bool _currentItemIsVTOLTakeoff: _currentMissionItemValid && _currentMissionItem.command == 84
    property bool _missionValid: missionItems !== undefined

    property real _dataFontSize: ScreenTools.defaultFontPointSize
    property real _largeValueWidth: ScreenTools.defaultFontPixelWidth * 8
    property real _mediumValueWidth: ScreenTools.defaultFontPixelWidth * 4
    property real _smallValueWidth: ScreenTools.defaultFontPixelWidth * 3
    property real _labelToValueSpacing: ScreenTools.defaultFontPixelWidth
    property real _rowSpacing: ScreenTools.isMobile ? 2 : 1
    property real _distance: _currentMissionItemValid ? _currentMissionItem.distance : NaN
    property real _altDifference: _currentMissionItemValid ? _currentMissionItem.altDifference : NaN
    property real _azimuth: _currentMissionItemValid ? _currentMissionItem.azimuth : NaN
    property real _heading: _currentMissionItemValid ? _currentMissionItem.missionVehicleYaw : NaN
    property real _missionPlannedDistance: _missionValid ? missionPlannedDistance : NaN
    property real _missionMaxTelemetry: _missionValid ? missionMaxTelemetry : NaN
    property real _missionBatteryPercentRemaining: _missionValid ? missionBatteryPercentRemaining : -1
    property real _missionTime: _missionValid ? missionTime : 0
    property real _maxSegmentDistance: _missionValid ? _calculateMaxSegmentDistance(_missionPlannedDistance) : NaN
    property int _batteryChangePoint: _controllerValid ? _planMasterController.missionController.batteryChangePoint : -1
    property int _batteriesRequired: _controllerValid ? _planMasterController.missionController.batteriesRequired : -1
    property bool _batteryInfoAvailable: _batteryChangePoint >= 0 || _batteriesRequired >= 0
    property real _gradient: _currentMissionItemValid && _currentMissionItem.distance > 0 ?
                                                    (_currentItemIsVTOLTakeoff ?
                                                         0 : (Math.atan(_currentMissionItem.altDifference / _currentMissionItem.distance) * (180.0/Math.PI)))
                                                  : NaN

    property string _distanceText: isNaN(_distance) ? "-.-" : QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(_distance).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
    property string _altDifferenceText: isNaN(_altDifference) ? "-.-" : QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(_altDifference).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsString
    property string _gradientText: isNaN(_gradient) ? "-.-" : _gradient.toFixed(0) + qsTr(" deg")
    property string _azimuthText: isNaN(_azimuth) ? "-.-" : Math.round(_azimuth) % 360
    property string _headingText: isNaN(_azimuth) ? "-.-" : Math.round(_heading) % 360
    property string _missionPlannedDistanceText: isNaN(_missionPlannedDistance) ? "-.-" : QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(_missionPlannedDistance).toFixed(0) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
    property string _missionMaxTelemetryText: isNaN(_missionMaxTelemetry) ? "-.-" : QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(_missionMaxTelemetry).toFixed(0) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
    property string _missionBatteryPercentRemainingText: _missionBatteryPercentRemaining < 0 ? qsTr("N/A") : _missionBatteryPercentRemaining.toFixed(0) + "%"
    property string _maxSegmentDistanceText: isNaN(_maxSegmentDistance) ? "-.-" : QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(_maxSegmentDistance).toFixed(0) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
    property int _communicationRiskLevel: _calculateCommunicationRiskLevel(_missionMaxTelemetry)
    property string _communicationRiskText: _riskLabelFromLevel(_communicationRiskLevel)
    property int _missionRiskLevel: _calculateMissionRiskLevel()
    property string _missionRiskText: _riskLabelFromLevel(_missionRiskLevel)
    property string _batteryChangePointText: _batteryChangePoint < 0 ? qsTr("N/A") : _batteryChangePoint
    property string _batteriesRequiredText: _batteriesRequired < 0 ? qsTr("N/A") : _batteriesRequired

    readonly property real _margins: ScreenTools.defaultFontPixelWidth * 0.75
    readonly property color _panelColor: "#AA222222"
    readonly property color _cardColor: "#B32D2D2D"
    readonly property color _borderColor: "#99333333"
    readonly property color _primaryTextColor: "#FFFFFF"
    readonly property color _secondaryTextColor: "#B0B0B0"
    readonly property color _disabledTextColor: "#666666"
    readonly property int _titlePixelSize: 14
    readonly property int _labelPixelSize: 12
    readonly property int _valuePixelSize: 14

    function getMissionTime() {
        var totalSeconds = Number(_missionTime)
        if (!totalSeconds) {
            return "00:00:00"
        }

        var hours = Math.floor(totalSeconds / 3600)
        var minutes = Math.floor((totalSeconds % 3600) / 60)
        var seconds = Math.floor(totalSeconds % 60)

        var hoursText = hours < 10 ? "0" + hours : String(hours)
        var minutesText = minutes < 10 ? "0" + minutes : String(minutes)
        var secondsText = seconds < 10 ? "0" + seconds : String(seconds)

        return hoursText + ":" + minutesText + ":" + secondsText
    }

    function _calculateMaxSegmentDistance(_recalcToken) {
        let maxDistance = NaN

        if (!missionItems || missionItems.count <= 1) {
            return maxDistance
        }

        for (let i = 1; i < missionItems.count; i++) {
            const item = missionItems.get(i)
            if (!item) {
                continue
            }

            const distance = Number(item.distance)
            if (!isNaN(distance)) {
                maxDistance = isNaN(maxDistance) ? distance : Math.max(maxDistance, distance)
            }
        }

        return maxDistance
    }

    function _calculateCommunicationRiskLevel(maxTelemetryDistance) {
        if (isNaN(maxTelemetryDistance)) {
            return 0
        } else if (maxTelemetryDistance > 5000) {
            return 3
        } else if (maxTelemetryDistance > 2500) {
            return 2
        } else if (maxTelemetryDistance > 1000) {
            return 1
        }

        return 0
    }

    function _riskLabelFromLevel(level) {
        switch (level) {
        case 3:
            return qsTr("Critical")
        case 2:
            return qsTr("High")
        case 1:
            return qsTr("Medium")
        default:
            return qsTr("Low")
        }
    }

    function _calculateMissionRiskLevel() {
        let batteryRisk = 0
        if (_missionBatteryPercentRemaining >= 0) {
            if (_missionBatteryPercentRemaining < 10) {
                batteryRisk = 3
            } else if (_missionBatteryPercentRemaining < 20) {
                batteryRisk = 2
            } else if (_missionBatteryPercentRemaining < 35) {
                batteryRisk = 1
            }
        } else if (_batteriesRequired > 1) {
            batteryRisk = 2
        }

        let segmentRisk = 0
        if (!isNaN(_maxSegmentDistance)) {
            if (_maxSegmentDistance > 3000) {
                segmentRisk = 3
            } else if (_maxSegmentDistance > 1500) {
                segmentRisk = 2
            } else if (_maxSegmentDistance > 600) {
                segmentRisk = 1
            }
        }

        return Math.max(_communicationRiskLevel, batteryRisk, segmentRisk)
    }

    QGCFlickable {
        id: contentFlickable
        anchors.margins: _margins
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.AutoFlickDirection
        contentWidth: Math.max(width, mainLayout.implicitWidth + (_margins * 2))
        contentHeight: Math.max(height, mainLayout.implicitHeight + (_margins * 2))

        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Item {
            width: contentFlickable.contentWidth
            height: contentFlickable.contentHeight

            RowLayout {
                id: mainLayout
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: ScreenTools.defaultFontPixelWidth

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    color: _cardColor
                    border.width: 1
                    border.color: _borderColor
                    radius: 8
                    implicitWidth: waypointGrid.implicitWidth + (_margins * 2)
                    implicitHeight: waypointGrid.implicitHeight + (_margins * 2)

                    GridLayout {
                        id: waypointGrid
                        anchors.margins: _margins
                        anchors.fill: parent
                        columns: 8
                        rowSpacing: _rowSpacing
                        columnSpacing: _labelToValueSpacing

                        QGCLabel {
                            text: qsTr("Selected Waypoint")
                            color: _secondaryTextColor
                            Layout.columnSpan: 8
                            font.pixelSize: _titlePixelSize
                        }

                        QGCLabel { text: qsTr("Alt diff:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _altDifferenceText
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _mediumValueWidth
                        }

                        Item { width: 1; height: 1 }

                        QGCLabel { text: qsTr("Azimuth:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _azimuthText
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _smallValueWidth
                        }

                        Item { width: 1; height: 1 }

                        QGCLabel { text: qsTr("Dist prev WP:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _distanceText
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _largeValueWidth
                        }

                        QGCLabel { text: qsTr("Gradient:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _gradientText
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _mediumValueWidth
                        }

                        Item { width: 1; height: 1 }

                        QGCLabel { text: qsTr("Heading:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _headingText
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _smallValueWidth
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    color: _cardColor
                    border.width: 1
                    border.color: _borderColor
                    radius: 8
                    implicitWidth: missionGrid.implicitWidth + (_margins * 2)
                    implicitHeight: missionGrid.implicitHeight + (_margins * 2)

                    GridLayout {
                        id: missionGrid
                        anchors.margins: _margins
                        anchors.fill: parent
                        columns: 5
                        rowSpacing: _rowSpacing
                        columnSpacing: _labelToValueSpacing

                        QGCLabel {
                            text: qsTr("Total Mission")
                            color: _secondaryTextColor
                            Layout.columnSpan: 5
                            font.pixelSize: _titlePixelSize
                        }

                        QGCLabel { text: qsTr("Distance:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _missionPlannedDistanceText
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _largeValueWidth
                        }

                        Item { width: 1; height: 1 }

                        QGCLabel { text: qsTr("Max telem dist:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _missionMaxTelemetryText
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _largeValueWidth
                        }

                        QGCLabel { text: qsTr("Time:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: getMissionTime()
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _largeValueWidth
                        }

                        QGCLabel { text: qsTr("Max segment:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _maxSegmentDistanceText
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _largeValueWidth
                        }

                        Item { width: 1; height: 1 }

                        QGCLabel { text: qsTr("Comm risk:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _communicationRiskText
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _largeValueWidth
                        }

                        QGCLabel { text: qsTr("Battery left (est):"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _missionBatteryPercentRemainingText
                            color: _missionBatteryPercentRemaining < 0 ? _disabledTextColor : _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _largeValueWidth
                        }

                        Item { width: 1; height: 1 }

                        QGCLabel { text: qsTr("Mission risk:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _missionRiskText
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _largeValueWidth
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    color: _cardColor
                    border.width: 1
                    border.color: _borderColor
                    radius: 8
                    visible: _batteryInfoAvailable
                    implicitWidth: batteryGrid.implicitWidth + (_margins * 2)
                    implicitHeight: batteryGrid.implicitHeight + (_margins * 2)

                    GridLayout {
                        id: batteryGrid
                        anchors.margins: _margins
                        anchors.fill: parent
                        columns: 3
                        rowSpacing: _rowSpacing
                        columnSpacing: _labelToValueSpacing
                        visible: _batteryInfoAvailable

                        QGCLabel {
                            text: qsTr("Battery")
                            color: _secondaryTextColor
                            Layout.columnSpan: 3
                            font.pixelSize: _titlePixelSize
                        }

                        QGCLabel { text: qsTr("Batteries required:"); font.pixelSize: _labelPixelSize; color: _secondaryTextColor }
                        QGCLabel {
                            text: _batteriesRequiredText
                            color: _primaryTextColor
                            font.pixelSize: _valuePixelSize
                            Layout.minimumWidth: _mediumValueWidth
                        }
                    }
                }
            }
        }
    }
}
