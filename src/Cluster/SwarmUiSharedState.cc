#include "SwarmUiSharedState.h"

#include "Fact.h"
#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "Vehicle.h"

SwarmUiSharedState &SwarmUiSharedState::instance()
{
    static SwarmUiSharedState instance;
    return instance;
}

void SwarmUiSharedState::setVehicleGroup(int vehicleId, int groupId)
{
    if (groupId > 0) {
        _groupByVehicle.insert(vehicleId, groupId);
    } else {
        _groupByVehicle.remove(vehicleId);
    }
}

int SwarmUiSharedState::vehicleGroup(int vehicleId)
{
    _refreshVehicleState(vehicleId);
    return _groupByVehicle.value(vehicleId, -1);
}

int SwarmUiSharedState::assignedCountForGroup(int groupId)
{
    refreshFromAllVehicles();

    int count = 0;
    for (auto it = _groupByVehicle.cbegin(); it != _groupByVehicle.cend(); ++it) {
        if (it.value() == groupId) {
            count++;
        }
    }

    return count;
}

QList<int> SwarmUiSharedState::vehiclesInGroup(int groupId)
{
    refreshFromAllVehicles();

    QList<int> vehicles;
    for (auto it = _groupByVehicle.cbegin(); it != _groupByVehicle.cend(); ++it) {
        if (it.value() == groupId) {
            vehicles.append(it.key());
        }
    }

    return vehicles;
}

void SwarmUiSharedState::setVehicleLeader(int vehicleId, bool leader)
{
    _leaderByVehicle.insert(vehicleId, leader);
}

bool SwarmUiSharedState::vehicleLeader(int vehicleId)
{
    _refreshVehicleState(vehicleId);
    return _leaderByVehicle.value(vehicleId, false);
}

void SwarmUiSharedState::removeVehicle(int vehicleId)
{
    _groupByVehicle.remove(vehicleId);
    _leaderByVehicle.remove(vehicleId);
}

void SwarmUiSharedState::refreshFromVehicle(int vehicleId)
{
    _refreshVehicleState(vehicleId);
}

void SwarmUiSharedState::refreshFromAllVehicles()
{
    MultiVehicleManager *const manager = MultiVehicleManager::instance();
    if (!manager || !manager->vehicles()) {
        return;
    }

    QList<int> activeVehicleIds;
    for (int i = 0; i < manager->vehicles()->count(); ++i) {
        Vehicle *const vehicle = qobject_cast<Vehicle *>(manager->vehicles()->get(i));
        if (!vehicle) {
            continue;
        }

        activeVehicleIds.append(vehicle->id());
        _refreshVehicleState(vehicle->id());
    }

    for (auto it = _groupByVehicle.begin(); it != _groupByVehicle.end();) {
        if (!activeVehicleIds.contains(it.key())) {
            _leaderByVehicle.remove(it.key());
            it = _groupByVehicle.erase(it);
        } else {
            ++it;
        }
    }
}

void SwarmUiSharedState::_refreshVehicleState(int vehicleId)
{
    MultiVehicleManager *const manager = MultiVehicleManager::instance();
    Vehicle *const vehicle = manager ? manager->getVehicleById(vehicleId) : nullptr;
    if (!vehicle) {
        removeVehicle(vehicleId);
        return;
    }

    ParameterManager *const parameterManager = vehicle->parameterManager();
    if (!parameterManager || !parameterManager->parametersReady()) {
        if (!_groupByVehicle.contains(vehicleId)) {
            _groupByVehicle.insert(vehicleId, 1);
        }
        return;
    }

    if (parameterManager->parameterExists(ParameterManager::defaultComponentId, QStringLiteral("SWARM_GROUP_ID"))) {
        Fact *const groupFact = parameterManager->getParameter(ParameterManager::defaultComponentId, QStringLiteral("SWARM_GROUP_ID"));
        if (groupFact) {
            const int groupId = groupFact->rawValue().toInt();
            if (groupId > 0) {
                _groupByVehicle.insert(vehicleId, groupId);
            } else {
                _groupByVehicle.remove(vehicleId);
            }
        }
    } else if (!_groupByVehicle.contains(vehicleId)) {
        _groupByVehicle.insert(vehicleId, 1);
    }

    if (parameterManager->parameterExists(ParameterManager::defaultComponentId, QStringLiteral("SWARM_SET_LEADER"))) {
        Fact *const leaderFact = parameterManager->getParameter(ParameterManager::defaultComponentId, QStringLiteral("SWARM_SET_LEADER"));
        if (leaderFact) {
            _leaderByVehicle.insert(vehicleId, leaderFact->rawValue().toInt() != 0);
        }
    }
}
