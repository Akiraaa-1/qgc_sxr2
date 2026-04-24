#pragma once

#include <QtCore/QObject>
#include <QtQmlIntegration/QtQmlIntegration>

#include "SwarmCommandBridge.h"

class SwarmUiAssignmentController : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Swarmsend)

public:
    explicit SwarmUiAssignmentController(QObject *parent = nullptr);

    Q_INVOKABLE void caculate_pos(int sysid, double x, double y, double z, bool deferSync = false);
    Q_INVOKABLE void set_main_airplane(int sysid, int grpId, double x, double y, double z);
    Q_INVOKABLE void store_airplane_group(int sysid, int groupId, bool flag = false, bool setAsFollower = false);
    Q_INVOKABLE void set_absolute_altitude(int sysid, double altitude);
    Q_INVOKABLE void emitMainAltitudeChanged(int vehicleId, double altitude);

signals:
    void mainAltitudeChanged(int vehicleId, double altitude);
    void swarmOperationAckReceived(int sysId, int opType, int result, int oldValue, int newValue, const QString &message);

private:
    void _emitOperationResult(int sysId, int operationType, int oldValue, int newValue, const QVariantMap &result);

    SwarmCommandBridge _bridge;
};
