#pragma once

#include <QtCore/QObject>
#include <QtCore/QVariantMap>
#include <QtQmlIntegration/QtQmlIntegration>

class LinkInterface;
class Vehicle;
struct __mavlink_message;
typedef struct __mavlink_message mavlink_message_t;

class SwarmUiCommandController : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Mavlinktest2)

public:
    explicit SwarmUiCommandController(QObject *parent = nullptr);

    Q_INVOKABLE void _sendcom(int test1, int test2, int test3, int pause, int conti);

signals:
    void swarmOperationAckReceived(int sysId, int opType, int result, int oldValue, int newValue, const QString &message);

private:
    void _handleActiveVehicleChanged(Vehicle *vehicle);
    void _receiveMessage(LinkInterface *link, const mavlink_message_t &message);
    QString _formatOperationAckMessage(int sysId, int operationType, int result, int oldValue, int newValue) const;
    void _emitOperationResult(int operationType, const QVariantMap &result);
    bool _sendSwarmStartFlag(Vehicle *vehicle, int startAuto, int groupId, int stop, int pause, int resume) const;
    bool _echoUavInfo(Vehicle *vehicle, const mavlink_message_t &incomingMessage) const;

    Vehicle *_vehicle = nullptr;
};
