#pragma once

#include "BaseClasses/VehicleTest.h"

class VehicleReadinessTest : public VehicleTest
{
    Q_OBJECT

private slots:
    void _legacyFallbackRequiresExplicitConfirmation();
    void _legacyPrearmNotReadyBlocksArmingAndLaunchActions();
    void _legacyPrearmReadyAllowsConfirmedLaunchActions();
    void _waitingForHealthReportAllowsConfirmedLaunchActions();
};
