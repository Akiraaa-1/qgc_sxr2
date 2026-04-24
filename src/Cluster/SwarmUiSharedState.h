#pragma once

#include <QtCore/QHash>
#include <QtCore/QList>

class SwarmUiSharedState
{
public:
    static SwarmUiSharedState &instance();

    void setVehicleGroup(int vehicleId, int groupId);
    int vehicleGroup(int vehicleId);
    int assignedCountForGroup(int groupId);
    QList<int> vehiclesInGroup(int groupId);

    void setVehicleLeader(int vehicleId, bool leader);
    bool vehicleLeader(int vehicleId);
    void removeVehicle(int vehicleId);
    void refreshFromVehicle(int vehicleId);
    void refreshFromAllVehicles();

private:
    void _refreshVehicleState(int vehicleId);

    QHash<int, int> _groupByVehicle;
    QHash<int, bool> _leaderByVehicle;
};
