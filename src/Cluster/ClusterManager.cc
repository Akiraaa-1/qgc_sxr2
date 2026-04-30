#include "ClusterManager.h"

#include "MultiVehicleManager.h"
#include "QGCLoggingCategory.h"
#include "SwarmCommandBridge.h"
#include "SwarmUiSharedState.h"
#include "Vehicle.h"

QGC_LOGGING_CATEGORY(ClusterManagerLog, "Cluster.ClusterManager")

ClusterManager::ClusterManager(QObject *parent)
    : QObject(parent)
    , _swarmCommandBridge(new SwarmCommandBridge(this))
    , _swarmOperationAckHandler(new SwarmOperationAckHandler(this))
    , _stateSyncTimer(new QTimer(this))
{
    MultiVehicleManager *const multiVehicleManager = MultiVehicleManager::instance();
    if (!multiVehicleManager) {
        qCWarning(ClusterManagerLog) << "MultiVehicleManager unavailable";
        return;
    }

    (void) connect(_swarmOperationAckHandler, &SwarmOperationAckHandler::operationAckReceived, this, &ClusterManager::_handleOperationAckReceived);
    (void) connect(multiVehicleManager, &MultiVehicleManager::activeVehicleChanged, this, &ClusterManager::_handleActiveVehicleChanged);
    (void) connect(multiVehicleManager, &MultiVehicleManager::vehicleAdded, this, &ClusterManager::_handleVehicleAdded);
    (void) connect(multiVehicleManager, &MultiVehicleManager::vehicleRemoved, this, &ClusterManager::_handleVehicleRemoved);

    _stateSyncTimer->setInterval(500);
    (void) connect(_stateSyncTimer, &QTimer::timeout, this, &ClusterManager::_syncAssignmentsFromVehicles);
    _stateSyncTimer->start();

    _syncAssignmentsFromVehicles();
}

int ClusterManager::assignedVehicleCount() const
{
    return _assignments.size();
}

int ClusterManager::leaderCount() const
{
    int count = 0;
    for (auto it = _assignments.cbegin(); it != _assignments.cend(); ++it) {
        if (it->leader) {
            count++;
        }
    }

    return count;
}

int ClusterManager::activeVehicleGroup() const
{
    Vehicle *const vehicle = _activeVehicle();
    return vehicle ? vehicleGroup(vehicle->id()) : -1;
}

bool ClusterManager::activeVehicleLeader() const
{
    Vehicle *const vehicle = _activeVehicle();
    return vehicle ? vehicleLeader(vehicle->id()) : false;
}

QVariantList ClusterManager::groupSummary() const
{
    QVariantList summary;
    for (int groupId = 1; groupId <= groupCount(); groupId++) {
        int vehicleCount = 0;
        int leaderId = -1;
        int leaderCountForGroup = 0;

        for (auto it = _assignments.cbegin(); it != _assignments.cend(); ++it) {
            if (it->groupId != groupId) {
                continue;
            }

            vehicleCount++;
            if (it->leader) {
                leaderCountForGroup++;
                if (leaderId < 0) {
                    leaderId = it.key();
                }
            }
        }

        QVariantMap groupInfo;
        groupInfo[QStringLiteral("groupId")] = groupId;
        groupInfo[QStringLiteral("vehicleCount")] = vehicleCount;
        groupInfo[QStringLiteral("leaderId")] = leaderId;
        groupInfo[QStringLiteral("leaderCount")] = leaderCountForGroup;
        summary.append(groupInfo);
    }

    return summary;
}

int ClusterManager::vehicleGroup(int vehicleId) const
{
    const auto it = _assignments.constFind(vehicleId);
    return it == _assignments.cend() ? -1 : it->groupId;
}

bool ClusterManager::vehicleLeader(int vehicleId) const
{
    const auto it = _assignments.constFind(vehicleId);
    return it != _assignments.cend() && it->leader;
}

void ClusterManager::assignVehicleToGroup(int vehicleId, int groupId)
{
    if (!_vehicleExists(vehicleId)) {
        qCWarning(ClusterManagerLog) << "Attempted to assign missing vehicle" << vehicleId;
        _setLastCommandResult(_buildLocalResult(ResultError, QStringLiteral("set-group"), groupId, tr("Vehicle %1 is not available in the current session.").arg(vehicleId)));
        return;
    }

    if ((groupId < 1) || (groupId > groupCount())) {
        qCWarning(ClusterManagerLog) << "Invalid cluster group" << groupId << "for vehicle" << vehicleId;
        _setLastCommandResult(_buildLocalResult(ResultError, QStringLiteral("set-group"), groupId, tr("Group %1 is invalid. Choose Group 1 to Group 4.").arg(groupId)));
        return;
    }

    const int currentGroupId = vehicleGroup(vehicleId);
    const bool currentLeader = vehicleLeader(vehicleId);
    if (currentGroupId == groupId) {
        _setLastCommandResult(_buildLocalResult(ResultSuccess, QStringLiteral("set-group"), groupId, tr("Vehicle %1 is already assigned to Group %2.").arg(vehicleId).arg(groupId)));
        return;
    }

    if (_swarmCommandBridge) {
        _setLastCommandResult(_swarmCommandBridge->setVehicleGroup(vehicleId, groupId, !currentLeader));
    } else {
        _setLastCommandResult(_buildLocalResult(ResultSuccess, QStringLiteral("set-group"), groupId, tr("Vehicle %1 was assigned to Group %2 locally.").arg(vehicleId).arg(groupId)));
    }
    _refreshAndEmitIfChanged();
}

void ClusterManager::assignActiveVehicleToGroup(int groupId)
{
    Vehicle *const vehicle = _activeVehicle();
    if (!vehicle) {
        return;
    }

    assignVehicleToGroup(vehicle->id(), groupId);
}

void ClusterManager::clearVehicleAssignment(int vehicleId)
{
    if (!_clearVehicleAssignmentInternal(vehicleId, true)) {
        if (_assignments.constFind(vehicleId) == _assignments.cend()) {
            _setLastCommandResult(_buildLocalResult(ResultSuccess, QStringLiteral("clear-assignment"), -1, tr("Vehicle %1 is already unassigned.").arg(vehicleId)));
        }
    }
}

void ClusterManager::clearActiveVehicleAssignment()
{
    Vehicle *const vehicle = _activeVehicle();
    if (!vehicle) {
        return;
    }

    clearVehicleAssignment(vehicle->id());
}

void ClusterManager::toggleLeaderForVehicle(int vehicleId)
{
    if (!_vehicleExists(vehicleId)) {
        qCWarning(ClusterManagerLog) << "Attempted to toggle leader for missing vehicle" << vehicleId;
        _setLastCommandResult(_buildLocalResult(ResultError, QStringLiteral("set-leader"), -1, tr("Vehicle %1 is not available in the current session.").arg(vehicleId)));
        return;
    }

    const int currentGroupId = vehicleGroup(vehicleId);
    const bool currentLeader = vehicleLeader(vehicleId);
    if (currentGroupId < 1) {
        _setLastCommandResult(_buildLocalResult(ResultNoGroupAssigned, QStringLiteral("set-leader"), -1, tr("Assign Vehicle %1 to a group before changing its leader role.").arg(vehicleId)));
        return;
    }

    if (_swarmCommandBridge) {
        _setLastCommandResult(_swarmCommandBridge->setVehicleLeader(vehicleId, !currentLeader));
    } else {
        _setLastCommandResult(_buildLocalResult(ResultSuccess, !currentLeader ? QStringLiteral("set-leader") : QStringLiteral("unset-leader"), currentGroupId, !currentLeader
            ? tr("Vehicle %1 was marked as leader locally.").arg(vehicleId)
            : tr("Vehicle %1 was marked as follower locally.").arg(vehicleId)));
    }
    _refreshAndEmitIfChanged();
}

void ClusterManager::toggleLeaderForActiveVehicle()
{
    Vehicle *const vehicle = _activeVehicle();
    if (!vehicle) {
        return;
    }

    toggleLeaderForVehicle(vehicle->id());
}

void ClusterManager::clearAllAssignments()
{
    _syncAssignmentsFromVehicles();

    if (_assignments.isEmpty()) {
        return;
    }

    int failedVehicles = 0;

    if (_swarmCommandBridge) {
        for (auto it = _assignments.cbegin(); it != _assignments.cend(); ++it) {
            const QVariantMap result = _swarmCommandBridge->clearVehicleAssignment(it.key());
            if (!result.value(QStringLiteral("success")).toBool()) {
                failedVehicles++;
            }
        }
    }

    const int clearedCount = _assignments.size();
    _refreshAndEmitIfChanged();

    if (_swarmCommandBridge) {
        if (failedVehicles == 0) {
            _setLastCommandResult(_buildLocalResult(ResultSuccess, QStringLiteral("clear-all"), -1, tr("Queued clear requests for %1 cluster assignments through the current parameter pipeline. Vehicle-side confirmation is still pending.").arg(clearedCount)));
        } else {
            _setLastCommandResult(_buildLocalResult(ResultError, QStringLiteral("clear-all"), -1, tr("Queued clear requests for %1 cluster assignments, but %2 vehicle sync operations were rejected before dispatch.").arg(clearedCount).arg(failedVehicles)));
        }
    } else {
        _setLastCommandResult(_buildLocalResult(ResultSuccess, QStringLiteral("clear-all"), -1, tr("Cleared %1 local cluster assignments.").arg(clearedCount)));
    }
}

void ClusterManager::clearLastCommandResult()
{
    _lastCommandAction.clear();
    _lastCommandGroup = -1;
    _lastCommandCode = -1;
    _lastCommandMessage.clear();
    _lastCommandSuccess = false;
    emit lastCommandResultChanged();
}

QVariantMap ClusterManager::armGroup(int groupId)
{
    return _runGroupCommand(QStringLiteral("arm"), groupId);
}

QVariantMap ClusterManager::disarmGroup(int groupId)
{
    return _runGroupCommand(QStringLiteral("disarm"), groupId);
}

QVariantMap ClusterManager::takeoffGroup(int groupId)
{
    return _runGroupCommand(QStringLiteral("takeoff"), groupId);
}

QVariantMap ClusterManager::landGroup(int groupId)
{
    return _runGroupCommand(QStringLiteral("land"), groupId);
}

QVariantMap ClusterManager::pauseGroup(int groupId)
{
    return _runGroupCommand(QStringLiteral("pause"), groupId);
}

QVariantMap ClusterManager::resumeGroup(int groupId)
{
    return _runGroupCommand(QStringLiteral("resume"), groupId);
}

QVariantMap ClusterManager::ingestOperationAck(int vehicleId, int operationType, int result, int oldValue, int newValue)
{
    if (!_swarmOperationAckHandler) {
        return QVariantMap();
    }

    return _swarmOperationAckHandler->publishAck(vehicleId, operationType, result, oldValue, newValue);
}

void ClusterManager::clearLastAck()
{
    _ackAvailable = false;
    _lastAckVehicleId = -1;
    _lastAckOperationType = SwarmOperationAckHandler::OperationUnknown;
    _lastAckResult = -1;
    _lastAckOldValue = 0;
    _lastAckNewValue = 0;
    _lastAckMessage.clear();
    _lastAckSuccess = false;
    emit ackChanged();
}

void ClusterManager::_handleActiveVehicleChanged(Vehicle *vehicle)
{
    Q_UNUSED(vehicle);
    _syncAssignmentsFromVehicles();
    emit activeVehicleClusterStateChanged();
}

void ClusterManager::_handleVehicleAdded(Vehicle *vehicle)
{
    Q_UNUSED(vehicle);
    _syncAssignmentsFromVehicles();
}

void ClusterManager::_handleVehicleRemoved(Vehicle *vehicle)
{
    if (!vehicle) {
        return;
    }

    SwarmUiSharedState::instance().removeVehicle(vehicle->id());
    _syncAssignmentsFromVehicles();
}

void ClusterManager::_handleOperationAckReceived(const QVariantMap &result)
{
    _setLastAck(result);
}

Vehicle *ClusterManager::_activeVehicle() const
{
    MultiVehicleManager *const multiVehicleManager = MultiVehicleManager::instance();
    return multiVehicleManager ? multiVehicleManager->activeVehicle() : nullptr;
}

bool ClusterManager::_vehicleExists(int vehicleId) const
{
    MultiVehicleManager *const multiVehicleManager = MultiVehicleManager::instance();
    return multiVehicleManager && (multiVehicleManager->getVehicleById(vehicleId) != nullptr);
}

int ClusterManager::_assignedVehicleCountForGroup(int groupId) const
{
    int count = 0;
    for (auto it = _assignments.cbegin(); it != _assignments.cend(); ++it) {
        if (it->groupId == groupId) {
            count++;
        }
    }

    return count;
}

QVariantMap ClusterManager::_buildLocalResult(ResultCode code, const QString &action, int groupId, const QString &message) const
{
    QVariantMap result;
    result[QStringLiteral("success")] = (code == ResultSuccess);
    result[QStringLiteral("code")] = code;
    result[QStringLiteral("action")] = action;
    result[QStringLiteral("groupId")] = groupId;
    result[QStringLiteral("message")] = message;
    return result;
}

bool ClusterManager::_clearVehicleAssignmentInternal(int vehicleId, bool syncToVehicle)
{
    if (vehicleGroup(vehicleId) < 1) {
        return false;
    }

    if (syncToVehicle && _swarmCommandBridge) {
        _setLastCommandResult(_swarmCommandBridge->clearVehicleAssignment(vehicleId));
    } else if (syncToVehicle) {
        _setLastCommandResult(_buildLocalResult(ResultSuccess, QStringLiteral("clear-assignment"), -1, tr("Vehicle %1 cluster assignment was cleared locally.").arg(vehicleId)));
    }

    _refreshAndEmitIfChanged();
    return true;
}

QVariantMap ClusterManager::_runGroupCommand(const QString &action, int groupId)
{
    if (!_swarmCommandBridge) {
        QVariantMap result;
        result[QStringLiteral("success")] = false;
        result[QStringLiteral("code")] = SwarmCommandBridge::ResultError;
        result[QStringLiteral("action")] = action;
        result[QStringLiteral("groupId")] = groupId;
        result[QStringLiteral("message")] = tr("Cluster bridge is unavailable.");
        _setLastCommandResult(result);
        return result;
    }

    const int assignedVehicleCount = _assignedVehicleCountForGroup(groupId);
    QVariantMap result;

    if (action == QStringLiteral("arm")) {
        result = _swarmCommandBridge->armGroup(groupId, assignedVehicleCount);
    } else if (action == QStringLiteral("disarm")) {
        result = _swarmCommandBridge->disarmGroup(groupId, assignedVehicleCount);
    } else if (action == QStringLiteral("takeoff")) {
        result = _swarmCommandBridge->takeoffGroup(groupId, assignedVehicleCount);
    } else if (action == QStringLiteral("land")) {
        result = _swarmCommandBridge->landGroup(groupId, assignedVehicleCount);
    } else if (action == QStringLiteral("pause")) {
        result = _swarmCommandBridge->pauseGroup(groupId, assignedVehicleCount);
    } else if (action == QStringLiteral("resume")) {
        result = _swarmCommandBridge->resumeGroup(groupId, assignedVehicleCount);
    } else {
        result[QStringLiteral("success")] = false;
        result[QStringLiteral("code")] = SwarmCommandBridge::ResultError;
        result[QStringLiteral("action")] = action;
        result[QStringLiteral("groupId")] = groupId;
        result[QStringLiteral("message")] = tr("Unknown cluster command: %1").arg(action);
    }

    _setLastCommandResult(result);
    return result;
}

void ClusterManager::_setLastCommandResult(const QVariantMap &result)
{
    _lastCommandAction = result.value(QStringLiteral("action")).toString();
    _lastCommandGroup = result.value(QStringLiteral("groupId"), -1).toInt();
    _lastCommandCode = result.value(QStringLiteral("code"), -1).toInt();
    _lastCommandMessage = result.value(QStringLiteral("message")).toString();
    _lastCommandSuccess = result.value(QStringLiteral("success")).toBool();
    emit lastCommandResultChanged();
}

void ClusterManager::_setLastAck(const QVariantMap &result)
{
    _ackAvailable = true;
    _lastAckVehicleId = result.value(QStringLiteral("vehicleId"), -1).toInt();
    _lastAckOperationType = result.value(QStringLiteral("operationType"), SwarmOperationAckHandler::OperationUnknown).toInt();
    _lastAckResult = result.value(QStringLiteral("result"), -1).toInt();
    _lastAckOldValue = result.value(QStringLiteral("oldValue"), 0).toInt();
    _lastAckNewValue = result.value(QStringLiteral("newValue"), 0).toInt();
    _lastAckMessage = result.value(QStringLiteral("message")).toString();
    _lastAckSuccess = result.value(QStringLiteral("success")).toBool();
    emit ackChanged();
}

void ClusterManager::_emitAssignmentSignals(int vehicleId)
{
    emit assignmentsChanged();

    Vehicle *const vehicle = _activeVehicle();
    if (vehicle && (vehicle->id() == vehicleId)) {
        emit activeVehicleClusterStateChanged();
    }
}

void ClusterManager::_syncAssignmentsFromVehicles()
{
    SwarmUiSharedState::instance().refreshFromAllVehicles();

    QHash<int, VehicleAssignment> nextAssignments;
    MultiVehicleManager *const multiVehicleManager = MultiVehicleManager::instance();
    if (multiVehicleManager && multiVehicleManager->vehicles()) {
        for (int i = 0; i < multiVehicleManager->vehicles()->count(); ++i) {
            Vehicle *const vehicle = qobject_cast<Vehicle *>(multiVehicleManager->vehicles()->get(i));
            if (!vehicle) {
                continue;
            }

            const int vehicleId = vehicle->id();
            const int groupId = SwarmUiSharedState::instance().vehicleGroup(vehicleId);
            if (groupId < 1) {
                continue;
            }

            VehicleAssignment assignment;
            assignment.groupId = groupId;
            assignment.leader = SwarmUiSharedState::instance().vehicleLeader(vehicleId);
            nextAssignments.insert(vehicleId, assignment);
        }
    }

    if (_assignments == nextAssignments) {
        return;
    }

    _assignments = nextAssignments;
    emit assignmentsChanged();
    emit activeVehicleClusterStateChanged();
}

void ClusterManager::_refreshAndEmitIfChanged()
{
    _syncAssignmentsFromVehicles();
}
