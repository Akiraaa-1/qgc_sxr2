#pragma once

#include "BaseClasses/CommsTest.h"
#include "LinkConfiguration.h"

class Fact;
class QSignalSpy;
class Vehicle;

class VehicleReadinessSITLTest : public CommsTest
{
    Q_OBJECT

protected slots:
    void init() override;
    void cleanup() override;

private slots:
    void _healthReportReadinessScenarios();

private:
    bool _setParameter(const QString& name, int value);
    bool _hasParameterSetSuccess(const QSignalSpy& spy, const QString& name) const;
    bool _healthReportAllowsArm() const;
    bool _healthReportDeniesArm() const;
    bool _pauseSitl();
    void _resumeSitl();

    SharedLinkConfigurationPtr _linkConfig;
    Vehicle* _vehicle = nullptr;
    int _gcsPort = 0;
    int _sitlPort = 0;
    qint64 _sitlPid = 0;
    bool _sitlPaused = false;
};
