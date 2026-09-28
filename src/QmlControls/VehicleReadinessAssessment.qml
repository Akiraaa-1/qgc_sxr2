import QtQml

QtObject {
    id: root

    readonly property int sourceUnavailable:    0
    readonly property int sourceHealthReport:   1
    readonly property int sourceLegacyPrearm:   2
    readonly property int sourceBasicFallback:  3
    readonly property int sourceWaitingForHealthReport: 4

    readonly property int verdictUnknown: 0
    readonly property int verdictAllowed: 1
    readonly property int verdictDenied:  2

    readonly property int statusReady:     0
    readonly property int statusAttention: 1
    readonly property int statusBlocked:   2

    property var vehicle: null

    // VehicleReadiness is the authoritative implementation. The fallback keeps
    // this adapter usable in isolated QML tests with a lightweight fake vehicle.
    readonly property var _nativeReadiness: vehicle && vehicle.readiness ? vehicle.readiness : null
    readonly property var healthReport: vehicle && vehicle.healthAndArmingCheckReport
        ? vehicle.healthAndArmingCheckReport
        : null
    readonly property bool healthReportSupported: _nativeReadiness
        ? _nativeReadiness.healthReportSupported
        : !!(healthReport && healthReport.supported)
    readonly property bool hasHealthWarnings: _nativeReadiness
        ? _nativeReadiness.hasHealthWarnings
        : (healthReportSupported && !!healthReport.hasWarningsOrErrors)
    readonly property bool legacyPrearmAvailable: _nativeReadiness
        ? _nativeReadiness.legacyPrearmAvailable
        : !!(vehicle && vehicle.readyToFlyAvailable)
    readonly property bool legacyPrearmReady: _nativeReadiness
        ? _nativeReadiness.legacyPrearmReady
        : (legacyPrearmAvailable && !!vehicle.readyToFly)
    readonly property bool sysStatusReceived: _nativeReadiness
        ? _nativeReadiness.sysStatusReceived
        : !!(vehicle && vehicle.sysStatusReceived)
    readonly property int sensorsEnabledBits: vehicle && vehicle.sensorsEnabledBits !== undefined
        ? Number(vehicle.sensorsEnabledBits)
        : 0
    readonly property bool allSensorsHealthy: _nativeReadiness
        ? _nativeReadiness.allSensorsHealthy
        : !!(vehicle && vehicle.allSensorsHealthy)
    readonly property bool setupComplete: _nativeReadiness
        ? _nativeReadiness.setupComplete
        : !!(vehicle && vehicle.autopilotPlugin && vehicle.autopilotPlugin.setupComplete)
    readonly property bool basicSensorStatusAvailable: _nativeReadiness
        ? _nativeReadiness.basicSensorStatusAvailable
        : (sysStatusReceived && sensorsEnabledBits !== 0)
    readonly property bool basicSensorsHealthy: basicSensorStatusAvailable && allSensorsHealthy
    readonly property bool basicReady: _nativeReadiness
        ? _nativeReadiness.basicReady
        : (basicSensorsHealthy && setupComplete)

    readonly property int source: _nativeReadiness
        ? _nativeReadiness.source
        : (!vehicle
        ? sourceUnavailable
        : (healthReportSupported
            ? sourceHealthReport
            : (legacyPrearmAvailable ? sourceLegacyPrearm : sourceBasicFallback)))
    readonly property int armingVerdict: _nativeReadiness
        ? _nativeReadiness.armingVerdict
        : (source === sourceHealthReport
        ? (healthReport.canArm ? verdictAllowed : verdictDenied)
        : (source === sourceLegacyPrearm && !legacyPrearmReady
            ? verdictDenied
            : verdictUnknown))
    readonly property int takeoffVerdict: _nativeReadiness
        ? _nativeReadiness.takeoffVerdict
        : (source === sourceHealthReport && healthReport
            && (healthReport.takeoffCheckValid === undefined || healthReport.takeoffCheckValid)
        ? (healthReport.canTakeoff ? verdictAllowed : verdictDenied)
        : verdictUnknown)
    readonly property int missionStartVerdict: _nativeReadiness
        ? _nativeReadiness.missionStartVerdict
        : (source === sourceHealthReport && healthReport
            && (healthReport.missionStartCheckValid === undefined || healthReport.missionStartCheckValid)
        ? (healthReport.canStartMission ? verdictAllowed : verdictDenied)
        : verdictUnknown)
    readonly property int missionResumeVerdict: _nativeReadiness
        ? _nativeReadiness.missionResumeVerdict
        : (source === sourceHealthReport && healthReport
            && (healthReport.missionResumeCheckValid === undefined || healthReport.missionResumeCheckValid)
        ? (healthReport.canResumeMission ? verdictAllowed : verdictDenied)
        : verdictUnknown)
    readonly property int statusLevel: _nativeReadiness
        ? _nativeReadiness.statusLevel
        : (source === sourceUnavailable
        ? statusBlocked
        : (armingVerdict === verdictDenied
            ? statusBlocked
            : (source === sourceHealthReport
                ? (hasHealthWarnings ? statusAttention : statusReady)
                : statusAttention)))
}
