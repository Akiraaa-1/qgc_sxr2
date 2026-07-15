import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: _summaryRoot

    anchors.fill: parent
    color: qgcPal.window
    property bool useOfflineVehicleFallback: false
    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
        ? QGroundControl.multiVehicleManager.activeVehicle
        : (useOfflineVehicleFallback ? QGroundControl.multiVehicleManager.offlineEditingVehicle : null)
    readonly property bool _parametersReady: _activeVehicle ? _activeVehicle.parameterManager.parametersReady : false

    readonly property real _pageMargins: ScreenTools.defaultFontPixelHeight * 0.7
    readonly property real _sectionSpacingX: _pageMargins * 0.8
    readonly property real _sectionSpacingY: _pageMargins * 0.9
    readonly property int _columnCount: width >= ScreenTools.defaultFontPixelWidth * 88
        ? 3
        : (width >= ScreenTools.defaultFontPixelWidth * 58 ? 2 : 1)
    readonly property real _availableContentWidth: Math.max(0, width - (_pageMargins * 2))
    readonly property real _singleColumnCardWidth: Math.max(
        ScreenTools.defaultFontPixelWidth * 36,
        Math.min(ScreenTools.defaultFontPixelWidth * 88, _availableContentWidth)
    )
    readonly property real _multiColumnCardWidth: Math.max(
        ScreenTools.defaultFontPixelWidth * 24,
        Math.min(ScreenTools.defaultFontPixelWidth * 34, (_availableContentWidth - (_sectionSpacingX * (_columnCount - 1))) / _columnCount)
    )
    readonly property real _contentWidth: _columnCount > 1
        ? _availableContentWidth
        : _singleColumnCardWidth
    readonly property real _overviewChecklistWidth: Math.max(
        ScreenTools.defaultFontPixelWidth * 44,
        Math.min(_contentWidth * 0.60, _contentWidth - (ScreenTools.defaultFontPixelWidth * 2.2))
    )

    readonly property real _cardCornerRadius: ScreenTools.defaultFontPixelHeight * 0.66
    readonly property real _cardPadding: ScreenTools.defaultFontPixelHeight * 0.9
    readonly property real _cardHeaderSpacing: ScreenTools.defaultFontPixelHeight * 0.58
    readonly property real _summaryCardHeight: ScreenTools.defaultFontPixelHeight * (_columnCount > 1 ? 9.6 : 10.8)
    readonly property real _statusBadgeSize: ScreenTools.defaultFontPixelHeight * 1.55
    readonly property real _statusGlyphSize: _statusBadgeSize * 0.62
    readonly property color _cardBorderColor: "#333333"
    readonly property color _cardBaseColor: "#2D2D2D"
    readonly property color _cardHoverColor: "#343434"
    readonly property color _cardPressedColor: "#252525"
    readonly property color _cardPrimaryTextColor: "#FFFFFF"
    readonly property color _cardSecondaryTextColor: "#B0B0B0"
    readonly property color _cardDisabledTextColor: "#666666"
    readonly property color _cardAccentColor: "#2563EB"
    readonly property color _cardWarningColor: "#D6A566"
    readonly property color _cardDangerColor: "#D95C5C"
    readonly property color _cardSuccessColor: "#56B38A"
    readonly property color _cardIconChipColor: "#3A3A3A"
    readonly property color _cardShadowColor: Qt.rgba(0, 0, 0, 0.22)
    readonly property int _cardStateDuration: 200

    readonly property var _primaryBattery: _activeVehicle && _activeVehicle.batteries && _activeVehicle.batteries.count > 0
        ? _activeVehicle.batteries.get(0)
        : null
    readonly property real _batteryPercent: _primaryBattery && _primaryBattery.percentRemaining
        ? Number(_primaryBattery.percentRemaining.rawValue)
        : NaN
    readonly property real _gpsSatellites: _activeVehicle && _activeVehicle.gps && _activeVehicle.gps.count
        ? Number(_activeVehicle.gps.count.rawValue)
        : NaN
    readonly property real _gpsLock: _activeVehicle && _activeVehicle.gps && _activeVehicle.gps.lock
        ? Number(_activeVehicle.gps.lock.rawValue)
        : NaN
    readonly property real _gpsHdop: _activeVehicle && _activeVehicle.gps && _activeVehicle.gps.hdop
        ? Number(_activeVehicle.gps.hdop.rawValue)
        : NaN
    readonly property real _rcRssiPercent: _validRcRssiPercent(_activeVehicle && _activeVehicle.rcRSSI !== undefined
        ? Number(_activeVehicle.rcRSSI)
        : NaN)
    readonly property real _telemetryQualityPercent: _calcTelemetryQualityPercent()
    readonly property bool _healthReportSupported: !!(_activeVehicle && _activeVehicle.healthAndArmingCheckReport && _activeVehicle.healthAndArmingCheckReport.supported)
    readonly property bool _canArm: _healthReportSupported
        ? !!_activeVehicle.healthAndArmingCheckReport.canArm
        : !!(_activeVehicle && _activeVehicle.readyToFlyAvailable && _activeVehicle.readyToFly)
    readonly property bool _hasHealthWarnings: _healthReportSupported
        ? !!_activeVehicle.healthAndArmingCheckReport.hasWarningsOrErrors
        : false
    readonly property bool _setupComplete: !!(_activeVehicle && _activeVehicle.autopilotPlugin && _activeVehicle.autopilotPlugin.setupComplete)
    readonly property bool _vehicleConnected: !!_activeVehicle && !_activeVehicle.isOfflineEditingVehicle
    readonly property int _batteryStatusLevel: _batteryLevel(_batteryPercent)
    readonly property int _gpsStatusLevel: _gpsLevel(_gpsSatellites, _gpsLock, _gpsHdop)
    readonly property int _rcStatusLevel: _rcLevel(_rcRssiPercent)
    readonly property int _telemetryStatusLevel: _telemetryLevel(_telemetryQualityPercent)
    readonly property int _configStatusLevel: _setupComplete ? 0 : 2
    readonly property int _armingStatusLevel: _canArm ? (_hasHealthWarnings ? 1 : 0) : 2
    readonly property int _overallStatusLevel: _maxLevel([
        _batteryStatusLevel,
        _gpsStatusLevel,
        _rcStatusLevel,
        _telemetryStatusLevel,
        _configStatusLevel,
        _armingStatusLevel
    ])
    readonly property string _overallStatusText: _statusText(_overallStatusLevel)
    readonly property color _overallStatusColor: _statusColor(_overallStatusLevel)

    function _componentKey(component) {
        if (!component) {
            return ""
        }

        var name = component.name ? component.name.toString().toLowerCase() : ""
        var setupSource = component.setupSource ? component.setupSource.toString().toLowerCase() : ""

        if (setupSource.indexOf("joystickcomponent") !== -1 || name.indexOf("joystick") !== -1 || name.indexOf("\u6447\u6746") !== -1) {
            return "joystick"
        }
        if (setupSource.indexOf("safetycomponent") !== -1 || setupSource.indexOf("failsafe") !== -1 || name.indexOf("safety") !== -1 || name.indexOf("failsafe") !== -1 || name.indexOf("\u5b89\u5168") !== -1) {
            return "safety"
        }
        if (setupSource.indexOf("airframecomponent") !== -1 || setupSource.indexOf("subframecomponent") !== -1 || name.indexOf("airframe") !== -1 || name.indexOf("frame") !== -1 || name.indexOf("\u673a\u67b6") !== -1) {
            return "airframe"
        }
        if (setupSource.indexOf("powercomponent") !== -1 || name.indexOf("power") !== -1 || name.indexOf("battery") !== -1 || name.indexOf("\u7535\u6e90") !== -1) {
            return "power"
        }
        if (setupSource.indexOf("radiocomponent") !== -1 || setupSource.indexOf("remotecontrol") !== -1 || name.indexOf("radio") !== -1 || name.indexOf("remote") !== -1 || name.indexOf("\u9065\u63a7") !== -1) {
            return "radio"
        }
        if (setupSource.indexOf("sensorscomponent") !== -1 || name.indexOf("sensor") !== -1 || name.indexOf("\u4f20\u611f") !== -1) {
            return "sensors"
        }
        if (setupSource.indexOf("flightmodescomponent") !== -1 || setupSource.indexOf("flightmode") !== -1 || name.indexOf("flight mode") !== -1 || name.indexOf("\u98de\u884c\u6a21\u5f0f") !== -1) {
            return "flightModes"
        }
        if (name.indexOf("actuators") !== -1 || setupSource.indexOf("actuatorcomponent.qml") !== -1) {
            return "actuators"
        }
        if (name.indexOf("motors") !== -1 || setupSource.indexOf("motorcomponent.qml") !== -1 || name.indexOf("\u7535\u673a") !== -1) {
            return "motors"
        }
        if (setupSource.indexOf("px4flightbehavior") !== -1 || name.indexOf("flight behavior") !== -1) {
            return "flightBehavior"
        }

        return ""
    }

    function _clampPercent(value) {
        if (isNaN(Number(value))) {
            return NaN
        }
        return Math.max(0, Math.min(100, Number(value)))
    }

    function _validRcRssiPercent(value) {
        const numeric = Number(value)
        if (isNaN(numeric) || numeric < 0 || numeric > 100) {
            return NaN
        }
        return numeric
    }

    function _telemetryRssiToPercent(rssi) {
        const numeric = Number(rssi)
        if (isNaN(numeric) || numeric === 0) {
            return NaN
        }
        const minDbm = -120
        const maxDbm = -45
        const normalized = (numeric - minDbm) / (maxDbm - minDbm)
        return _clampPercent(normalized * 100)
    }

    function _calcTelemetryQualityPercent() {
        if (!_activeVehicle) {
            return NaN
        }

        const localPercent = _telemetryRssiToPercent(_activeVehicle.telemetryLRSSI)
        const remotePercent = _telemetryRssiToPercent(_activeVehicle.telemetryRRSSI)
        const rxErrors = _activeVehicle.telemetryRXErrors !== undefined ? Number(_activeVehicle.telemetryRXErrors) : NaN
        const txBuffer = _activeVehicle.telemetryTXBuffer !== undefined ? _clampPercent(_activeVehicle.telemetryTXBuffer) : NaN

        let quality = NaN
        if (!isNaN(localPercent) && !isNaN(remotePercent)) {
            quality = (localPercent * 0.55) + (remotePercent * 0.45)
        } else if (!isNaN(localPercent)) {
            quality = localPercent
        } else if (!isNaN(remotePercent)) {
            quality = remotePercent
        }

        if (!isNaN(quality) && !isNaN(rxErrors)) {
            quality -= Math.min(40, rxErrors * 0.45)
        }
        if (!isNaN(quality) && !isNaN(txBuffer)) {
            quality -= Math.max(0, txBuffer - 80) * 0.7
        }

        return _clampPercent(quality)
    }

    function _batteryLevel(percent) {
        if (isNaN(percent)) {
            return 1
        } else if (percent < 20) {
            return 2
        } else if (percent < 35) {
            return 1
        }
        return 0
    }

    function _gpsLevel(satellites, lock, hdop) {
        if (isNaN(satellites) && isNaN(lock) && isNaN(hdop)) {
            return 1
        }
        if ((!isNaN(lock) && lock < 3) || (!isNaN(satellites) && satellites < 6)) {
            return 2
        }
        if ((!isNaN(lock) && lock === 3) || (!isNaN(satellites) && satellites < 10) || (!isNaN(hdop) && hdop > 2.5)) {
            return 1
        }
        return 0
    }

    function _rcLevel(rssiPercent) {
        if (isNaN(rssiPercent)) {
            return 1
        } else if (rssiPercent < 35) {
            return 2
        } else if (rssiPercent < 55) {
            return 1
        }
        return 0
    }

    function _telemetryLevel(qualityPercent) {
        if (isNaN(qualityPercent)) {
            return 1
        } else if (qualityPercent < 35) {
            return 2
        } else if (qualityPercent < 60) {
            return 1
        }
        return 0
    }

    function _statusText(level) {
        if (level >= 2) {
            return qsTr("Not Ready")
        } else if (level === 1) {
            return qsTr("Attention")
        }
        return qsTr("Ready")
    }

    function _statusColor(level) {
        if (level >= 2) {
            return _cardDangerColor
        } else if (level === 1) {
            return _cardWarningColor
        }
        return _cardSuccessColor
    }

    function _maxLevel(levels) {
        let maxLevel = 0
        for (let i = 0; i < levels.length; i++) {
            maxLevel = Math.max(maxLevel, Number(levels[i]))
        }
        return maxLevel
    }

    function _formatPercent(value) {
        return isNaN(value) ? "--" : (Math.round(value) + "%")
    }

    function _componentTitle(component) {
        if (!component) {
            return ""
        }

        const key = _componentKey(component)
        switch (key) {
        case "joystick":        return qsTr("Joystick")
        case "sensors":         return qsTr("Sensors")
        case "safety":          return qsTr("Safety")
        case "airframe":        return qsTr("Airframe")
        case "power":           return qsTr("Power")
        case "radio":           return qsTr("Radio")
        case "flightModes":     return qsTr("Flight Modes")
        case "actuators":
        case "motors":          return qsTr("Actuators")
        case "flightBehavior":  return qsTr("Flight Behavior")
        }

        const name = component.name ? component.name.toString() : ""
        switch (name) {
        case "Joystick":                return qsTr("Joystick")
        case "Sensors":                 return qsTr("Sensors")
        case "Safety":                  return qsTr("Safety")
        case "Airframe":                return qsTr("Airframe")
        case "Power":                   return qsTr("Power")
        case "Radio":                   return qsTr("Radio")
        case "Flight Modes":            return qsTr("Flight Modes")
        case "Actuators":               return qsTr("Actuators")
        case "Motors":                  return qsTr("Motors")
        case "Vehicle Configuration":   return qsTr("Vehicle Configuration")
        }

        return name
    }

    function _isActuatorComponent(component) {
        return _componentKey(component) === "actuators"
    }

    function _isMotorComponent(component) {
        return _componentKey(component) === "motors"
    }

    function _summaryActuatorComponent() {
        if (!_activeVehicle || !_activeVehicle.autopilotPlugin) {
            return null
        }

        const components = _activeVehicle.autopilotPlugin.vehicleComponents
        for (let i = 0; i < components.length; i++) {
            const component = components[i]
            if (_isActuatorComponent(component)) {
                return component
            }
        }

        return null
    }

    function _summaryDisplayComponent(component) {
        const actuatorComponent = _summaryActuatorComponent()
        if (actuatorComponent && _isMotorComponent(component)) {
            return actuatorComponent
        }
        return component
    }

    function _statusBadgeColor(component) {
        return _cardIconChipColor
    }

    function _statusBadgeIcon(component) {
        var key = _componentKey(component)
        if (key === "joystick") {
            return "/qmlimages/Joystick.png"
        }
        if (key === "sensors") {
            return "/qmlimages/SensorsComponentIcon.png"
        }
        if (key === "safety") {
            return "/qmlimages/SafetyComponentIcon.png"
        }
        if (key === "airframe") {
            return "/qmlimages/AirframeComponentIcon.png"
        }
        if (key === "power") {
            return "/qmlimages/PowerComponentIcon.png"
        }
        if (key === "radio") {
            return "/qmlimages/RadioComponentIcon.png"
        }
        if (key === "flightModes") {
            return "/qmlimages/FlightModesComponentIcon.png"
        }
        if (key === "actuators" || key === "motors") {
            return "/qmlimages/MotorComponentIcon.svg"
        }

        return component && component.iconResource ? component.iconResource.toString() : ""
    }

    function _hasSummary(component) {
        return !!(component && component.summaryQmlSource && component.summaryQmlSource.toString() !== "")
    }

    function _hasSetup(component) {
        return !!(component && component.setupSource && component.setupSource.toString() !== "")
    }

    function _isHiddenSummaryComponent(component) {
        if (!component) {
            return false
        }

        var name = component.name ? component.name.toString().toLowerCase() : ""
        var setupSource = component.setupSource ? component.setupSource.toString().toLowerCase() : ""
        var summarySource = component.summaryQmlSource ? component.summaryQmlSource.toString().toLowerCase() : ""

        if (_componentKey(component) === "flightBehavior") {
            return true
        }

        if (_isActuatorComponent(component)) {
            return true
        }

        if (name.indexOf("pid tuning") !== -1
                || setupSource.indexOf("px4tuningcomponent.qml") !== -1) {
            return true
        }

        if (name.indexOf("flight behavior") !== -1
                || setupSource.indexOf("px4flightbehavior.qml") !== -1
                || summarySource.indexOf("flightbehavior") !== -1) {
            return true
        }

        return false
    }

    function _showCard(component) {
        return !_isHiddenSummaryComponent(component) && (_hasSummary(component) || _hasSetup(component))
    }

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: enabled
    }

    QGCFlickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + (_summaryRoot._pageMargins * 2)
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: contentColumn

            width: _summaryRoot._contentWidth
            anchors.top: parent.top
            anchors.topMargin: _summaryRoot._pageMargins * 0.4
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: _summaryRoot._sectionSpacingY

            Rectangle {
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: _summaryRoot._overviewChecklistWidth
                color: _summaryRoot._cardBaseColor
                radius: _summaryRoot._cardCornerRadius
                border.width: 1
                border.color: _summaryRoot._cardBorderColor
                implicitHeight: overviewContent.implicitHeight + (_summaryRoot._cardPadding * 2)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: parent.radius + 1
                    color: _summaryRoot._cardShadowColor
                    z: -1
                }

                ColumnLayout {
                    id: overviewContent
                    anchors.fill: parent
                    anchors.margins: _summaryRoot._cardPadding
                    spacing: _summaryRoot._cardHeaderSpacing

                    RowLayout {
                        Layout.fillWidth: true

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Flight Readiness Overview")
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                            color: _summaryRoot._cardPrimaryTextColor
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            radius: ScreenTools.defaultFontPixelHeight * 0.45
                            color: _summaryRoot._overallStatusColor
                            implicitHeight: ScreenTools.defaultFontPixelHeight * 1.3
                            implicitWidth: overallStatusText.implicitWidth + (ScreenTools.defaultFontPixelWidth * 1.6)

                            QGCLabel {
                                id: overallStatusText
                                anchors.centerIn: parent
                                text: _summaryRoot._overallStatusText
                                font.bold: true
                                color: "#111111"
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: _summaryRoot._columnCount > 2 ? 3 : (_summaryRoot._columnCount > 1 ? 2 : 1)
                        columnSpacing: _summaryRoot._sectionSpacingX * 0.7
                        rowSpacing: _summaryRoot._sectionSpacingY * 0.65

                        Repeater {
                            model: [
                                {
                                    "title": qsTr("Battery"),
                                    "value": _summaryRoot._formatPercent(_summaryRoot._batteryPercent),
                                    "detail": _summaryRoot._primaryBattery ? qsTr("Primary pack") : qsTr("No battery telemetry"),
                                    "level": _summaryRoot._batteryStatusLevel
                                },
                                {
                                    "title": qsTr("GPS"),
                                    "value": isNaN(_summaryRoot._gpsSatellites) ? "--" : (Math.round(_summaryRoot._gpsSatellites) + qsTr(" sats")),
                                    "detail": isNaN(_summaryRoot._gpsHdop) ? qsTr("HDOP --") : qsTr("HDOP %1").arg(_summaryRoot._gpsHdop.toFixed(1)),
                                    "level": _summaryRoot._gpsStatusLevel
                                },
                                {
                                    "title": qsTr("RC Link"),
                                    "value": _summaryRoot._formatPercent(_summaryRoot._rcRssiPercent),
                                    "detail": isNaN(_summaryRoot._rcRssiPercent) ? qsTr("RC signal not provided") : qsTr("Control signal"),
                                    "level": _summaryRoot._rcStatusLevel
                                },
                                {
                                    "title": qsTr("Telemetry"),
                                    "value": _summaryRoot._formatPercent(_summaryRoot._telemetryQualityPercent),
                                    "detail": qsTr("Data link quality"),
                                    "level": _summaryRoot._telemetryStatusLevel
                                },
                                {
                                    "title": qsTr("Configuration"),
                                    "value": _summaryRoot._setupComplete ? qsTr("Complete") : qsTr("Pending"),
                                    "detail": qsTr("Autopilot setup"),
                                    "level": _summaryRoot._configStatusLevel
                                },
                                {
                                    "title": qsTr("Arming Check"),
                                    "value": _summaryRoot._canArm ? (_summaryRoot._hasHealthWarnings ? qsTr("Warnings") : qsTr("Pass")) : qsTr("Blocked"),
                                    "detail": _summaryRoot._healthReportSupported ? qsTr("Health and arming report") : qsTr("Fallback readiness"),
                                    "level": _summaryRoot._armingStatusLevel
                                }
                            ]

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: tileContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.8)
                                radius: _summaryRoot._cardCornerRadius * 0.8
                                color: "#252525"
                                border.width: 1
                                border.color: _summaryRoot._cardBorderColor

                                ColumnLayout {
                                    id: tileContent
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.42
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.12

                                    RowLayout {
                                        Layout.fillWidth: true

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: modelData.title
                                            color: _summaryRoot._cardSecondaryTextColor
                                            font.pointSize: ScreenTools.defaultFontPointSize * 0.92
                                        }

                                        Rectangle {
                                            radius: width / 2
                                            implicitWidth: ScreenTools.defaultFontPixelHeight * 0.62
                                            implicitHeight: implicitWidth
                                            color: _summaryRoot._statusColor(modelData.level)
                                        }
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: modelData.value
                                        font.bold: true
                                        color: _summaryRoot._cardPrimaryTextColor
                                        font.pointSize: ScreenTools.defaultFontPointSize * 1.08
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: modelData.detail
                                        color: _summaryRoot._cardSecondaryTextColor
                                        font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: _summaryRoot._overviewChecklistWidth
                color: _summaryRoot._cardBaseColor
                radius: _summaryRoot._cardCornerRadius
                border.width: 1
                border.color: _summaryRoot._cardBorderColor
                implicitHeight: checklistContent.implicitHeight + (_summaryRoot._cardPadding * 2)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: parent.radius + 1
                    color: _summaryRoot._cardShadowColor
                    z: -1
                }

                ColumnLayout {
                    id: checklistContent
                    anchors.fill: parent
                    anchors.margins: _summaryRoot._cardPadding
                    spacing: ScreenTools.defaultFontPixelHeight * 0.45

                    QGCLabel {
                        Layout.fillWidth: true
                        text: qsTr("Preflight Checklist")
                        font.bold: true
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.08
                        color: _summaryRoot._cardPrimaryTextColor
                    }

                    Repeater {
                        model: [
                            { "name": qsTr("Vehicle connection established"), "level": _summaryRoot._vehicleConnected ? 0 : 2 },
                            { "name": qsTr("Autopilot configuration completed"), "level": _summaryRoot._configStatusLevel },
                            { "name": qsTr("Battery reserve acceptable"), "level": _summaryRoot._batteryStatusLevel },
                            { "name": qsTr("GPS quality acceptable"), "level": _summaryRoot._gpsStatusLevel },
                            { "name": isNaN(_summaryRoot._rcRssiPercent) ? qsTr("RC signal unavailable") : qsTr("RC signal quality acceptable"), "level": _summaryRoot._rcStatusLevel },
                            { "name": qsTr("Telemetry link quality acceptable"), "level": _summaryRoot._telemetryStatusLevel },
                            { "name": qsTr("Arming checks pass"), "level": _summaryRoot._armingStatusLevel }
                        ]

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: rowLayout.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.35
                            radius: _summaryRoot._cardCornerRadius * 0.65
                            color: "#252525"
                            border.width: 1
                            border.color: _summaryRoot._cardBorderColor

                            RowLayout {
                                id: rowLayout
                                anchors.fill: parent
                                anchors.margins: ScreenTools.defaultFontPixelHeight * 0.3
                                spacing: ScreenTools.defaultFontPixelWidth * 0.7

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: width / 2
                                    implicitWidth: ScreenTools.defaultFontPixelHeight * 0.62
                                    implicitHeight: implicitWidth
                                    color: _summaryRoot._statusColor(modelData.level)
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    wrapMode: Text.WordWrap
                                    color: _summaryRoot._cardPrimaryTextColor
                                }

                                QGCLabel {
                                    text: _summaryRoot._statusText(modelData.level)
                                    color: _summaryRoot._statusColor(modelData.level)
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            GridLayout {
                id: summaryCardsGrid

                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                columns: _summaryRoot._columnCount
                columnSpacing: _summaryRoot._sectionSpacingX
                rowSpacing: _summaryRoot._sectionSpacingY

                Repeater {
                    // Depend on _parametersReady so model re-evaluates once parameters are available.
                    model: (_summaryRoot._parametersReady
                            && _summaryRoot._activeVehicle
                            && _summaryRoot._activeVehicle.autopilotPlugin)
                        ? _summaryRoot._activeVehicle.autopilotPlugin.vehicleComponents
                        : []

                    Rectangle {
                        id: summaryCard

                        required property var modelData

                        readonly property var vehicleComponent: modelData
                        readonly property var summaryComponent: _summaryRoot._summaryDisplayComponent(vehicleComponent)

                        visible: _summaryRoot._showCard(vehicleComponent)
                        Layout.preferredWidth: _summaryRoot._columnCount > 1 ? _summaryRoot._multiColumnCardWidth : _summaryRoot._singleColumnCardWidth
                        Layout.preferredHeight: _summaryRoot._summaryCardHeight
                        Layout.fillWidth: _summaryRoot._columnCount === 1
                        Layout.alignment: Qt.AlignTop

                        color: _summaryRoot._cardBaseColor
                        radius: _summaryRoot._cardCornerRadius
                        border.width: 1
                        border.color: _summaryRoot._cardBorderColor

                        Behavior on color {
                            ColorAnimation {
                                duration: _summaryRoot._cardStateDuration
                                easing.type: Easing.InOutQuad
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -1
                            radius: parent.radius + 1
                            color: _summaryRoot._cardShadowColor
                            z: -1
                        }

                        ColumnLayout {
                            id: cardContent

                            anchors.fill: parent
                            anchors.margins: _summaryRoot._cardPadding
                            spacing: _summaryRoot._cardHeaderSpacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.65

                                Rectangle {
                                    Layout.preferredWidth: _summaryRoot._statusBadgeSize
                                    Layout.preferredHeight: _summaryRoot._statusBadgeSize
                                    radius: ScreenTools.defaultFontPixelHeight * 0.5
                                    color: _summaryRoot._statusBadgeColor(vehicleComponent)
                                    border.width: 1
                                    border.color: _summaryRoot._cardBorderColor

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        width: _summaryRoot._statusGlyphSize
                                        height: width
                                        source: _summaryRoot._statusBadgeIcon(vehicleComponent)
                                        fillMode: Image.PreserveAspectFit
                                        color: "white"
                                    }
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: _summaryRoot._componentTitle(summaryComponent)
                                    font.pointSize: ScreenTools.defaultFontPointSize * 1.12
                                    font.bold: true
                                    color: _summaryRoot._cardPrimaryTextColor
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 1.35
                                    Layout.preferredHeight: Layout.preferredWidth
                                    radius: Layout.preferredWidth / 2
                                    visible: summaryComponent ? (summaryComponent.requiresSetup && summaryComponent.setupSource !== "") : false
                                    color: summaryComponent && summaryComponent.setupComplete ? _summaryRoot._cardAccentColor : _summaryRoot._cardDisabledTextColor
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: _summaryRoot._cardBorderColor
                            }

                            Item {
                                id: summaryViewport

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 0
                                clip: true

                                Loader {
                                    id: summaryLoader

                                    anchors.fill: parent
                                    source: _summaryRoot._hasSummary(summaryComponent)
                                        ? summaryComponent.summaryQmlSource
                                        : ""

                                    onLoaded: {
                                        if (item && item.hasOwnProperty("width")) {
                                            item.width = Qt.binding(function() { return summaryViewport.width })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: _summaryRoot._pageMargins
            }
        }
    }
}
