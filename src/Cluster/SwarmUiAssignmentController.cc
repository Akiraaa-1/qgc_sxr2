#include "SwarmUiAssignmentController.h"

#include "SwarmOperationAckHandler.h"
#include "SwarmUiSharedState.h"

SwarmUiAssignmentController::SwarmUiAssignmentController(QObject *parent)
    : QObject(parent)
    , _bridge(this)
{
}

void SwarmUiAssignmentController::caculate_pos(int sysid, double x, double y, double z, bool deferSync)
{
    Q_UNUSED(deferSync);

    SwarmUiSharedState::instance().setVehicleOffset(sysid, x, y, z);

    const QVariantMap result = _bridge.setVehicleOffsets(sysid, x, y, z);
    if (!result.value(QStringLiteral("success")).toBool()) {
        _emitOperationResult(sysid, SwarmOperationAckHandler::OperationUnknown, 0, 0, result);
    }
}

void SwarmUiAssignmentController::set_main_airplane(int sysid, int grpId, double x, double y, double z)
{
    Q_UNUSED(x);
    Q_UNUSED(y);
    Q_UNUSED(z);

    const QList<int> vehicles = SwarmUiSharedState::instance().vehiclesInGroup(grpId);
    if (vehicles.isEmpty()) {
        QVariantMap result;
        result[QStringLiteral("success")] = false;
        result[QStringLiteral("message")] = tr("Group %1 has no synced vehicles available for leader selection.").arg(grpId);
        _emitOperationResult(sysid, SwarmOperationAckHandler::OperationLeaderChange, 0, 0, result);
        return;
    }

    if (!vehicles.contains(sysid)) {
        QVariantMap result;
        result[QStringLiteral("success")] = false;
        result[QStringLiteral("message")] = tr("Vehicle %1 is not part of Group %2 in the current swarm state.").arg(sysid).arg(grpId);
        _emitOperationResult(sysid, SwarmOperationAckHandler::OperationLeaderChange, 0, 0, result);
        return;
    }

    for (const int vehicleId : vehicles) {
        const bool oldLeader = SwarmUiSharedState::instance().vehicleLeader(vehicleId);
        const bool leader = (vehicleId == sysid);
        SwarmUiSharedState::instance().setVehicleLeader(vehicleId, leader);
        const QVariantMap result = _bridge.setVehicleLeader(vehicleId, leader);
        _emitOperationResult(vehicleId, SwarmOperationAckHandler::OperationLeaderChange, oldLeader ? 1 : 0, leader ? 1 : 0, result);
    }
}

void SwarmUiAssignmentController::store_airplane_group(int sysid, int groupId, bool flag, bool setAsFollower)
{
    SwarmUiSharedState::instance().refreshFromVehicle(sysid);
    const int oldGroupId = SwarmUiSharedState::instance().vehicleGroup(sysid);
    const bool oldLeader = SwarmUiSharedState::instance().vehicleLeader(sysid);

    SwarmUiSharedState::instance().setVehicleGroup(sysid, groupId);

    if (!flag) {
        // Keep local UI group membership available for group commands without
        // forcing a parameter write. Firmware that exposes SWARM_GROUP_ID will
        // still override this value through refreshFromVehicle.
        return;
    }

    SwarmUiSharedState::instance().setVehicleGroup(sysid, groupId);
    if (setAsFollower) {
        SwarmUiSharedState::instance().setVehicleLeader(sysid, false);
    }

    const QVariantMap result = _bridge.setVehicleGroup(sysid, groupId, setAsFollower);
    if (result.value(QStringLiteral("success")).toBool()) {
        _emitOperationResult(sysid, SwarmOperationAckHandler::OperationGroupChange, oldGroupId, groupId, result);
    }

    if (setAsFollower && oldLeader) {
        _emitOperationResult(sysid, SwarmOperationAckHandler::OperationLeaderChange, 1, 0, result);
    }
}

int SwarmUiAssignmentController::stored_airplane_group(int sysid)
{
    return SwarmUiSharedState::instance().cachedVehicleGroup(sysid);
}

bool SwarmUiAssignmentController::stored_airplane_leader(int sysid)
{
    return SwarmUiSharedState::instance().cachedVehicleLeader(sysid);
}

void SwarmUiAssignmentController::set_absolute_altitude(int sysid, double altitude)
{
    SwarmUiSharedState::instance().refreshFromVehicle(sysid);
    const QVariantMap result = _bridge.setVehicleAbsoluteAltitude(sysid, altitude);
    if (!result.value(QStringLiteral("success")).toBool()) {
        _emitOperationResult(sysid, SwarmOperationAckHandler::OperationUnknown, 0, 0, result);
    }
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
