#pragma once

#include "BaseClasses/VehicleTest.h"

class TrajectoryPointsTest : public VehicleTest
{
    Q_OBJECT

private slots:
    void _armedMissionTransactionsPreserveTrajectory();
    void _restartTrackingPreservesTrajectory();
    void _missionTransactionsClearTrajectory();
    void _groundJitterDoesNotGrowAirborneVehicleTrack();
};
