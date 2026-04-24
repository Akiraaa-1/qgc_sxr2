#pragma once

#include <QtCore/QObject>
#include <QtQmlIntegration/QtQmlIntegration>

#include "SwarmCommandBridge.h"

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
    void _emitOperationResult(int operationType, const QVariantMap &result);

    SwarmCommandBridge _bridge;
};
