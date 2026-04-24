#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QVariantMap>

Q_DECLARE_LOGGING_CATEGORY(SwarmOperationAckHandlerLog)

class SwarmOperationAckHandler : public QObject
{
    Q_OBJECT

public:
    enum OperationType {
        OperationUnknown = 0,
        OperationGroupChange = 1,
        OperationLeaderChange = 2,
        OperationArm = 3,
        OperationDisarm = 4,
        OperationTakeoff = 5,
        OperationLand = 6,
        OperationPause = 7,
        OperationResume = 8,
    };
    Q_ENUM(OperationType)

    enum AckResult {
        AckSuccess = 0,
        AckFailed = 1,
    };
    Q_ENUM(AckResult)

    explicit SwarmOperationAckHandler(QObject *parent = nullptr);

    QVariantMap buildAckResult(int vehicleId, int operationType, int result, int oldValue, int newValue) const;
    QVariantMap publishAck(int vehicleId, int operationType, int result, int oldValue, int newValue);
    QString operationText(int operationType) const;
    QString resultText(int result) const;

signals:
    void operationAckReceived(const QVariantMap &result);
};
