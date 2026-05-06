#pragma once

#include <QtCore/QHash>
#include <QtCore/QList>
#include <QtCore/QVariantList>

class SwarmUiSharedState
{
public:
    static SwarmUiSharedState &instance();

    void setVehicleGroup(int vehicleId, int groupId);
    int cachedVehicleGroup(int vehicleId) const;
    int vehicleGroup(int vehicleId);
    int assignedCountForGroup(int groupId);
    QList<int> vehiclesInGroup(int groupId);

    void setVehicleLeader(int vehicleId, bool leader);
    bool cachedVehicleLeader(int vehicleId) const;
    bool vehicleLeader(int vehicleId);
    void setVehicleOffset(int vehicleId, double xOffset, double yOffset, double zOffset);
    QVariantList formationTargets() const;
    void removeVehicle(int vehicleId);
    void refreshFromVehicle(int vehicleId);
    void refreshFromAllVehicles();

private:
    void _refreshVehicleState(int vehicleId);

    QHash<int, int> _groupByVehicle;
    QHash<int, bool> _leaderByVehicle;

    struct VehicleOffset
    {
        double x = 0.0;
        double y = 0.0;
        double z = 0.0;
    };

    QHash<int, VehicleOffset> _offsetByVehicle;
};
