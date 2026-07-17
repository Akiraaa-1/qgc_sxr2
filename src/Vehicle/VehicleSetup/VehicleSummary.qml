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
        Math.min(ScreenTools.defaultFontPixelWidth * 112, _contentWidth - (ScreenTools.defaultFontPixelWidth * 2.2))
    )

    readonly property real _cardCornerRadius: ScreenTools.defaultFontPixelHeight * 0.66
    readonly property real _cardPadding: ScreenTools.defaultFontPixelHeight * 0.9
    readonly property real _cardHeaderSpacing: ScreenTools.defaultFontPixelHeight * 0.58
    readonly property real _summaryCardHeight: ScreenTools.defaultFontPixelHeight * (_columnCount > 1 ? 9.6 : 10.8)
    readonly property real _moduleSummaryCardHeight: ScreenTools.defaultFontPixelHeight * 7.2
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
    property bool _healthDetailsVisible: false

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
    readonly property real _gpsVdop: _activeVehicle && _activeVehicle.gps && _activeVehicle.gps.vdop
        ? Number(_activeVehicle.gps.vdop.rawValue)
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

    function _gpsDopDetail() {
        const hdopText = isNaN(_gpsHdop) ? "--" : _gpsHdop.toFixed(1)
        const vdopText = isNaN(_gpsVdop) ? "--" : _gpsVdop.toFixed(1)
        return qsTr("HDOP %1 / VDOP %2").arg(hdopText).arg(vdopText)
    }

    function _levelConclusion(level, readyText, attentionText, blockedText) {
        if (level >= 2) {
            return blockedText
        } else if (level === 1) {
            return attentionText
        }
        return readyText
    }

    function _healthReport() {
        return _activeVehicle && _activeVehicle.healthAndArmingCheckReport
            ? _activeVehicle.healthAndArmingCheckReport
            : null
    }

    function _healthProblems() {
        const report = _healthReport()
        return report && report.problemsForCurrentMode ? report.problemsForCurrentMode : null
    }

    function _healthProblemCount() {
        const problems = _healthProblems()
        return problems ? problems.count : 0
    }

    function _healthStateSummary() {
        const report = _healthReport()
        if (!report || !report.supported) {
            return qsTr("当前飞控未提供健康与解锁报告，地面站只能使用备用就绪状态。")
        }
        return qsTr("解锁：%1\n起飞：%2\n开始任务：%3")
            .arg(report.canArm ? qsTr("允许") : qsTr("阻止"))
            .arg(report.canTakeoff ? qsTr("允许") : qsTr("阻止"))
            .arg(report.canStartMission ? qsTr("允许") : qsTr("阻止"))
    }

    function _translatedHealthText(text) {
        let translated = (text || "").toString()
        translated = translated.replace(/No manual control input/gi, qsTr("没有手动控制输入"))
        translated = translated.replace(/Connect and enable stick input or use autonomous mode\./gi, qsTr("连接并启用摇杆输入，或使用自主模式。"))
        translated = translated.replace(/Sticks can be enabled via\s*(<a[^>]*>)?COM_RC_IN_MODE(<\/a>)?\s*parameter\./gi, qsTr("可通过 COM_RC_IN_MODE 参数启用摇杆输入。"))
        translated = translated.replace(/Switching to mode 'Position control' is currently not possible/gi, qsTr("当前无法切换到“位置控制”模式"))
        return translated
    }

    function _componentTitle(component) {
        if (!component) {
            return ""
        }

        const key = _componentKey(component)
        switch (key) {
        case "joystick":        return qsTr("摇杆")
        case "sensors":         return qsTr("传感器")
        case "safety":          return qsTr("安全保护")
        case "airframe":        return qsTr("机架")
        case "power":           return qsTr("电源")
        case "radio":           return qsTr("遥控器")
        case "flightModes":     return qsTr("飞行模式")
        case "actuators":
        case "motors":          return qsTr("执行器")
        case "flightBehavior":  return qsTr("飞行行为")
        }

        const name = component.name ? component.name.toString() : ""
        switch (name) {
        case "Joystick":                return qsTr("摇杆")
        case "Sensors":                 return qsTr("传感器")
        case "Safety":                  return qsTr("安全保护")
        case "Airframe":                return qsTr("机架")
        case "Power":                   return qsTr("电源")
        case "Radio":                   return qsTr("遥控器")
        case "Flight Modes":            return qsTr("飞行模式")
        case "Actuators":               return qsTr("执行器")
        case "Motors":                  return qsTr("电机")
        case "Vehicle Configuration":   return qsTr("飞行器配置")
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

    function _componentStatusLevel(component) {
        if (!component) {
            return 1
        }
        if (component.requiresSetup && !component.setupComplete) {
            return 2
        }
        if (component.setupComplete) {
            return 0
        }
        return 1
    }

    function _componentStatusColor(component) {
        return _statusColor(_componentStatusLevel(component))
    }

    function _moduleCheckValue(component) {
        const key = _componentKey(component)
        const level = _componentStatusLevel(component)
        if (key === "joystick") {
            return level === 0 ? qsTr("摇杆正常") : qsTr("未检测到摇杆")
        }
        if (key === "sensors") {
            return level === 0 ? qsTr("传感器就绪") : qsTr("传感器需检查")
        }
        if (key === "safety") {
            return level === 0 ? qsTr("保护已配置") : qsTr("保护需检查")
        }
        if (key === "airframe") {
            return level === 0 ? qsTr("机架已配置") : qsTr("机架需设置")
        }
        if (key === "actuators" || key === "motors") {
            const actuators = _activeVehicle ? _activeVehicle.actuators : null
            return actuators && actuators.hasUnsetRequiredFunctions ? qsTr("执行器需设置") : (level === 0 ? qsTr("执行器就绪") : qsTr("执行器需检查"))
        }
        if (key === "power") {
            return level === 0 ? qsTr("电源正常") : qsTr("电源需检查")
        }
        if (key === "radio") {
            return level === 0 ? qsTr("遥控器正常") : qsTr("遥控器需设置")
        }
        if (key === "flightModes") {
            return level === 0 ? qsTr("模式已配置") : qsTr("模式需设置")
        }
        return _statusText(level)
    }

    function _moduleCheckDetail(component) {
        const key = _componentKey(component)
        const level = _componentStatusLevel(component)
        if (key === "joystick") {
            return level === 0 ? qsTr("手控输入可用") : qsTr("手控输入不可用")
        }
        if (key === "sensors") {
            return level === 0 ? qsTr("磁罗盘/陀螺仪/加速度计正常") : qsTr("存在未就绪传感器")
        }
        if (key === "safety") {
            return level === 0 ? qsTr("低电量/链路丢失保护有效") : qsTr("检查失控保护与返航设置")
        }
        if (key === "airframe") {
            return level === 0 ? qsTr("机架类型与飞行器类型已确认") : qsTr("选择机架后再飞行")
        }
        if (key === "actuators" || key === "motors") {
            const actuators = _activeVehicle ? _activeVehicle.actuators : null
            if (actuators && actuators.hasUnsetRequiredFunctions) {
                return qsTr("存在未分配输出功能")
            }
            return level === 0 ? qsTr("电机/舵面输出已配置") : qsTr("检查输出与测试通道")
        }
        if (key === "power") {
            return _primaryBattery ? qsTr("电池与电源参数可用") : qsTr("无电池遥测")
        }
        if (key === "radio") {
            return level === 0 ? qsTr("主要遥控通道已映射") : qsTr("横滚/俯仰/油门等通道需确认")
        }
        if (key === "flightModes") {
            return level === 0 ? qsTr("模式开关与飞行模式可用") : qsTr("模式开关或飞行模式未完成")
        }
        return level === 0 ? qsTr("检查通过") : qsTr("需要检查")
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

        const componentKey = _componentKey(component)

        if (componentKey === "joystick" || componentKey === "airframe" || componentKey === "power") {
            return true
        }

        if (componentKey === "flightBehavior") {
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
                                    "title": qsTr("飞行器连接"),
                                    "value": _summaryRoot._vehicleConnected ? qsTr("已连接") : qsTr("未连接"),
                                    "detail": _summaryRoot._vehicleConnected ? qsTr("通信链路已建立") : qsTr("等待飞行器连接"),
                                    "level": _summaryRoot._vehicleConnected ? 0 : 2
                                },
                                {
                                    "title": qsTr("电池"),
                                    "value": _summaryRoot._formatPercent(_summaryRoot._batteryPercent),
                                    "detail": _summaryRoot._primaryBattery
                                        ? _summaryRoot._levelConclusion(_summaryRoot._batteryStatusLevel, qsTr("电池余量正常"), qsTr("电池余量需注意"), qsTr("电池余量不足"))
                                        : qsTr("无电池遥测"),
                                    "level": _summaryRoot._batteryStatusLevel
                                },
                                {
                                    "title": qsTr("定位"),
                                    "value": isNaN(_summaryRoot._gpsSatellites) ? "--" : qsTr("%1 颗卫星").arg(Math.round(_summaryRoot._gpsSatellites)),
                                    "detail": _summaryRoot._gpsDopDetail() + " / "
                                        + _summaryRoot._levelConclusion(_summaryRoot._gpsStatusLevel, qsTr("定位质量正常"), qsTr("定位质量需注意"), qsTr("定位质量不足")),
                                    "level": _summaryRoot._gpsStatusLevel
                                },
                                {
                                    "title": qsTr("遥控链路"),
                                    "value": _summaryRoot._formatPercent(_summaryRoot._rcRssiPercent),
                                    "detail": isNaN(_summaryRoot._rcRssiPercent)
                                        ? qsTr("遥控信号不可用")
                                        : _summaryRoot._levelConclusion(_summaryRoot._rcStatusLevel, qsTr("遥控链路正常"), qsTr("遥控链路需注意"), qsTr("遥控链路异常")),
                                    "level": _summaryRoot._rcStatusLevel
                                },
                                {
                                    "title": qsTr("遥测链路"),
                                    "value": _summaryRoot._formatPercent(_summaryRoot._telemetryQualityPercent),
                                    "detail": _summaryRoot._levelConclusion(_summaryRoot._telemetryStatusLevel, qsTr("遥测链路质量正常"), qsTr("遥测链路需注意"), qsTr("遥测链路异常")),
                                    "level": _summaryRoot._telemetryStatusLevel
                                },
                                {
                                    "title": qsTr("配置"),
                                    "value": _summaryRoot._setupComplete ? qsTr("完成") : qsTr("待完成"),
                                    "detail": _summaryRoot._setupComplete ? qsTr("自动驾驶仪配置已完成") : qsTr("自动驾驶仪配置未完成"),
                                    "level": _summaryRoot._configStatusLevel
                                },
                                {
                                    "title": qsTr("解锁检查"),
                                    "value": _summaryRoot._canArm ? (_summaryRoot._hasHealthWarnings ? qsTr("警告") : qsTr("通过")) : qsTr("阻止"),
                                    "detail": _summaryRoot._canArm ? (_summaryRoot._hasHealthWarnings ? qsTr("解锁检查存在警告") : qsTr("解锁检查通过")) : qsTr("解锁检查未通过"),
                                    "level": _summaryRoot._armingStatusLevel,
                                    "action": "health"
                                }
                            ]

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: _summaryRoot._moduleSummaryCardHeight
                                Layout.minimumHeight: _summaryRoot._moduleSummaryCardHeight
                                radius: _summaryRoot._cardCornerRadius * 0.8
                                color: "#252525"
                                border.width: 1
                                border.color: _summaryRoot._cardBorderColor
                                opacity: tileMouseArea.pressed ? 0.82 : 1

                                MouseArea {
                                    id: tileMouseArea
                                    anchors.fill: parent
                                    enabled: modelData.action === "health"
                                    hoverEnabled: enabled
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: _summaryRoot._healthDetailsVisible = true
                                }

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

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: _summaryRoot._cardBorderColor
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
                        Repeater {
                            // Depend on _parametersReady so model re-evaluates once parameters are available.
                            model: (_summaryRoot._parametersReady
                                    && _summaryRoot._activeVehicle
                                    && _summaryRoot._activeVehicle.autopilotPlugin)
                                ? _summaryRoot._activeVehicle.autopilotPlugin.vehicleComponents
                                : []

                            Rectangle {
                                id: moduleSummaryPanel

                                required property var modelData

                                readonly property var vehicleComponent: modelData
                                readonly property var summaryComponent: _summaryRoot._summaryDisplayComponent(vehicleComponent)

                                visible: _summaryRoot._showCard(vehicleComponent)
                                Layout.fillWidth: true
                                Layout.preferredHeight: visible ? _summaryRoot._moduleSummaryCardHeight : 0
                                Layout.minimumHeight: 0
                                Layout.alignment: Qt.AlignTop
                                radius: _summaryRoot._cardCornerRadius * 0.8
                                color: "#252525"
                                border.width: 1
                                border.color: _summaryRoot._cardBorderColor

                                ColumnLayout {
                                    id: moduleContent
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.42
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.34

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.6

                                        Rectangle {
                                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.45
                                            Layout.preferredHeight: Layout.preferredWidth
                                            radius: ScreenTools.defaultFontPixelHeight * 0.48
                                            color: _summaryRoot._statusBadgeColor(moduleSummaryPanel.vehicleComponent)
                                            border.width: 1
                                            border.color: _summaryRoot._cardBorderColor

                                            QGCColoredImage {
                                                anchors.centerIn: parent
                                                width: _summaryRoot._statusGlyphSize * 0.9
                                                height: width
                                                source: _summaryRoot._statusBadgeIcon(moduleSummaryPanel.vehicleComponent)
                                                fillMode: Image.PreserveAspectFit
                                                color: "white"
                                            }
                                        }

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: _summaryRoot._componentTitle(moduleSummaryPanel.summaryComponent)
                                            font.pointSize: ScreenTools.defaultFontPointSize * 1.02
                                            font.bold: true
                                            color: _summaryRoot._cardPrimaryTextColor
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 1.15
                                            Layout.preferredHeight: Layout.preferredWidth
                                            radius: Layout.preferredWidth / 2
                                            visible: !!moduleSummaryPanel.summaryComponent
                                            color: _summaryRoot._componentStatusColor(moduleSummaryPanel.summaryComponent)
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: _summaryRoot._cardBorderColor
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.12

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: _summaryRoot._moduleCheckValue(moduleSummaryPanel.summaryComponent)
                                            font.bold: true
                                            color: _summaryRoot._cardPrimaryTextColor
                                            font.pointSize: ScreenTools.defaultFontPointSize * 1.02
                                            elide: Text.ElideRight
                                        }

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: _summaryRoot._moduleCheckDetail(moduleSummaryPanel.summaryComponent)
                                            color: _summaryRoot._cardSecondaryTextColor
                                            font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
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

    Rectangle {
        visible: _summaryRoot._healthDetailsVisible
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.48)
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: _summaryRoot._healthDetailsVisible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - (_summaryRoot._pageMargins * 2), ScreenTools.defaultFontPixelWidth * 72)
            height: Math.min(parent.height - (_summaryRoot._pageMargins * 2), detailsColumn.implicitHeight + (_summaryRoot._cardPadding * 2))
            radius: _summaryRoot._cardCornerRadius
            color: _summaryRoot._cardBaseColor
            border.width: 1
            border.color: _summaryRoot._cardBorderColor

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: detailsColumn
                anchors.fill: parent
                anchors.margins: _summaryRoot._cardPadding
                spacing: ScreenTools.defaultFontPixelHeight * 0.55

                RowLayout {
                    Layout.fillWidth: true

                    QGCLabel {
                        Layout.fillWidth: true
                        text: qsTr("健康与解锁报告")
                        font.bold: true
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.16
                        color: _summaryRoot._cardPrimaryTextColor
                    }

                    QGCButton {
                        text: qsTr("关闭")
                        onClicked: _summaryRoot._healthDetailsVisible = false
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text: _summaryRoot._healthStateSummary()
                    color: _summaryRoot._cardSecondaryTextColor
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: _summaryRoot._cardBorderColor
                }

                QGCFlickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(
                        ScreenTools.defaultFontPixelHeight * 22,
                        Math.max(ScreenTools.defaultFontPixelHeight * 4, healthProblemColumn.implicitHeight))
                    contentWidth: width
                    contentHeight: healthProblemColumn.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: healthProblemColumn
                        width: parent.width
                        spacing: ScreenTools.defaultFontPixelHeight * 0.4

                        QGCLabel {
                            Layout.fillWidth: true
                            visible: _summaryRoot._healthProblemCount() === 0
                            text: qsTr("当前报告没有返回具体阻止项。")
                            color: _summaryRoot._cardSecondaryTextColor
                            wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: _summaryRoot._healthProblems()

                            Rectangle {
                                required property var object
                                Layout.fillWidth: true
                                implicitHeight: problemContent.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.6
                                radius: _summaryRoot._cardCornerRadius * 0.6
                                color: "#252525"
                                border.width: 1
                                border.color: _summaryRoot._cardBorderColor

                                ColumnLayout {
                                    id: problemContent
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.35
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.18

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Rectangle {
                                            Layout.alignment: Qt.AlignVCenter
                                            implicitWidth: ScreenTools.defaultFontPixelHeight * 0.62
                                            implicitHeight: implicitWidth
                                            radius: width / 2
                                            color: object.severity === "error"
                                                ? _summaryRoot._cardDangerColor
                                                : (object.severity === "warning" ? _summaryRoot._cardWarningColor : _summaryRoot._cardSuccessColor)
                                        }

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: _summaryRoot._translatedHealthText(object.message)
                                            color: _summaryRoot._cardPrimaryTextColor
                                            font.bold: true
                                            wrapMode: Text.WordWrap
                                        }
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        visible: object.description !== ""
                                        text: _summaryRoot._translatedHealthText(object.description)
                                        textFormat: Text.RichText
                                        color: _summaryRoot._cardSecondaryTextColor
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
