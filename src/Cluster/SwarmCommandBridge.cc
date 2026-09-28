#include "SwarmCommandBridge.h"

#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "QGCLoggingCategory.h"
#include "SwarmUiSharedState.h"
#include "Vehicle.h"
#include "VehicleReadiness.h"
#include "VehicleSupports.h"

#include "../MissionManager/MissionManager.h"

QGC_LOGGING_CATEGORY(SwarmCommandBridgeLog, "Cluster.SwarmCommandBridge")

SwarmCommandBridge::SwarmCommandBridge(QObject *parent)
    : QObject(parent)
{
}

QVariantMap SwarmCommandBridge::armGroup(int groupId, int assignedVehicleCount) const
{
    return _executeGroupAction(QStringLiteral("arm"), groupId, assignedVehicleCount);
}

QVariantMap SwarmCommandBridge::disarmGroup(int groupId, int assignedVehicleCount) const
{
    return _executeGroupAction(QStringLiteral("disarm"), groupId, assignedVehicleCount);
}

QVariantMap SwarmCommandBridge::takeoffGroup(int groupId, int assignedVehicleCount) const
{
    return _executeGroupAction(QStringLiteral("takeoff"), groupId, assignedVehicleCount);
}

QVariantMap SwarmCommandBridge::landGroup(int groupId, int assignedVehicleCount) const
{
    return _executeGroupAction(QStringLiteral("land"), groupId, assignedVehicleCount);
}

QVariantMap SwarmCommandBridge::pauseGroup(int groupId, int assignedVehicleCount) const
{
    return _executeGroupAction(QStringLiteral("pause"), groupId, assignedVehicleCount);
}

QVariantMap SwarmCommandBridge::resumeGroup(int groupId, int assignedVehicleCount) const
{
    return _executeGroupAction(QStringLiteral("resume"), groupId, assignedVehicleCount);
}

QVariantMap SwarmCommandBridge::setVehicleGroup(int vehicleId, int groupId, bool setAsFollower) const
{
    if ((groupId < 1) || (groupId > 4)) {
        return _buildResult(ResultError, QStringLiteral("set-group"), groupId, tr("Cannot sync Group %1 because it is outside the supported range 1-4.").arg(groupId));
    }

    QVariantMap result = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_GROUP_ID"), groupId, QStringLiteral("set-group"), groupId);
    if (!result.value(QStringLiteral("success")).toBool()) {
        return result;
    }

    if (setAsFollower) {
        result = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_SET_LEADER"), 0, QStringLiteral("set-follower"), groupId);
        if (!result.value(QStringLiteral("success")).toBool()) {
            return result;
        }
    }

    return _buildResult(ResultSuccess, QStringLiteral("set-group"), groupId, tr("Vehicle %1 accepted a Group %2 sync request through the current parameter pipeline. Vehicle-side confirmation is still pending.").arg(vehicleId).arg(groupId));
}

QVariantMap SwarmCommandBridge::setVehicleLeader(int vehicleId, bool leader) const
{
    if (leader) {
        const int groupId = SwarmUiSharedState::instance().vehicleGroup(vehicleId);
        if (groupId < 1) {
            return _buildResult(ResultNoGroupAssigned, QStringLiteral("set-leader"), -1, tr("Assign Vehicle %1 to a group before setting it as leader.").arg(vehicleId));
        }

        const QVariantMap clearResult = _clearExistingGroupLeader(groupId, vehicleId);
        if (!clearResult.isEmpty()) {
            return clearResult;
        }
    }

    const QVariantMap result = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_SET_LEADER"), leader ? 1 : 0, leader ? QStringLiteral("set-leader") : QStringLiteral("unset-leader"));
    if (!result.value(QStringLiteral("success")).toBool()) {
        return result;
    }

    return _buildResult(ResultSuccess, leader ? QStringLiteral("set-leader") : QStringLiteral("unset-leader"), -1, leader
        ? tr("Vehicle %1 accepted a swarm leader sync request through the current parameter pipeline. Vehicle-side confirmation is still pending.").arg(vehicleId)
        : tr("Vehicle %1 accepted a swarm follower sync request through the current parameter pipeline. Vehicle-side confirmation is still pending.").arg(vehicleId));
}

QVariantMap SwarmCommandBridge::setVehicleOffsets(int vehicleId, double xOffset, double yOffset, double zOffset) const
{
    const QVariantMap xResult = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_X_OFFSET"), xOffset, QStringLiteral("set-x-offset"));
    if (!xResult.value(QStringLiteral("success")).toBool()) {
        return xResult;
    }

    const QVariantMap yResult = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_Y_OFFSET"), yOffset, QStringLiteral("set-y-offset"));
    if (!yResult.value(QStringLiteral("success")).toBool()) {
        return yResult;
    }

    const QVariantMap zResult = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_Z_OFFSET"), zOffset, QStringLiteral("set-z-offset"));
    if (!zResult.value(QStringLiteral("success")).toBool()) {
        return zResult;
    }

    return _buildResult(ResultSuccess, QStringLiteral("set-offsets"), -1, tr("Vehicle %1 accepted swarm offset sync requests through the current parameter pipeline. Vehicle-side confirmation is still pending.").arg(vehicleId));
}

QVariantMap SwarmCommandBridge::setVehicleAbsoluteAltitude(int vehicleId, double altitude) const
{
    const QVariantMap result = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_ABS_ALT"), altitude, QStringLiteral("set-absolute-altitude"));
    if (!result.value(QStringLiteral("success")).toBool()) {
        return result;
    }

    return _buildResult(ResultSuccess, QStringLiteral("set-absolute-altitude"), -1, tr("Vehicle %1 accepted an absolute swarm altitude sync request through the current parameter pipeline. Vehicle-side confirmation is still pending.").arg(vehicleId));
}

QVariantMap SwarmCommandBridge::clearVehicleAssignment(int vehicleId) const
{
    Vehicle *const vehicle = _vehicleForId(vehicleId);
    if (!vehicle) {
        return _buildResult(ResultError, QStringLiteral("clear-assignment"), -1, tr("Vehicle %1 is not available in the current session.").arg(vehicleId));
    }

    ParameterManager *const parameterManager = vehicle->parameterManager();
    if (!parameterManager || !parameterManager->parametersReady()) {
        return _buildResult(ResultError, QStringLiteral("clear-assignment"), -1, tr("Vehicle %1 parameters are not ready yet.").arg(vehicleId));
    }

    bool syncedAnyParameter = false;

    if (parameterManager->parameterExists(ParameterManager::defaultComponentId, QStringLiteral("SWARM_SET_LEADER"))) {
        const QVariantMap leaderResult = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_SET_LEADER"), 0, QStringLiteral("clear-assignment"));
        if (!leaderResult.value(QStringLiteral("success")).toBool()) {
            return leaderResult;
        }
        syncedAnyParameter = true;
    }

    if (parameterManager->parameterExists(ParameterManager::defaultComponentId, QStringLiteral("SWARM_GROUP_ID"))) {
        const QVariantMap groupResult = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_GROUP_ID"), 0, QStringLiteral("clear-assignment"));
        if (!groupResult.value(QStringLiteral("success")).toBool()) {
            return groupResult;
        }
        syncedAnyParameter = true;
    }

    if (!syncedAnyParameter) {
        return _buildResult(ResultError, QStringLiteral("clear-assignment"), -1, tr("Vehicle %1 does not expose swarm assignment parameters in the current firmware.").arg(vehicleId));
    }

    return _buildResult(ResultSuccess, QStringLiteral("clear-assignment"), -1, tr("Vehicle %1 accepted a swarm assignment clear request through the current parameter pipeline. Vehicle-side confirmation is still pending.").arg(vehicleId));
}

Vehicle *SwarmCommandBridge::_vehicleForId(int vehicleId) const
{
    MultiVehicleManager *const manager = MultiVehicleManager::instance();
    return manager ? manager->getVehicleById(vehicleId) : nullptr;
}

QList<int> SwarmCommandBridge::_vehicleIdsForGroup(int groupId) const
{
    return SwarmUiSharedState::instance().vehiclesInGroup(groupId);
}

QVariantMap SwarmCommandBridge::_clearExistingGroupLeader(int groupId, int excludedVehicleId) const
{
    const QList<int> vehicleIds = _vehicleIdsForGroup(groupId);
    for (const int vehicleId : vehicleIds) {
        if (vehicleId == excludedVehicleId) {
            continue;
        }

        if (!SwarmUiSharedState::instance().vehicleLeader(vehicleId)) {
            continue;
        }

        const QVariantMap result = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_SET_LEADER"), 0, QStringLiteral("clear-peer-leader"), groupId);
        if (!result.value(QStringLiteral("success")).toBool()) {
            return result;
        }
    }

    return QVariantMap();
}

QVariantMap SwarmCommandBridge::_executeGroupAction(const QString &action, int groupId, int assignedVehicleCount) const
{
    const QList<int> vehicleIds = _vehicleIdsForGroup(groupId);
    const int liveAssignedVehicleCount = vehicleIds.count();
    const QVariantMap validation = _validateGroup(groupId, liveAssignedVehicleCount > 0 ? liveAssignedVehicleCount : assignedVehicleCount, action);
    if (!validation.isEmpty()) {
        qCWarning(SwarmCommandBridgeLog) << "Rejected cluster command" << action << "for group" << groupId << validation.value(QStringLiteral("message")).toString();
        return validation;
    }

    QList<Vehicle*> vehicles;
    QStringList failures;

    for (const int vehicleId : vehicleIds) {
        Vehicle *const vehicle = _vehicleForId(vehicleId);
        if (!vehicle) {
            failures.append(tr("Vehicle %1 is no longer connected.").arg(vehicleId));
            continue;
        }

        VehicleSupports *const supports = vehicle->supports();
        VehicleReadiness *const readiness = vehicle->readiness();
        VehicleLinkManager *const linkManager = vehicle->vehicleLinkManager();
        if (!linkManager || linkManager->communicationLost()) {
            failures.append(tr("Vehicle %1 communication is unavailable.").arg(vehicleId));
            continue;
        }

        if (action == QStringLiteral("arm")) {
            if (!vehicle->armed() && (!readiness || !readiness->armAllowed())) {
                failures.append(tr("Vehicle %1 does not have a current explicit arm approval.").arg(vehicleId));
            }
        } else if (action == QStringLiteral("disarm")) {
            if (!vehicle->armed() || vehicle->flying()) {
                failures.append(tr("Vehicle %1 cannot disarm while it is still flying.").arg(vehicleId));
            }
        } else if (action == QStringLiteral("takeoff")) {
            if (!supports || (!supports->guidedTakeoffWithAltitude() && !supports->guidedTakeoffWithoutAltitude())) {
                failures.append(tr("Vehicle %1 does not support guided takeoff.").arg(vehicleId));
            } else if (vehicle->flying()) {
                failures.append(tr("Vehicle %1 is already airborne.").arg(vehicleId));
            } else if (!readiness || !readiness->takeoffAllowed()) {
                failures.append(tr("Vehicle %1 does not have a current explicit takeoff approval.").arg(vehicleId));
            }
        } else if (action == QStringLiteral("land")) {
            if (!supports || !supports->guidedMode()) {
                failures.append(tr("Vehicle %1 does not support guided landing.").arg(vehicleId));
            } else if (!vehicle->armed() || !vehicle->flying()) {
                failures.append(tr("Vehicle %1 is not in a landing-capable flight state.").arg(vehicleId));
            }
        } else if (action == QStringLiteral("pause")) {
            if (!supports || !supports->pauseVehicle()) {
                failures.append(tr("Vehicle %1 does not support pause.").arg(vehicleId));
            } else if (!vehicle->armed() || !vehicle->flying()) {
                failures.append(tr("Vehicle %1 is not in a pausable flight state.").arg(vehicleId));
            }
        } else if (action == QStringLiteral("resume")) {
            MissionManager *const missionManager = vehicle->missionManager();
            if (!missionManager || missionManager->missionItems().isEmpty()) {
                failures.append(tr("Vehicle %1 has no mission available to resume.").arg(vehicleId));
            } else if (!vehicle->armed() || !vehicle->flying()) {
                failures.append(tr("Vehicle %1 is not in a resumable mission state.").arg(vehicleId));
            } else if (!readiness || !readiness->missionResumeAllowed()) {
                failures.append(tr("Vehicle %1 does not have a current explicit mission-resume approval.").arg(vehicleId));
            }
        } else {
            return _buildResult(ResultError, action, groupId, tr("Unknown cluster command: %1").arg(action));
        }

        vehicles.append(vehicle);
    }

    if (!failures.isEmpty()) {
        return _buildResult(ResultError, action, groupId, tr("Group %1 did not dispatch %2 because every assigned vehicle must pass preflight validation. %3")
            .arg(groupId)
            .arg(action)
            .arg(failures.join(QLatin1Char('\n'))));
    }

    for (Vehicle* const vehicle : vehicles) {
        if (action == QStringLiteral("arm")) {
            if (!vehicle->armed()) {
                vehicle->requestArm(false);
            }
        } else if (action == QStringLiteral("disarm")) {
            vehicle->setArmed(false, true);
        } else if (action == QStringLiteral("takeoff")) {
            vehicle->requestTakeoff(qMax(5.0, vehicle->minimumTakeoffAltitudeMeters()), false);
        } else if (action == QStringLiteral("land")) {
            vehicle->guidedModeLand();
        } else if (action == QStringLiteral("pause")) {
            vehicle->pauseVehicle();
        } else if (action == QStringLiteral("resume")) {
            vehicle->requestAirborneMissionResume(false);
        }
    }

    QVariantMap result = _buildResult(ResultSuccess, action, groupId, tr("Group %1 dispatched %2 to %3 vehicles after all members passed preflight validation. Per-vehicle command acknowledgement and state confirmation are pending.")
        .arg(groupId)
        .arg(action)
        .arg(vehicles.count()));
    result[QStringLiteral("phase")] = QStringLiteral("dispatched");
    return result;
}

QVariantMap SwarmCommandBridge::_setVehicleParameter(int vehicleId, const QString &paramName, const QVariant &value, const QString &action, int groupId) const
{
    Vehicle *const vehicle = _vehicleForId(vehicleId);
    if (!vehicle) {
        return _buildResult(ResultError, action, groupId, tr("Vehicle %1 is not available in the current session.").arg(vehicleId));
    }

    ParameterManager *const parameterManager = vehicle->parameterManager();
    if (!parameterManager) {
        return _buildResult(ResultError, action, groupId, tr("Vehicle %1 parameter manager is not available.").arg(vehicleId));
    }

    if (!parameterManager->parametersReady()) {
        return _buildResult(ResultError, action, groupId, tr("Vehicle %1 parameters are not ready yet. Wait for parameter download to finish before sending %2.").arg(vehicleId).arg(paramName));
    }

    if (!parameterManager->parameterExists(ParameterManager::defaultComponentId, paramName)) {
        qCWarning(SwarmCommandBridgeLog) << "Firmware does not expose swarm parameter" << "vehicle" << vehicleId << "param" << paramName;
        return _buildResult(ResultError, action, groupId, tr("Vehicle %1 firmware does not expose swarm parameter %2. No parameter write was sent.").arg(vehicleId).arg(paramName));
    }

    Fact *const fact = parameterManager->getParameter(ParameterManager::defaultComponentId, paramName);
    if (!fact) {
        return _buildResult(ResultError, action, groupId, tr("Vehicle %1 parameter %2 could not be opened.").arg(vehicleId).arg(paramName));
    }

    fact->setRawValue(value);
    qCInfo(SwarmCommandBridgeLog) << "Swarm parameter write routed through existing parameter pipeline" << "vehicle" << vehicleId << "param" << paramName << "value" << value;
    return _buildResult(ResultSuccess, action, groupId, tr("Vehicle %1 parameter %2 was queued through the current parameter pipeline. Vehicle-side confirmation is still pending.").arg(vehicleId).arg(paramName));
}

QVariantMap SwarmCommandBridge::_buildResult(ResultCode code, const QString &action, int groupId, const QString &message) const
{
    QVariantMap result;
    result[QStringLiteral("success")] = (code == ResultSuccess);
    result[QStringLiteral("code")] = code;
    result[QStringLiteral("action")] = action;
    result[QStringLiteral("groupId")] = groupId;
    result[QStringLiteral("message")] = message;
    return result;
}

QVariantMap SwarmCommandBridge::_validateGroup(int groupId, int assignedVehicleCount, const QString &action) const
{
    if ((groupId < 1) || (groupId > 4)) {
        return _buildResult(ResultError, action, groupId, tr("Group %1 is invalid. Choose Group 1 to Group 4.").arg(groupId));
    }

    if (assignedVehicleCount <= 0) {
        return _buildResult(ResultNoGroupAssigned, action, groupId, tr("Group %1 has no assigned vehicles yet.").arg(groupId));
    }

    return QVariantMap();
}

QVariantMap SwarmCommandBridge::_notImplementedResult(const QString &action, int groupId, int assignedVehicleCount) const
{
    const QVariantMap validation = _validateGroup(groupId, assignedVehicleCount, action);
    if (!validation.isEmpty()) {
        qCWarning(SwarmCommandBridgeLog) << "Rejected cluster command" << action << "for group" << groupId << "assigned vehicles" << assignedVehicleCount << validation.value(QStringLiteral("message")).toString();
        return validation;
    }

    qCInfo(SwarmCommandBridgeLog) << "Cluster command queued for future backend integration" << action << "group" << groupId << "assigned vehicles" << assignedVehicleCount;
    return _buildResult(ResultNotImplemented, action, groupId, tr("%1 for Group %2 is staged in the cluster bridge, but the real swarm backend is not connected yet.").arg(action).arg(groupId));
}
