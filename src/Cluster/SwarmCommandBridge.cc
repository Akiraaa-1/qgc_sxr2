#include "SwarmCommandBridge.h"

#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "QGCLoggingCategory.h"
#include "SwarmUiSharedState.h"
#include "Vehicle.h"
#include "VehicleSupports.h"

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
        Vehicle *const vehicle = _vehicleForId(vehicleId);
        ParameterManager *const parameterManager = vehicle ? vehicle->parameterManager() : nullptr;
        if (parameterManager && parameterManager->parametersReady() && parameterManager->parameterExists(ParameterManager::defaultComponentId, QStringLiteral("SWARM_SET_LEADER"))) {
            result = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_SET_LEADER"), 0, QStringLiteral("set-follower"), groupId);
            if (!result.value(QStringLiteral("success")).toBool()) {
                return result;
            }
        }
    }

    return _buildResult(ResultSuccess, QStringLiteral("set-group"), groupId, tr("Vehicle %1 was synced to Group %2 through the current parameter pipeline.").arg(vehicleId).arg(groupId));
}

QVariantMap SwarmCommandBridge::setVehicleLeader(int vehicleId, bool leader) const
{
    const QVariantMap result = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_SET_LEADER"), leader ? 1 : 0, leader ? QStringLiteral("set-leader") : QStringLiteral("unset-leader"));
    if (!result.value(QStringLiteral("success")).toBool()) {
        return result;
    }

    return _buildResult(ResultSuccess, leader ? QStringLiteral("set-leader") : QStringLiteral("unset-leader"), -1, leader
        ? tr("Vehicle %1 was marked as swarm leader through the current parameter pipeline.").arg(vehicleId)
        : tr("Vehicle %1 was marked as swarm follower through the current parameter pipeline.").arg(vehicleId));
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

    return _buildResult(ResultSuccess, QStringLiteral("set-offsets"), -1, tr("Vehicle %1 swarm offsets were sent through the current parameter pipeline.").arg(vehicleId));
}

QVariantMap SwarmCommandBridge::setVehicleAbsoluteAltitude(int vehicleId, double altitude) const
{
    const QVariantMap result = _setVehicleParameter(vehicleId, QStringLiteral("SWARM_ABS_ALT"), altitude, QStringLiteral("set-absolute-altitude"));
    if (!result.value(QStringLiteral("success")).toBool()) {
        return result;
    }

    return _buildResult(ResultSuccess, QStringLiteral("set-absolute-altitude"), -1, tr("Vehicle %1 absolute swarm altitude was sent through the current parameter pipeline.").arg(vehicleId));
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

    return _buildResult(ResultSuccess, QStringLiteral("clear-assignment"), -1, tr("Vehicle %1 swarm assignment was cleared through the current parameter pipeline.").arg(vehicleId));
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

QVariantMap SwarmCommandBridge::_executeGroupAction(const QString &action, int groupId, int assignedVehicleCount) const
{
    const QList<int> vehicleIds = _vehicleIdsForGroup(groupId);
    const int liveAssignedVehicleCount = vehicleIds.count();
    const QVariantMap validation = _validateGroup(groupId, liveAssignedVehicleCount > 0 ? liveAssignedVehicleCount : assignedVehicleCount, action);
    if (!validation.isEmpty()) {
        qCWarning(SwarmCommandBridgeLog) << "Rejected cluster command" << action << "for group" << groupId << validation.value(QStringLiteral("message")).toString();
        return validation;
    }

    int successCount = 0;
    QStringList failures;

    for (const int vehicleId : vehicleIds) {
        Vehicle *const vehicle = _vehicleForId(vehicleId);
        if (!vehicle) {
            failures.append(tr("Vehicle %1 is no longer connected.").arg(vehicleId));
            continue;
        }

        VehicleSupports *const supports = vehicle->supports();

        if (action == QStringLiteral("arm")) {
            vehicle->setArmed(true, true);
            successCount++;
        } else if (action == QStringLiteral("disarm")) {
            vehicle->setArmed(false, true);
            successCount++;
        } else if (action == QStringLiteral("takeoff")) {
            if (!supports || !supports->guidedMode()) {
                failures.append(tr("Vehicle %1 does not support guided takeoff.").arg(vehicleId));
                continue;
            }

            vehicle->guidedModeTakeoff(qMax(5.0, vehicle->minimumTakeoffAltitudeMeters()));
            successCount++;
        } else if (action == QStringLiteral("land")) {
            if (!supports || !supports->guidedMode()) {
                failures.append(tr("Vehicle %1 does not support guided landing.").arg(vehicleId));
                continue;
            }

            vehicle->guidedModeLand();
            successCount++;
        } else if (action == QStringLiteral("pause")) {
            if (!supports || !supports->pauseVehicle()) {
                failures.append(tr("Vehicle %1 does not support pause.").arg(vehicleId));
                continue;
            }

            vehicle->pauseVehicle();
            successCount++;
        } else if (action == QStringLiteral("resume")) {
            vehicle->startMission();
            successCount++;
        } else {
            return _buildResult(ResultError, action, groupId, tr("Unknown cluster command: %1").arg(action));
        }
    }

    if (successCount <= 0) {
        return _buildResult(ResultError, action, groupId, failures.join(QLatin1Char('\n')));
    }

    if (!failures.isEmpty()) {
        return _buildResult(ResultError, action, groupId, tr("Group %1 partially executed %2 on %3 vehicles. %4")
            .arg(groupId)
            .arg(action)
            .arg(successCount)
            .arg(failures.join(QLatin1Char('\n'))));
    }

    return _buildResult(ResultSuccess, action, groupId, tr("Group %1 executed %2 through the current vehicle command pipeline on %3 vehicles.")
        .arg(groupId)
        .arg(action)
        .arg(successCount));
}

QVariantMap SwarmCommandBridge::_setVehicleParameter(int vehicleId, const QString &paramName, const QVariant &value, const QString &action, int groupId) const
{
    Vehicle *const vehicle = _vehicleForId(vehicleId);
    if (!vehicle) {
        return _buildResult(ResultError, action, groupId, tr("Vehicle %1 is not available in the current session.").arg(vehicleId));
    }

    ParameterManager *const parameterManager = vehicle->parameterManager();
    if (!parameterManager || !parameterManager->parametersReady()) {
        return _buildResult(ResultError, action, groupId, tr("Vehicle %1 parameters are not ready yet.").arg(vehicleId));
    }

    if (!parameterManager->parameterExists(ParameterManager::defaultComponentId, paramName)) {
        return _buildResult(ResultError, action, groupId, tr("Vehicle %1 does not expose swarm parameter %2 in the current firmware.").arg(vehicleId).arg(paramName));
    }

    Fact *const fact = parameterManager->getParameter(ParameterManager::defaultComponentId, paramName);
    if (!fact) {
        return _buildResult(ResultError, action, groupId, tr("Vehicle %1 parameter %2 could not be opened.").arg(vehicleId).arg(paramName));
    }

    fact->setRawValue(value);
    qCInfo(SwarmCommandBridgeLog) << "Swarm parameter write routed through existing parameter pipeline" << "vehicle" << vehicleId << "param" << paramName << "value" << value;
    return _buildResult(ResultSuccess, action, groupId, tr("Vehicle %1 parameter %2 was sent through the current parameter pipeline.").arg(vehicleId).arg(paramName));
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
