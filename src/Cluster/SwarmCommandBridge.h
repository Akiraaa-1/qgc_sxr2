#pragma once

#include <QtCore/QList>
#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QVariantMap>

class Vehicle;

Q_DECLARE_LOGGING_CATEGORY(SwarmCommandBridgeLog)

class SwarmCommandBridge : public QObject
{
    Q_OBJECT

public:
    enum ResultCode {
        ResultSuccess = 0,
        ResultError,
        ResultNoGroupAssigned,
        ResultNotImplemented,
    };
    Q_ENUM(ResultCode)

    explicit SwarmCommandBridge(QObject *parent = nullptr);

    QVariantMap armGroup(int groupId, int assignedVehicleCount) const;
    QVariantMap disarmGroup(int groupId, int assignedVehicleCount) const;
    QVariantMap takeoffGroup(int groupId, int assignedVehicleCount) const;
    QVariantMap landGroup(int groupId, int assignedVehicleCount) const;
    QVariantMap pauseGroup(int groupId, int assignedVehicleCount) const;
    QVariantMap resumeGroup(int groupId, int assignedVehicleCount) const;
    QVariantMap setVehicleGroup(int vehicleId, int groupId, bool setAsFollower) const;
    QVariantMap setVehicleLeader(int vehicleId, bool leader) const;
    QVariantMap setVehicleOffsets(int vehicleId, double xOffset, double yOffset, double zOffset) const;
    QVariantMap setVehicleAbsoluteAltitude(int vehicleId, double altitude) const;
    QVariantMap clearVehicleAssignment(int vehicleId) const;

private:
    Vehicle *_vehicleForId(int vehicleId) const;
    QList<int> _vehicleIdsForGroup(int groupId) const;
    QVariantMap _clearExistingGroupLeader(int groupId, int excludedVehicleId) const;
    QVariantMap _executeGroupAction(const QString &action, int groupId, int assignedVehicleCount) const;
    QVariantMap _setVehicleParameter(int vehicleId, const QString &paramName, const QVariant &value, const QString &action, int groupId = -1) const;
    QVariantMap _buildResult(ResultCode code, const QString &action, int groupId, const QString &message) const;
    QVariantMap _validateGroup(int groupId, int assignedVehicleCount, const QString &action) const;
    QVariantMap _notImplementedResult(const QString &action, int groupId, int assignedVehicleCount) const;
};
