import QtQuick
import QtTest

import "../../../../src/QmlControls" as Controls

TestCase {
    id: testCase
    name: "VehicleReadinessAssessment"

    QtObject {
        id: fakeHealthReport

        property bool supported: false
        property bool canArm: true
        property bool canTakeoff: true
        property bool canStartMission: true
        property bool canResumeMission: true
        property bool hasWarningsOrErrors: false
    }

    QtObject {
        id: fakeAutopilotPlugin

        property bool setupComplete: true
    }

    QtObject {
        id: fakeVehicle

        property var healthAndArmingCheckReport: fakeHealthReport
        property bool readyToFlyAvailable: false
        property bool readyToFly: false
        property bool sysStatusReceived: false
        property int sensorsEnabledBits: 0
        property bool allSensorsHealthy: true
        property var autopilotPlugin: fakeAutopilotPlugin
        property var readiness: null
    }

    QtObject {
        id: fakeNativeReadiness

        property int source: 4
        property int armingVerdict: 0
        property int takeoffVerdict: 0
        property int missionStartVerdict: 0
        property int missionResumeVerdict: 0
        property int statusLevel: 1
        property bool healthReportSupported: false
        property bool hasHealthWarnings: false
        property bool legacyPrearmAvailable: false
        property bool legacyPrearmReady: false
        property bool sysStatusReceived: false
        property bool basicSensorStatusAvailable: false
        property bool allSensorsHealthy: true
        property bool setupComplete: true
        property bool basicReady: false
    }

    Controls.VehicleReadinessAssessment {
        id: assessment

        vehicle: fakeVehicle
    }

    function init() {
        fakeHealthReport.supported = false
        fakeHealthReport.canArm = true
        fakeHealthReport.canTakeoff = true
        fakeHealthReport.canStartMission = true
        fakeHealthReport.canResumeMission = true
        fakeHealthReport.hasWarningsOrErrors = false
        fakeVehicle.readyToFlyAvailable = false
        fakeVehicle.readyToFly = false
        fakeVehicle.sysStatusReceived = false
        fakeVehicle.sensorsEnabledBits = 0
        fakeVehicle.allSensorsHealthy = true
        fakeAutopilotPlugin.setupComplete = true
        fakeVehicle.readiness = null
    }

    function test_modernHealthReportAllowed() {
        fakeHealthReport.supported = true

        compare(assessment.source, assessment.sourceHealthReport)
        compare(assessment.armingVerdict, assessment.verdictAllowed)
        compare(assessment.statusLevel, assessment.statusReady)
    }

    function test_modernHealthReportBlocked() {
        fakeHealthReport.supported = true
        fakeHealthReport.canArm = false

        compare(assessment.source, assessment.sourceHealthReport)
        compare(assessment.armingVerdict, assessment.verdictDenied)
        compare(assessment.statusLevel, assessment.statusBlocked)
    }

    function test_modernHealthReportWarning() {
        fakeHealthReport.supported = true
        fakeHealthReport.hasWarningsOrErrors = true

        compare(assessment.statusLevel, assessment.statusAttention)
    }

    function test_nativeWaitingHealthReport() {
        fakeVehicle.readiness = fakeNativeReadiness

        compare(assessment.source, assessment.sourceWaitingForHealthReport)
        compare(assessment.armingVerdict, assessment.verdictUnknown)
        compare(assessment.takeoffVerdict, assessment.verdictUnknown)
        compare(assessment.missionStartVerdict, assessment.verdictUnknown)
        compare(assessment.missionResumeVerdict, assessment.verdictUnknown)
        compare(assessment.statusLevel, assessment.statusAttention)
    }

    function test_legacyPrearmReady() {
        fakeVehicle.readyToFlyAvailable = true
        fakeVehicle.readyToFly = true

        compare(assessment.source, assessment.sourceLegacyPrearm)
        compare(assessment.armingVerdict, assessment.verdictUnknown)
        compare(assessment.statusLevel, assessment.statusAttention)
    }

    function test_legacyPrearmNotReady() {
        fakeVehicle.readyToFlyAvailable = true

        compare(assessment.source, assessment.sourceLegacyPrearm)
        compare(assessment.armingVerdict, assessment.verdictDenied)
        compare(assessment.statusLevel, assessment.statusBlocked)
    }

    function test_basicFallbackWithoutSysStatus() {
        compare(assessment.source, assessment.sourceBasicFallback)
        compare(assessment.armingVerdict, assessment.verdictUnknown)
        compare(assessment.statusLevel, assessment.statusAttention)
        verify(!assessment.sysStatusReceived)
        verify(!assessment.basicSensorStatusAvailable)
        verify(!assessment.basicReady)
    }

    function test_basicFallbackWithoutEvaluableSensors() {
        fakeVehicle.sysStatusReceived = true

        compare(assessment.source, assessment.sourceBasicFallback)
        compare(assessment.statusLevel, assessment.statusAttention)
        verify(assessment.sysStatusReceived)
        verify(!assessment.basicSensorStatusAvailable)
        verify(!assessment.basicReady)
    }

    function test_basicFallbackHealthySensorsRemainUnconfirmed() {
        fakeVehicle.sysStatusReceived = true
        fakeVehicle.sensorsEnabledBits = 1

        compare(assessment.source, assessment.sourceBasicFallback)
        compare(assessment.statusLevel, assessment.statusAttention)
        verify(assessment.basicSensorStatusAvailable)
        verify(assessment.basicSensorsHealthy)
        verify(assessment.basicReady)
    }

    function test_basicFallbackIncomplete() {
        fakeVehicle.sysStatusReceived = true
        fakeVehicle.sensorsEnabledBits = 1
        fakeVehicle.allSensorsHealthy = false

        compare(assessment.source, assessment.sourceBasicFallback)
        compare(assessment.statusLevel, assessment.statusAttention)
        verify(!assessment.basicReady)
    }
}
