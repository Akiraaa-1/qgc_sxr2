#include "VehiclePlanSessionManagerTest.h"

#include <QtTest/QSignalSpy>

#include "MultiVehicleManager.h"
#include "LinkManager.h"
#include "MockLink.h"
#include "MissionController.h"
#include "PlanMasterController.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"
#include "VehiclePlanSessionManager.h"

#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QTemporaryDir>
#include <QtPositioning/QGeoCoordinate>

void VehiclePlanSessionManagerTest::_testSessionIsolationAndOperationTokens()
{
    MultiVehicleManager* const multiVehicleManager = MultiVehicleManager::instance();
    multiVehicleManager->init();

    Vehicle* const firstVehicle = createVehicle(128);
    Vehicle* const secondVehicle = createVehicle(129);
    QVERIFY(firstVehicle);
    QVERIFY(secondVehicle);

    setActiveVehicle(firstVehicle);
    QVERIFY_TRUE_WAIT(multiVehicleManager->activeVehicle() == firstVehicle, TestTimeout::mediumMs());

    VehiclePlanSessionManager* const sessionManager = multiVehicleManager->planSessionManager();
    QVERIFY(sessionManager);
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicle() == firstVehicle, TestTimeout::mediumMs());

    PlanMasterController* const firstController = sessionManager->activeController();
    const QString firstSessionId = sessionManager->activeSessionId();
    QVERIFY(firstController);
    QVERIFY(!firstSessionId.isEmpty());
    QCOMPARE(firstController->boundVehicle(), firstVehicle);

    const QVariantMap firstToken = sessionManager->makeOperationToken();
    QVERIFY(!firstToken.isEmpty());

    setActiveVehicle(secondVehicle);
    QVERIFY_TRUE_WAIT(multiVehicleManager->activeVehicle() == secondVehicle, TestTimeout::mediumMs());
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicle() == secondVehicle, TestTimeout::mediumMs());

    PlanMasterController* const secondController = sessionManager->activeController();
    QVERIFY(secondController);
    QVERIFY(secondController != firstController);
    QCOMPARE(secondController->boundVehicle(), secondVehicle);
    QVERIFY(!sessionManager->tokenStillCurrent(firstToken));

    QSignalSpy operationRejectedSpy(sessionManager, &VehiclePlanSessionManager::operationRejected);
    QVERIFY(operationRejectedSpy.isValid());
    QVERIFY(!sessionManager->sendToVehicleWithToken(firstToken));
    QCOMPARE(operationRejectedSpy.count(), 1);
    QVERIFY(!sessionManager->removeAllWithToken(firstToken));
    QCOMPARE(operationRejectedSpy.count(), 2);
    QVERIFY(!sessionManager->removeMissionFromVehicleWithToken(firstToken));
    QCOMPARE(operationRejectedSpy.count(), 3);

    setActiveVehicle(firstVehicle);
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicle() == firstVehicle, TestTimeout::mediumMs());
    QCOMPARE(sessionManager->activeController(), firstController);
    QCOMPARE(sessionManager->activeSessionId(), firstSessionId);
    QCOMPARE(sessionManager->activeController()->boundVehicle(), firstVehicle);
}

void VehiclePlanSessionManagerTest::_testTemporaryVehicleIdentityBlocksMutation()
{
    constexpr quint64 stableUid = 9000000000000001ULL;

    MultiVehicleManager* const multiVehicleManager = MultiVehicleManager::instance();
    multiVehicleManager->init();

    Vehicle* const vehicle = createVehicle(130);
    QVERIFY(vehicle);
    QVERIFY_TRUE_WAIT(vehicle->isInitialConnectComplete(), TestTimeout::longMs());

    setActiveVehicle(vehicle);
    QVERIFY_TRUE_WAIT(multiVehicleManager->activeVehicle() == vehicle, TestTimeout::mediumMs());

    VehiclePlanSessionManager* const sessionManager = multiVehicleManager->planSessionManager();
    QVERIFY(sessionManager);
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicle() == vehicle, TestTimeout::mediumMs());

    vehicle->setVehicleUIDUnitTest(0);
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("TemporaryIdentity"), TestTimeout::mediumMs());

    QSignalSpy operationRejectedSpy(sessionManager, &VehiclePlanSessionManager::operationRejected);
    QVERIFY(operationRejectedSpy.isValid());
    const QVariantMap temporaryIdentityToken = sessionManager->makeOperationToken();
    QVERIFY(!sessionManager->sendToVehicleWithToken(temporaryIdentityToken));
    QCOMPARE(operationRejectedSpy.count(), 1);

    vehicle->setVehicleUIDUnitTest(stableUid);
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("VerifiedIdentity"), TestTimeout::mediumMs());
    const QVariantMap stableIdentityToken = sessionManager->makeOperationToken();
    QCOMPARE(stableIdentityToken.value(QStringLiteral("vehicleUid")).toString(), QString::number(stableUid));
    QVERIFY(sessionManager->tokenStillCurrent(stableIdentityToken));
    QVERIFY(sessionManager->removeAllWithToken(temporaryIdentityToken));
    QCOMPARE(operationRejectedSpy.count(), 1);
}

void VehiclePlanSessionManagerTest::_testPlanIdentityMismatchBlocksMutation()
{
    constexpr quint64 vehicleUid = 9000000000000002ULL;
    constexpr quint64 planUid = 9000000000000003ULL;

    MultiVehicleManager* const multiVehicleManager = MultiVehicleManager::instance();
    multiVehicleManager->init();

    Vehicle* const vehicle = createVehicle(131);
    QVERIFY(vehicle);
    QVERIFY_TRUE_WAIT(vehicle->isInitialConnectComplete(), TestTimeout::longMs());

    setActiveVehicle(vehicle);
    QVERIFY_TRUE_WAIT(multiVehicleManager->activeVehicle() == vehicle, TestTimeout::mediumMs());

    VehiclePlanSessionManager* const sessionManager = multiVehicleManager->planSessionManager();
    QVERIFY(sessionManager);
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicle() == vehicle, TestTimeout::mediumMs());

    PlanMasterController* const controller = sessionManager->activeController();
    QVERIFY(controller);
    QCOMPARE(controller->boundVehicle(), vehicle);
    vehicle->setVehicleUIDUnitTest(vehicleUid);
    QCOMPARE(vehicle->vehicleUID(), vehicleUid);

    QJsonObject planJson = controller->saveToJson().object();
    const QJsonObject savedBtfwJson = planJson.value(QStringLiteral("btfw")).toObject();
    QCOMPARE(savedBtfwJson.value(QStringLiteral("identityVersion")).toInt(), 1);
    QCOMPARE(savedBtfwJson.value(QStringLiteral("vehicleUid")).toString(), QString::number(vehicleUid));

    QJsonObject btfwJson;
    btfwJson[QStringLiteral("identityVersion")] = 1;
    btfwJson[QStringLiteral("vehicleUid")] = QString::number(planUid);
    planJson[QStringLiteral("btfw")] = btfwJson;

    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    const QString planFile = tempDir.filePath(QStringLiteral("identity-mismatch.plan"));
    QFile file(planFile);
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
    const QByteArray planData = QJsonDocument(planJson).toJson();
    QCOMPARE(file.write(planData), qint64(planData.size()));
    file.close();

    controller->loadFromFile(planFile);
    QVERIFY(controller->planVehicleIdentityAvailable());
    QCOMPARE(controller->planVehicleUid(), planUid);
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("IdentityMismatch"), TestTimeout::mediumMs());

    QSignalSpy operationRejectedSpy(sessionManager, &VehiclePlanSessionManager::operationRejected);
    QVERIFY(operationRejectedSpy.isValid());
    QVERIFY(!sessionManager->removeAllFromVehicleWithToken(sessionManager->makeOperationToken()));
    QCOMPARE(operationRejectedSpy.count(), 1);
    QVERIFY(!sessionManager->removeMissionFromVehicleWithToken(sessionManager->makeOperationToken()));
    QCOMPARE(operationRejectedSpy.count(), 2);
}

void VehiclePlanSessionManagerTest::_testDuplicateVehicleIdentityBlocksMutation()
{
    constexpr quint64 duplicateUid = 9000000000000004ULL;

    MultiVehicleManager* const multiVehicleManager = MultiVehicleManager::instance();
    multiVehicleManager->init();

    Vehicle* const firstVehicle = createVehicle(132);
    Vehicle* const secondVehicle = createVehicle(133);
    QVERIFY(firstVehicle);
    QVERIFY(secondVehicle);
    QVERIFY_TRUE_WAIT(firstVehicle->isInitialConnectComplete(), TestTimeout::longMs());
    QVERIFY_TRUE_WAIT(secondVehicle->isInitialConnectComplete(), TestTimeout::longMs());

    firstVehicle->setVehicleUIDUnitTest(duplicateUid);
    secondVehicle->setVehicleUIDUnitTest(duplicateUid);

    setActiveVehicle(firstVehicle);
    QVERIFY_TRUE_WAIT(multiVehicleManager->activeVehicle() == firstVehicle, TestTimeout::mediumMs());

    VehiclePlanSessionManager* const sessionManager = multiVehicleManager->planSessionManager();
    QVERIFY(sessionManager);
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicle() == firstVehicle, TestTimeout::mediumMs());

    setActiveVehicle(secondVehicle);
    QVERIFY_TRUE_WAIT(multiVehicleManager->activeVehicle() == secondVehicle, TestTimeout::mediumMs());
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("Conflict"), TestTimeout::mediumMs());

    QSignalSpy operationRejectedSpy(sessionManager, &VehiclePlanSessionManager::operationRejected);
    QVERIFY(operationRejectedSpy.isValid());
    QVERIFY(!sessionManager->sendToVehicleWithToken(sessionManager->makeOperationToken()));
    QCOMPARE(operationRejectedSpy.count(), 1);

    setActiveVehicle(firstVehicle);
    QVERIFY_TRUE_WAIT(multiVehicleManager->activeVehicle() == firstVehicle, TestTimeout::mediumMs());
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("Conflict"), TestTimeout::mediumMs());
    QVERIFY(!sessionManager->removeAllFromVehicleWithToken(sessionManager->makeOperationToken()));
    QCOMPARE(operationRejectedSpy.count(), 2);
    QVERIFY(!sessionManager->removeMissionFromVehicleWithToken(sessionManager->makeOperationToken()));
    QCOMPARE(operationRejectedSpy.count(), 3);

    secondVehicle->setVehicleUIDUnitTest(duplicateUid + 1);
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("VerifiedIdentity"), TestTimeout::mediumMs());
}

void VehiclePlanSessionManagerTest::_testRemoteUnknownBlocksUploadButAllowsMissionClearRecovery()
{
    constexpr quint64 vehicleUid = 9000000000000007ULL;

    MultiVehicleManager* const multiVehicleManager = MultiVehicleManager::instance();
    multiVehicleManager->init();

    Vehicle* const vehicle = createVehicle(134);
    QVERIFY(vehicle);
    QVERIFY_TRUE_WAIT(vehicle->isInitialConnectComplete(), TestTimeout::longMs());

    setActiveVehicle(vehicle);
    QVERIFY_TRUE_WAIT(multiVehicleManager->activeVehicle() == vehicle, TestTimeout::mediumMs());

    VehiclePlanSessionManager* const sessionManager = multiVehicleManager->planSessionManager();
    QVERIFY(sessionManager);
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicle() == vehicle, TestTimeout::mediumMs());

    vehicle->setVehicleUIDUnitTest(vehicleUid);
    QCOMPARE(vehicle->vehicleUID(), vehicleUid);
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicleUid() == vehicleUid, TestTimeout::mediumMs());

    PlanMasterController* const controller = sessionManager->activeController();
    QVERIFY(controller);
    QVERIFY_TRUE_WAIT(!controller->syncInProgress(), TestTimeout::longMs());
    controller->_setPlanVehicleIdentity(false, 0);
    controller->_setRemotePlanStateKnown(true);
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("VerifiedIdentity"), TestTimeout::mediumMs());

    controller->_setRemotePlanStateKnown(false);
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("RemoteStateUnknown"), TestTimeout::mediumMs());

    QSignalSpy operationRejectedSpy(sessionManager, &VehiclePlanSessionManager::operationRejected);
    QVERIFY(operationRejectedSpy.isValid());
    QVERIFY(!sessionManager->sendToVehicleWithToken(sessionManager->makeOperationToken()));
    QCOMPARE(operationRejectedSpy.count(), 1);
    QVERIFY(!controller->syncInProgress());

    QVERIFY(sessionManager->removeMissionFromVehicleWithToken(sessionManager->makeOperationToken()));
    QVERIFY_TRUE_WAIT(controller->removeMissionFromVehicleInProgress(), TestTimeout::mediumMs());
    QVERIFY_TRUE_WAIT(!controller->removeMissionFromVehicleInProgress(), TestTimeout::longMs());
    QVERIFY(controller->remotePlanStateKnown());
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("VerifiedIdentity"), TestTimeout::mediumMs());
    QCOMPARE(operationRejectedSpy.count(), 1);
}

void VehiclePlanSessionManagerTest::_testCommunicationLossBlocksVehicleMutation()
{
    constexpr quint64 vehicleUid = 9000000000000008ULL;

    MultiVehicleManager* const multiVehicleManager = MultiVehicleManager::instance();
    multiVehicleManager->init();

    Vehicle* const vehicle = createVehicle(135);
    QVERIFY(vehicle);
    QVERIFY_TRUE_WAIT(vehicle->isInitialConnectComplete(), TestTimeout::longMs());

    setActiveVehicle(vehicle);
    QVERIFY_TRUE_WAIT(multiVehicleManager->activeVehicle() == vehicle, TestTimeout::mediumMs());

    VehiclePlanSessionManager* const sessionManager = multiVehicleManager->planSessionManager();
    QVERIFY(sessionManager);
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicle() == vehicle, TestTimeout::mediumMs());

    vehicle->setVehicleUIDUnitTest(vehicleUid);
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicleUid() == vehicleUid, TestTimeout::mediumMs());

    PlanMasterController* const controller = sessionManager->activeController();
    QVERIFY(controller);
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("VerifiedIdentity"), TestTimeout::mediumMs());
    QVERIFY(sessionManager->activeSessionConnected());

    const QList<SharedLinkInterfacePtr> links = LinkManager::instance()->links();
    QVERIFY(!links.isEmpty());
    MockLink* const mockLink = qobject_cast<MockLink*>(links.last().get());
    QVERIFY(mockLink);

    QSignalSpy communicationLostSpy(vehicle->vehicleLinkManager(), &VehicleLinkManager::communicationLostChanged);
    QVERIFY(communicationLostSpy.isValid());
    mockLink->setCommLost(true);
    QVERIFY_SIGNAL_WAIT(communicationLostSpy, VehicleLinkManager::kTestCommLostDetectionTimeoutMs);
    QVERIFY_TRUE_WAIT(vehicle->vehicleLinkManager()->communicationLost(), TestTimeout::mediumMs());
    QVERIFY_TRUE_WAIT(!sessionManager->activeSessionConnected(), TestTimeout::mediumMs());
    QCOMPARE(sessionManager->activeIdentityState(), QStringLiteral("Disconnected"));

    const QVariantMap disconnectedToken = sessionManager->makeOperationToken();
    QCOMPARE(disconnectedToken.value(QStringLiteral("connected")).toBool(), false);

    QSignalSpy operationRejectedSpy(sessionManager, &VehiclePlanSessionManager::operationRejected);
    QVERIFY(operationRejectedSpy.isValid());
    QVERIFY(!sessionManager->sendToVehicleWithToken(disconnectedToken));
    QVERIFY(!sessionManager->loadFromVehicleWithToken(disconnectedToken));
    QVERIFY(!sessionManager->removeMissionFromVehicleWithToken(disconnectedToken));
    QVERIFY(!sessionManager->removeAllFromVehicleWithToken(disconnectedToken));
    QCOMPARE(operationRejectedSpy.count(), 4);

    communicationLostSpy.clear();
    mockLink->setCommLost(false);
    QVERIFY_SIGNAL_WAIT(communicationLostSpy, VehicleLinkManager::kTestCommLostDetectionTimeoutMs);
    QVERIFY_TRUE_WAIT(!vehicle->vehicleLinkManager()->communicationLost(), TestTimeout::mediumMs());
    QVERIFY_TRUE_WAIT(sessionManager->activeSessionConnected(), TestTimeout::mediumMs());
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("VerifiedIdentity"), TestTimeout::mediumMs());
    QCOMPARE(controller->boundVehicle(), vehicle);
}

void VehiclePlanSessionManagerTest::_testUidConfirmationKeepsDirtyTemporarySession()
{
    constexpr quint64 stableUid = 9000000000000009ULL;

    MultiVehicleManager* const multiVehicleManager = MultiVehicleManager::instance();
    multiVehicleManager->init();

    Vehicle* const originalVehicle = createVehicle(136);
    QVERIFY(originalVehicle);
    QVERIFY_TRUE_WAIT(originalVehicle->isInitialConnectComplete(), TestTimeout::longMs());

    setActiveVehicle(originalVehicle);
    QVERIFY_TRUE_WAIT(multiVehicleManager->activeVehicle() == originalVehicle, TestTimeout::mediumMs());

    VehiclePlanSessionManager* const sessionManager = multiVehicleManager->planSessionManager();
    QVERIFY(sessionManager);
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicle() == originalVehicle, TestTimeout::mediumMs());

    originalVehicle->setVehicleUIDUnitTest(stableUid);
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicleUid() == stableUid, TestTimeout::mediumMs());
    PlanMasterController* const detachedUidController = sessionManager->activeController();
    QVERIFY(detachedUidController);

    disconnectAllVehicles();
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicle() == nullptr, TestTimeout::mediumMs());
    QCOMPARE(detachedUidController->boundVehicle(), nullptr);

    Vehicle* const reconnectingVehicle = createVehicle(137);
    QVERIFY(reconnectingVehicle);
    QVERIFY_TRUE_WAIT(reconnectingVehicle->isInitialConnectComplete(), TestTimeout::longMs());
    reconnectingVehicle->setVehicleUIDUnitTest(0);

    setActiveVehicle(reconnectingVehicle);
    QVERIFY_TRUE_WAIT(multiVehicleManager->activeVehicle() == reconnectingVehicle, TestTimeout::mediumMs());
    QVERIFY_TRUE_WAIT(sessionManager->activeVehicle() == reconnectingVehicle, TestTimeout::mediumMs());
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("TemporaryIdentity"), TestTimeout::mediumMs());

    PlanMasterController* const temporaryController = sessionManager->activeController();
    QVERIFY(temporaryController);
    QVERIFY(temporaryController != detachedUidController);
    const QString temporarySessionId = sessionManager->activeSessionId();

    temporaryController->missionController()->insertSimpleMissionItem(QGeoCoordinate(47.0, 8.0, 50.0), 1);
    QVERIFY(temporaryController->dirtyForSave());
    QVERIFY(temporaryController->dirtyForUpload());
    QVERIFY(temporaryController->missionController()->containsItems());

    reconnectingVehicle->setVehicleUIDUnitTest(stableUid);
    QVERIFY_TRUE_WAIT(sessionManager->activeController() == temporaryController, TestTimeout::mediumMs());
    QCOMPARE(sessionManager->activeSessionId(), temporarySessionId);
    QCOMPARE(sessionManager->activeVehicle(), reconnectingVehicle);
    QCOMPARE(sessionManager->activeVehicleUid(), stableUid);
    QCOMPARE(temporaryController->boundVehicle(), reconnectingVehicle);
    QVERIFY(temporaryController->missionController()->containsItems());
    QVERIFY_TRUE_WAIT(sessionManager->activeIdentityState() == QStringLiteral("VerifiedIdentity"), TestTimeout::mediumMs());
    QCOMPARE(detachedUidController->boundVehicle(), nullptr);
}

UT_REGISTER_TEST(VehiclePlanSessionManagerTest, TestLabel::Integration, TestLabel::Vehicle, TestLabel::MissionManager)
