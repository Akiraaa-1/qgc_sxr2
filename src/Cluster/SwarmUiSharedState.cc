#include "SwarmUiSharedState.h"

#include "Fact.h"
#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "Vehicle.h"

#include <QtCore/QVariantMap>
#include <QtPositioning/QGeoCoordinate>

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

int SwarmUiSharedState::cachedVehicleGroup(int vehicleId) const
{
    return _groupByVehicle.value(vehicleId, -1);
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

bool SwarmUiSharedState::cachedVehicleLeader(int vehicleId) const
{
    return _leaderByVehicle.value(vehicleId, false);
}

bool SwarmUiSharedState::vehicleLeader(int vehicleId)
{
    _refreshVehicleState(vehicleId);
    return _leaderByVehicle.value(vehicleId, false);
}

void SwarmUiSharedState::setVehicleOffset(int vehicleId, double xOffset, double yOffset, double zOffset)
{
    _offsetByVehicle.insert(vehicleId, VehicleOffset { xOffset, yOffset, zOffset });
}

QVariantList SwarmUiSharedState::formationTargets() const
{
    QVariantList targets;

    MultiVehicleManager *const manager = MultiVehicleManager::instance();
    if (!manager) {
        return targets;
    }

    QHash<int, int> leaderByGroup;
    for (auto it = _leaderByVehicle.cbegin(); it != _leaderByVehicle.cend(); ++it) {
        if (!it.value()) {
            continue;
        }

        const int groupId = _groupByVehicle.value(it.key(), -1);
        if (groupId > 0) {
            leaderByGroup.insert(groupId, it.key());
        }
    }

    for (auto it = _offsetByVehicle.cbegin(); it != _offsetByVehicle.cend(); ++it) {
        const int groupId = _groupByVehicle.value(it.key(), -1);
        if ((groupId < 1) || leaderByGroup.contains(groupId)) {
            continue;
        }

        const VehicleOffset offset = it.value();
        if (qFuzzyIsNull(offset.x) && qFuzzyIsNull(offset.y) && qFuzzyIsNull(offset.z)) {
            leaderByGroup.insert(groupId, it.key());
        }
    }

    for (auto it = _groupByVehicle.cbegin(); it != _groupByVehicle.cend(); ++it) {
        if ((it.value() > 0) && !leaderByGroup.contains(it.value())) {
            leaderByGroup.insert(it.value(), it.key());
        }
    }

    for (auto it = _offsetByVehicle.cbegin(); it != _offsetByVehicle.cend(); ++it) {
        const int vehicleId = it.key();
        const int groupId = _groupByVehicle.value(vehicleId, -1);
        if (groupId < 1) {
            continue;
        }

        const int leaderId = leaderByGroup.value(groupId, -1);
        Vehicle *const leaderVehicle = leaderId > 0 ? manager->getVehicleById(leaderId) : nullptr;
        Vehicle *const vehicle = manager->getVehicleById(vehicleId);
        if (!leaderVehicle || !vehicle) {
            continue;
        }

        const QGeoCoordinate leaderCoordinate = leaderVehicle->coordinate();
        if (!leaderCoordinate.isValid()) {
            continue;
        }

        const VehicleOffset offset = it.value();
        QGeoCoordinate targetCoordinate = leaderCoordinate.atDistanceAndAzimuth(offset.x, 90.0);
        targetCoordinate = targetCoordinate.atDistanceAndAzimuth(offset.y, 0.0);
        if (leaderCoordinate.type() == QGeoCoordinate::Coordinate3D) {
            targetCoordinate.setAltitude(leaderCoordinate.altitude() + offset.z);
        }

        QVariantMap target;
        target[QStringLiteral("vehicleId")] = vehicleId;
        target[QStringLiteral("groupId")] = groupId;
        target[QStringLiteral("leaderId")] = leaderId;
        target[QStringLiteral("isLeader")] = (vehicleId == leaderId);
        target[QStringLiteral("coordinate")] = QVariant::fromValue(targetCoordinate);
        target[QStringLiteral("actualCoordinate")] = QVariant::fromValue(vehicle->coordinate());
        target[QStringLiteral("xOffset")] = offset.x;
        target[QStringLiteral("yOffset")] = offset.y;
        target[QStringLiteral("zOffset")] = offset.z;
        targets.append(target);
    }

    return targets;
}

void SwarmUiSharedState::removeVehicle(int vehicleId)
{
    _groupByVehicle.remove(vehicleId);
    _leaderByVehicle.remove(vehicleId);
    _offsetByVehicle.remove(vehicleId);
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
