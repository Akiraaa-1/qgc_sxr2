#pragma once

#include "BaseClasses/MultiVehicleTest.h"

class VehiclePlanSessionManagerTest : public MultiVehicleTest
{
    Q_OBJECT

private slots:
    void _testSessionIsolationAndOperationTokens();
    void _testTemporaryVehicleIdentityBlocksMutation();
    void _testPlanIdentityMismatchBlocksMutation();
    void _testDuplicateVehicleIdentityBlocksMutation();
    void _testRemoteUnknownBlocksUploadButAllowsMissionClearRecovery();
    void _testCommunicationLossBlocksVehicleMutation();
    void _testUidConfirmationKeepsDirtyTemporarySession();
};
