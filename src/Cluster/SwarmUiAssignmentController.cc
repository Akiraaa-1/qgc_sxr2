#include "SwarmUiAssignmentController.h"

#include "SwarmOperationAckHandler.h"
#include "SwarmUiSharedState.h"

SwarmUiAssignmentController::SwarmUiAssignmentController(QObject *parent)
    : QObject(parent)
    , _bridge(this)
{
}

void SwarmUiAssignmentController::caculate_pos(int sysid, double x, double y, double z)
{
    (void) _bridge.setVehicleOffsets(sysid, x, y, z);
}

void SwarmUiAssignmentController::set_main_airplane(int sysid, int grpId, double x, double y, double z)
{
    Q_UNUSED(x);
    Q_UNUSED(y);
    Q_UNUSED(z);

    const QList<int> vehicles = SwarmUiSharedState::instance().vehiclesInGroup(grpId);
    for (const int vehicleId : vehicles) {
        const bool oldLeader = SwarmUiSharedState::instance().vehicleLeader(vehicleId);
        const bool leader = (vehicleId == sysid);
        const QVariantMap result = _bridge.setVehicleLeader(vehicleId, leader);
        if (result.value(QStringLiteral("success")).toBool()) {
            SwarmUiSharedState::instance().setVehicleLeader(vehicleId, leader);
        }
        _emitOperationResult(vehicleId, SwarmOperationAckHandler::OperationLeaderChange, oldLeader ? 1 : 0, leader ? 1 : 0, result);
    }
}

void SwarmUiAssignmentController::store_airplane_group(int sysid, int groupId, bool flag, bool setAsFollower)
{
    SwarmUiSharedState::instance().refreshFromVehicle(sysid);
    const int oldGroupId = SwarmUiSharedState::instance().vehicleGroup(sysid);
    const bool oldLeader = SwarmUiSharedState::instance().vehicleLeader(sysid);

    if (!flag) {
        SwarmUiSharedState::instance().setVehicleGroup(sysid, groupId);
        if (setAsFollower) {
            SwarmUiSharedState::instance().setVehicleLeader(sysid, false);
        }
        return;
    }

    const QVariantMap result = _bridge.setVehicleGroup(sysid, groupId, setAsFollower);
    if (result.value(QStringLiteral("success")).toBool()) {
        SwarmUiSharedState::instance().setVehicleGroup(sysid, groupId);
        if (setAsFollower) {
            SwarmUiSharedState::instance().setVehicleLeader(sysid, false);
        }
    }
    _emitOperationResult(sysid, SwarmOperationAckHandler::OperationGroupChange, oldGroupId, groupId, result);

    if (setAsFollower && oldLeader) {
        _emitOperationResult(sysid, SwarmOperationAckHandler::OperationLeaderChange, 1, 0, result);
    }
}

void SwarmUiAssignmentController::set_absolute_altitude(int sysid, double altitude)
{
    SwarmUiSharedState::instance().refreshFromVehicle(sysid);
    (void) _bridge.setVehicleAbsoluteAltitude(sysid, altitude);
}

void SwarmUiAssignmentController::emitMainAltitudeChanged(int vehicleId, double altitude)
{
    emit mainAltitudeChanged(vehicleId, altitude);
}

void SwarmUiAssignmentController::_emitOperationResult(int sysId, int operationType, int oldValue, int newValue, const QVariantMap &result)
{
    const bool success = result.value(QStringLiteral("success")).toBool();
    const QString message = result.value(QStringLiteral("message")).toString();

    emit swarmOperationAckReceived(sysId,
                                   operationType,
                                   success ? SwarmOperationAckHandler::AckSuccess : SwarmOperationAckHandler::AckFailed,
                                   oldValue,
                                   newValue,
                                   message);
}
