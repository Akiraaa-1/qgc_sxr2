#include "VehicleReadinessTest.h"

#include <QtCore/QRegularExpression>

#include "MAVLinkLib.h"
#include "MockLink.h"
#include "Vehicle.h"
#include "VehicleReadiness.h"

namespace {
void sendLegacyPrearmStatus(MockLink* mockLink, Vehicle* vehicle, bool readyToFly)
{
    QVERIFY(mockLink);
    QVERIFY(vehicle);

    mavlink_message_t msg{};
    (void) mavlink_msg_sys_status_pack_chan(
        static_cast<uint8_t>(vehicle->id()),
        static_cast<uint8_t>(vehicle->defaultComponentId()),
        static_cast<uint8_t>(mockLink->mavlinkChannel()),
        &msg,
        MAV_SYS_STATUS_SENSOR_GPS | MAV_SYS_STATUS_PREARM_CHECK,
        MAV_SYS_STATUS_PREARM_CHECK,
        readyToFly ? static_cast<uint32_t>(MAV_SYS_STATUS_PREARM_CHECK) : 0U,
        250,
        4200 * 4,
        8000,
        90,
        0, 0, 0, 0, 0, 0, 0, 0, 0);

    mockLink->respondWithMavlinkMessage(msg);
}
}

void VehicleReadinessTest::_legacyFallbackRequiresExplicitConfirmation()
{
    Vehicle* const testVehicle = vehicle();
    QVERIFY(testVehicle);
    QVERIFY(testVehicle->readiness());

    QVERIFY_TRUE_WAIT(testVehicle->sysStatusReceived(), TestTimeout::mediumMs());
    QCOMPARE(testVehicle->readiness()->source(), VehicleReadiness::SourceBasicFallback);
    QCOMPARE(testVehicle->readiness()->armingVerdict(), VehicleReadiness::VerdictUnknown);
    QVERIFY(testVehicle->readiness()->canRequestArm());
    QVERIFY(testVehicle->readiness()->armConfirmationRequired());
    QCOMPARE(testVehicle->readiness()->takeoffVerdict(), VehicleReadiness::VerdictUnknown);
    QCOMPARE(testVehicle->readiness()->missionStartVerdict(), VehicleReadiness::VerdictUnknown);
    QCOMPARE(testVehicle->readiness()->missionResumeVerdict(), VehicleReadiness::VerdictUnknown);
    QVERIFY(testVehicle->readiness()->canRequestTakeoff());
    QVERIFY(testVehicle->readiness()->canRequestMissionStart());
    QVERIFY(testVehicle->readiness()->canRequestMissionResume());
    QVERIFY(testVehicle->readiness()->takeoffConfirmationRequired());
    QVERIFY(testVehicle->readiness()->missionStartConfirmationRequired());
    QVERIFY(testVehicle->readiness()->missionResumeConfirmationRequired());

    mockLink()->clearReceivedMavCommandCounts();

    expectLogMessage(QtDebugMsg, QRegularExpression(QStringLiteral("not provided an explicit arming decision")));
    QVERIFY(!testVehicle->requestArm(false));
    QCOMPARE(mockLink()->receivedMavCommandCount(MAV_CMD_COMPONENT_ARM_DISARM), 0);

    QVERIFY(testVehicle->requestArm(true));
    QVERIFY_TRUE_WAIT(mockLink()->receivedMavCommandCount(MAV_CMD_COMPONENT_ARM_DISARM) == 1, TestTimeout::shortMs());
    QVERIFY_TRUE_WAIT(testVehicle->armed(), TestTimeout::mediumMs());
    QCOMPARE(testVehicle->readiness()->armRequestState(), VehicleReadiness::ArmRequestConfirmed);

    testVehicle->setArmed(false, true);
    QVERIFY_TRUE_WAIT(!testVehicle->armed(), TestTimeout::mediumMs());
}

void VehicleReadinessTest::_legacyPrearmNotReadyBlocksArmingAndLaunchActions()
{
    Vehicle* const testVehicle = vehicle();
    QVERIFY(testVehicle);
    QVERIFY(testVehicle->readiness());

    sendLegacyPrearmStatus(mockLink(), testVehicle, false);
    QVERIFY_TRUE_WAIT(testVehicle->readiness()->source() == VehicleReadiness::SourceLegacyPrearm, TestTimeout::mediumMs());
    QVERIFY(testVehicle->readiness()->legacyPrearmAvailable());
    QVERIFY(!testVehicle->readiness()->legacyPrearmReady());
    QCOMPARE(testVehicle->readiness()->armingVerdict(), VehicleReadiness::VerdictDenied);
    QCOMPARE(testVehicle->readiness()->statusLevel(), VehicleReadiness::StatusBlocked);
    QVERIFY(!testVehicle->readiness()->canRequestArm());
    QVERIFY(!testVehicle->readiness()->armConfirmationRequired());
    QVERIFY(!testVehicle->readiness()->canRequestTakeoff());
    QVERIFY(!testVehicle->readiness()->canRequestMissionStart());
    QVERIFY(!testVehicle->readiness()->canRequestMissionResume());

    mockLink()->clearReceivedMavCommandCounts();
    QVERIFY(!testVehicle->requestArm(false));
    QVERIFY(!testVehicle->requestArm(true));
    QVERIFY(!testVehicle->requestTakeoff(10.0, true));
    QVERIFY(!testVehicle->requestStartMission(true));
    QVERIFY(!testVehicle->requestAirborneMissionResume(true));
    QCOMPARE(mockLink()->receivedMavCommandCount(MAV_CMD_COMPONENT_ARM_DISARM), 0);
    QVERIFY(!testVehicle->armed());
}

void VehicleReadinessTest::_legacyPrearmReadyAllowsConfirmedLaunchActions()
{
    Vehicle* const testVehicle = vehicle();
    QVERIFY(testVehicle);
    QVERIFY(testVehicle->readiness());

    sendLegacyPrearmStatus(mockLink(), testVehicle, true);
    QVERIFY_TRUE_WAIT(testVehicle->readiness()->source() == VehicleReadiness::SourceLegacyPrearm, TestTimeout::mediumMs());
    QVERIFY(testVehicle->readiness()->legacyPrearmAvailable());
    QVERIFY(testVehicle->readiness()->legacyPrearmReady());
    QCOMPARE(testVehicle->readiness()->armingVerdict(), VehicleReadiness::VerdictUnknown);
    QCOMPARE(testVehicle->readiness()->statusLevel(), VehicleReadiness::StatusAttention);
    QVERIFY(testVehicle->readiness()->canRequestArm());
    QVERIFY(testVehicle->readiness()->armConfirmationRequired());
    QVERIFY(testVehicle->readiness()->canRequestTakeoff());
    QVERIFY(testVehicle->readiness()->canRequestMissionStart());
    QVERIFY(testVehicle->readiness()->canRequestMissionResume());
    QVERIFY(testVehicle->readiness()->takeoffConfirmationRequired());
    QVERIFY(testVehicle->readiness()->missionStartConfirmationRequired());
    QVERIFY(testVehicle->readiness()->missionResumeConfirmationRequired());

    mockLink()->clearReceivedMavCommandCounts();
    QVERIFY(!testVehicle->requestTakeoff(10.0, false));
    QVERIFY(!testVehicle->requestStartMission(false));
    QVERIFY(!testVehicle->requestAirborneMissionResume(false));
    QCOMPARE(mockLink()->receivedMavCommandCount(MAV_CMD_COMPONENT_ARM_DISARM), 0);

    QVERIFY(testVehicle->requestArm(true));
    QVERIFY_TRUE_WAIT(mockLink()->receivedMavCommandCount(MAV_CMD_COMPONENT_ARM_DISARM) == 1, TestTimeout::shortMs());
    QVERIFY_TRUE_WAIT(testVehicle->armed(), TestTimeout::mediumMs());

    testVehicle->setArmed(false, true);
    QVERIFY_TRUE_WAIT(!testVehicle->armed(), TestTimeout::mediumMs());
}

void VehicleReadinessTest::_waitingForHealthReportAllowsConfirmedLaunchActions()
{
    Vehicle* const testVehicle = vehicle();
    QVERIFY(testVehicle);
    QVERIFY(testVehicle->readiness());

    QVERIFY_TRUE_WAIT(testVehicle->isInitialConnectComplete(), TestTimeout::mediumMs());
    testVehicle->healthAndArmingCheckReport()->setHealthAndArmingChecksCapability(true);
    QVERIFY_TRUE_WAIT(testVehicle->readiness()->source() == VehicleReadiness::SourceWaitingForHealthReport, TestTimeout::shortMs());

    QCOMPARE(testVehicle->readiness()->statusLevel(), VehicleReadiness::StatusAttention);
    QCOMPARE(testVehicle->readiness()->armingVerdict(), VehicleReadiness::VerdictUnknown);
    QCOMPARE(testVehicle->readiness()->missionStartVerdict(), VehicleReadiness::VerdictUnknown);
    QVERIFY(testVehicle->readiness()->canRequestArm());
    QVERIFY(testVehicle->readiness()->canRequestTakeoff());
    QVERIFY(testVehicle->readiness()->canRequestMissionStart());
    QVERIFY(testVehicle->readiness()->canRequestMissionResume());
    QVERIFY(testVehicle->readiness()->armConfirmationRequired());
    QVERIFY(testVehicle->readiness()->takeoffConfirmationRequired());
    QVERIFY(testVehicle->readiness()->missionStartConfirmationRequired());
    QVERIFY(testVehicle->readiness()->missionResumeConfirmationRequired());

    mockLink()->clearReceivedMavCommandCounts();
    mockLink()->clearReceivedMavlinkMessageCounts();
    expectLogMessage(QtDebugMsg, QRegularExpression(QStringLiteral("has not provided a current mission start decision")));
    QVERIFY(!testVehicle->requestStartMission(false));
    QCOMPARE(mockLink()->receivedMavCommandCount(MAV_CMD_DO_SET_MODE), 0);
    QCOMPARE(mockLink()->receivedMavlinkMessageCount(MAVLINK_MSG_ID_SET_MODE), 0);
    QVERIFY(testVehicle->requestStartMission(true));
    QVERIFY_TRUE_WAIT(
        mockLink()->receivedMavCommandCount(MAV_CMD_DO_SET_MODE) > 0
        || mockLink()->receivedMavlinkMessageCount(MAVLINK_MSG_ID_SET_MODE) > 0,
        TestTimeout::shortMs());
}

UT_REGISTER_TEST(VehicleReadinessTest, TestLabel::Integration, TestLabel::Vehicle)
