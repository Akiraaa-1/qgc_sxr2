#include "SwarmCommandBridge.h"

#include "HealthAndArmingCheckReport.h"
#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "QGCLoggingCategory.h"
#include "SwarmUiSharedState.h"
#include "Vehicle.h"
#include "VehicleSupports.h"

#include "../MissionManager/MissionManager.h"

#include <QtCore/QMetaType>

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

    int successCount = 0;
    QStringList failures;

    for (const int vehicleId : vehicleIds) {
        Vehicle *const vehicle = _vehicleForId(vehicleId);
        if (!vehicle) {
            failures.append(tr("Vehicle %1 is no longer connected.").arg(vehicleId));
            continue;
        }

        VehicleSupports *const supports = vehicle->supports();
        HealthAndArmingCheckReport *const report = vehicle->healthAndArmingCheckReport();

        const bool healthChecksBlockArm = report && report->supported() && !report->canArm();
        const bool healthChecksBlockMission = report && report->supported() && !report->canStartMission();

        if (action == QStringLiteral("arm")) {
            if (vehicle->armed()) {
                successCount++;
                continue;
            }

            if (healthChecksBlockArm) {
                failures.append(tr("Vehicle %1 cannot arm because health and arming checks are blocking arming.").arg(vehicleId));
                continue;
            }

            vehicle->setArmed(true, true);
            successCount++;
        } else if (action == QStringLiteral("disarm")) {
            if (!vehicle->armed()) {
                successCount++;
                continue;
            }

            if (vehicle->flying()) {
                failures.append(tr("Vehicle %1 cannot disarm while it is still flying.").arg(vehicleId));
                continue;
            }

            vehicle->setArmed(false, true);
            successCount++;
        } else if (action == QStringLiteral("takeoff")) {
            if (!supports || (!supports->guidedTakeoffWithAltitude() && !supports->guidedTakeoffWithoutAltitude())) {
                failures.append(tr("Vehicle %1 does not support guided takeoff.").arg(vehicleId));
                continue;
            }

            if (vehicle->flying()) {
                failures.append(tr("Vehicle %1 is already airborne.").arg(vehicleId));
                continue;
            }

            if (supports->guidedTakeoffWithAltitude()) {
                vehicle->guidedModeTakeoff(qMax(5.0, vehicle->minimumTakeoffAltitudeMeters()));
            } else {
                vehicle->startTakeoff();
            }
            successCount++;
        } else if (action == QStringLiteral("land")) {
            if (!supports || !supports->guidedMode()) {
                failures.append(tr("Vehicle %1 does not support guided landing.").arg(vehicleId));
                continue;
            }

            if (!vehicle->armed() || !vehicle->flying()) {
                failures.append(tr("Vehicle %1 is not in a landing-capable flight state.").arg(vehicleId));
                continue;
            }

            vehicle->guidedModeLand();
            successCount++;
        } else if (action == QStringLiteral("pause")) {
            if (!supports || !supports->pauseVehicle()) {
                failures.append(tr("Vehicle %1 does not support pause.").arg(vehicleId));
                continue;
            }

            if (!vehicle->armed() || !vehicle->flying()) {
                failures.append(tr("Vehicle %1 is not in a pausable flight state.").arg(vehicleId));
                continue;
            }

            vehicle->pauseVehicle();
            successCount++;
        } else if (action == QStringLiteral("resume")) {
            MissionManager *const missionManager = vehicle->missionManager();
            if (!missionManager || missionManager->missionItems().isEmpty()) {
                failures.append(tr("Vehicle %1 has no mission available to resume.").arg(vehicleId));
                continue;
            }

            if (!vehicle->armed() || !vehicle->flying()) {
                failures.append(tr("Vehicle %1 is not in a resumable mission state.").arg(vehicleId));
                continue;
            }

            if (healthChecksBlockMission) {
                failures.append(tr("Vehicle %1 cannot resume mission because health and arming checks are blocking mission start.").arg(vehicleId));
                continue;
            }

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
        return _buildResult(ResultError, action, groupId, tr("Group %1 accepted %2 on %3 vehicles, but some vehicles were blocked before dispatch. %4")
            .arg(groupId)
            .arg(action)
            .arg(successCount)
            .arg(failures.join(QLatin1Char('\n'))));
    }

    return _buildResult(ResultSuccess, action, groupId, tr("Group %1 accepted %2 for dispatch through the current vehicle command pipeline on %3 vehicles. Vehicle-side completion is still pending.")
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
    if (!parameterManager) {
        return _buildResult(ResultError, action, groupId, tr("Vehicle %1 parameter manager is not available.").arg(vehicleId));
    }

    const FactMetaData::ValueType_t valueType = value.typeId() == QMetaType::Double
        ? FactMetaData::valueTypeFloat
        : FactMetaData::valueTypeInt32;

    if (!parameterManager->parametersReady() || !parameterManager->parameterExists(ParameterManager::defaultComponentId, paramName)) {
        parameterManager->sendSwarmParameter(ParameterManager::defaultComponentId, paramName, valueType, value);
        qCInfo(SwarmCommandBridgeLog) << "Swarm parameter direct write routed without Fact cache" << "vehicle" << vehicleId << "param" << paramName << "value" << value;
        return _buildResult(ResultSuccess, action, groupId, tr("Vehicle %1 swarm parameter %2 was sent directly because the normal parameter cache is not ready or does not expose it yet. Vehicle-side confirmation is still pending.").arg(vehicleId).arg(paramName));
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
