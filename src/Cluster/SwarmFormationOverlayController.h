#pragma once

#include <QtCore/QObject>
#include <QtCore/QVariantList>
#include <QtQmlIntegration/QtQmlIntegration>

class SwarmFormationOverlayController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList targets READ targets NOTIFY targetsChanged)

public:
    explicit SwarmFormationOverlayController(QObject *parent = nullptr);

    QVariantList targets() const { return _targets; }

    Q_INVOKABLE void refreshTargets();

signals:
    void targetsChanged();

private:
    QVariantList _targets;
};
