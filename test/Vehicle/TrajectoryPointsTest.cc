#include "TrajectoryPointsTest.h"

#include "MissionManager.h"
#include "TrajectoryPoints.h"
#include "Vehicle.h"

#include <QtTest/QSignalSpy>

void TrajectoryPointsTest::_armedMissionTransactionsPreserveTrajectory()
{
    TrajectoryPoints* const trajectoryPoints = vehicle()->findChild<TrajectoryPoints*>();
    MissionManager* const missionManager = vehicle()->findChild<MissionManager*>();
    QVERIFY(trajectoryPoints);
    QVERIFY(missionManager);

    mockLink()->setArmed(true);
    QVERIFY_TRUE_WAIT(vehicle()->armed(), TestTimeout::mediumMs());

    vehicle()->coordinateChanged(QGeoCoordinate(47.0, 8.0, 100.0));
    QCOMPARE(trajectoryPoints->list().count(), 1);

    missionManager->sendComplete(false);
    QCOMPARE(trajectoryPoints->list().count(), 1);

    missionManager->newMissionItemsAvailable(false);
    QCOMPARE(trajectoryPoints->list().count(), 1);
}

void TrajectoryPointsTest::_restartTrackingPreservesTrajectory()
{
    TrajectoryPoints* const trajectoryPoints = vehicle()->findChild<TrajectoryPoints*>();
    QVERIFY(trajectoryPoints);

    trajectoryPoints->start();
    vehicle()->coordinateChanged(QGeoCoordinate(47.0, 8.0, 100.0));
    QCOMPARE(trajectoryPoints->list().count(), 1);

    trajectoryPoints->stop();
    trajectoryPoints->start();
    QCOMPARE(trajectoryPoints->list().count(), 1);
}

void TrajectoryPointsTest::_missionTransactionsClearTrajectory()
{
    TrajectoryPoints* const trajectoryPoints = vehicle()->findChild<TrajectoryPoints*>();
    MissionManager* const missionManager = vehicle()->findChild<MissionManager*>();
    QVERIFY(trajectoryPoints);
    QVERIFY(missionManager);

    trajectoryPoints->start();
    const auto addPoint = [this, trajectoryPoints](double latitude) {
        vehicle()->coordinateChanged(QGeoCoordinate(latitude, 8.0, 100.0));
        QCOMPARE(trajectoryPoints->list().count(), 1);
    };

    addPoint(47.0);
    missionManager->sendComplete(false);
    QCOMPARE(trajectoryPoints->list().count(), 0);

    addPoint(47.1);
    missionManager->newMissionItemsAvailable(false);
    QCOMPARE(trajectoryPoints->list().count(), 0);
}

void TrajectoryPointsTest::_groundJitterDoesNotGrowAirborneVehicleTrack()
{
    TrajectoryPoints* const trajectoryPoints = vehicle()->findChild<TrajectoryPoints*>();
    QVERIFY(trajectoryPoints);

    trajectoryPoints->start();

    const QGeoCoordinate first(47.0000000, 8.0000000, 100.0);
    const QGeoCoordinate second(47.0000500, 8.0000000, 100.0);
    QVERIFY(first.distanceTo(second) > 2.0);

    vehicle()->coordinateChanged(first);
    QCOMPARE(trajectoryPoints->list().count(), 1);
    QCOMPARE(trajectoryPoints->list().last().value<QGeoCoordinate>(), first);

    QSignalSpy updateLastPointSpy(trajectoryPoints, &TrajectoryPoints::updateLastPoint);
    QVERIFY(updateLastPointSpy.isValid());
    vehicle()->coordinateChanged(second);
    QCOMPARE(trajectoryPoints->list().count(), 1);
    QCOMPARE(trajectoryPoints->list().last().value<QGeoCoordinate>(), first);
    QCOMPARE(updateLastPointSpy.count(), 0);
}

UT_REGISTER_TEST(TrajectoryPointsTest, TestLabel::Integration, TestLabel::Vehicle, TestLabel::MissionManager)
