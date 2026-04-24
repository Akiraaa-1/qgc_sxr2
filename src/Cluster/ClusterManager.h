#pragma once

#include <QtCore/QHash>
#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>
#include <QtQmlIntegration/QtQmlIntegration>

#include "SwarmCommandBridge.h"
#include "SwarmOperationAckHandler.h"

class Vehicle;

Q_DECLARE_LOGGING_CATEGORY(ClusterManagerLog)

class ClusterManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_MOC_INCLUDE("Vehicle.h")

    Q_PROPERTY(int assignedVehicleCount READ assignedVehicleCount NOTIFY assignmentsChanged)
    Q_PROPERTY(int leaderCount READ leaderCount NOTIFY assignmentsChanged)
    Q_PROPERTY(int groupCount READ groupCount CONSTANT)
    Q_PROPERTY(int activeVehicleGroup READ activeVehicleGroup NOTIFY activeVehicleClusterStateChanged)
    Q_PROPERTY(bool activeVehicleLeader READ activeVehicleLeader NOTIFY activeVehicleClusterStateChanged)
    Q_PROPERTY(QVariantList groupSummary READ groupSummary NOTIFY assignmentsChanged)
    Q_PROPERTY(QString lastCommandAction READ lastCommandAction NOTIFY lastCommandResultChanged)
    Q_PROPERTY(int lastCommandGroup READ lastCommandGroup NOTIFY lastCommandResultChanged)
    Q_PROPERTY(int lastCommandCode READ lastCommandCode NOTIFY lastCommandResultChanged)
    Q_PROPERTY(QString lastCommandMessage READ lastCommandMessage NOTIFY lastCommandResultChanged)
    Q_PROPERTY(bool lastCommandSuccess READ lastCommandSuccess NOTIFY lastCommandResultChanged)
    Q_PROPERTY(bool ackAvailable READ ackAvailable NOTIFY ackChanged)
    Q_PROPERTY(int lastAckVehicleId READ lastAckVehicleId NOTIFY ackChanged)
    Q_PROPERTY(int lastAckOperationType READ lastAckOperationType NOTIFY ackChanged)
    Q_PROPERTY(int lastAckResult READ lastAckResult NOTIFY ackChanged)
    Q_PROPERTY(int lastAckOldValue READ lastAckOldValue NOTIFY ackChanged)
    Q_PROPERTY(int lastAckNewValue READ lastAckNewValue NOTIFY ackChanged)
    Q_PROPERTY(QString lastAckMessage READ lastAckMessage NOTIFY ackChanged)
    Q_PROPERTY(bool lastAckSuccess READ lastAckSuccess NOTIFY ackChanged)

public:
    enum ResultCode {
        ResultSuccess = SwarmCommandBridge::ResultSuccess,
        ResultError = SwarmCommandBridge::ResultError,
        ResultNoGroupAssigned = SwarmCommandBridge::ResultNoGroupAssigned,
        ResultNotImplemented = SwarmCommandBridge::ResultNotImplemented,
    };
    Q_ENUM(ResultCode)

    explicit ClusterManager(QObject *parent = nullptr);

    int assignedVehicleCount() const;
    int leaderCount() const;
    int groupCount() const { return 4; }
    int activeVehicleGroup() const;
    bool activeVehicleLeader() const;
    QVariantList groupSummary() const;
    QString lastCommandAction() const { return _lastCommandAction; }
    int lastCommandGroup() const { return _lastCommandGroup; }
    int lastCommandCode() const { return _lastCommandCode; }
    QString lastCommandMessage() const { return _lastCommandMessage; }
    bool lastCommandSuccess() const { return _lastCommandSuccess; }
    bool ackAvailable() const { return _ackAvailable; }
    int lastAckVehicleId() const { return _lastAckVehicleId; }
    int lastAckOperationType() const { return _lastAckOperationType; }
    int lastAckResult() const { return _lastAckResult; }
    int lastAckOldValue() const { return _lastAckOldValue; }
    int lastAckNewValue() const { return _lastAckNewValue; }
    QString lastAckMessage() const { return _lastAckMessage; }
    bool lastAckSuccess() const { return _lastAckSuccess; }

    Q_INVOKABLE int vehicleGroup(int vehicleId) const;
    Q_INVOKABLE bool vehicleLeader(int vehicleId) const;
    Q_INVOKABLE void assignVehicleToGroup(int vehicleId, int groupId);
    Q_INVOKABLE void assignActiveVehicleToGroup(int groupId);
    Q_INVOKABLE void clearVehicleAssignment(int vehicleId);
    Q_INVOKABLE void clearActiveVehicleAssignment();
    Q_INVOKABLE void toggleLeaderForVehicle(int vehicleId);
    Q_INVOKABLE void toggleLeaderForActiveVehicle();
    Q_INVOKABLE void clearAllAssignments();
    Q_INVOKABLE void clearLastCommandResult();
    Q_INVOKABLE QVariantMap armGroup(int groupId);
    Q_INVOKABLE QVariantMap disarmGroup(int groupId);
    Q_INVOKABLE QVariantMap takeoffGroup(int groupId);
    Q_INVOKABLE QVariantMap landGroup(int groupId);
    Q_INVOKABLE QVariantMap pauseGroup(int groupId);
    Q_INVOKABLE QVariantMap resumeGroup(int groupId);
    Q_INVOKABLE QVariantMap ingestOperationAck(int vehicleId, int operationType, int result, int oldValue, int newValue);
    Q_INVOKABLE void clearLastAck();

signals:
    void assignmentsChanged();
    void activeVehicleClusterStateChanged();
    void lastCommandResultChanged();
    void ackChanged();

private slots:
    void _handleActiveVehicleChanged(Vehicle *vehicle);
    void _handleVehicleRemoved(Vehicle *vehicle);
    void _handleOperationAckReceived(const QVariantMap &result);

private:
    struct VehicleAssignment
    {
        int groupId = -1;
        bool leader = false;
    };

    [[nodiscard]] Vehicle *_activeVehicle() const;
    [[nodiscard]] bool _vehicleExists(int vehicleId) const;
    int _assignedVehicleCountForGroup(int groupId) const;
    QVariantMap _buildLocalResult(ResultCode code, const QString &action, int groupId, const QString &message) const;
    bool _clearVehicleAssignmentInternal(int vehicleId, bool syncToVehicle);
    QVariantMap _runGroupCommand(const QString &action, int groupId);
    void _setLastCommandResult(const QVariantMap &result);
    void _setLastAck(const QVariantMap &result);
    void _emitAssignmentSignals(int vehicleId);

    QHash<int, VehicleAssignment> _assignments;
    SwarmCommandBridge *_swarmCommandBridge = nullptr;
    SwarmOperationAckHandler *_swarmOperationAckHandler = nullptr;
    QString _lastCommandAction;
    int _lastCommandGroup = -1;
    int _lastCommandCode = -1;
    QString _lastCommandMessage;
    bool _lastCommandSuccess = false;
    bool _ackAvailable = false;
    int _lastAckVehicleId = -1;
    int _lastAckOperationType = SwarmOperationAckHandler::OperationUnknown;
    int _lastAckResult = -1;
    int _lastAckOldValue = 0;
    int _lastAckNewValue = 0;
    QString _lastAckMessage;
    bool _lastAckSuccess = false;
};
