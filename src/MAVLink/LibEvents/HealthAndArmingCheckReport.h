#pragma once

#include <libevents_includes.h>

#include <QtCore/QObject>
#include <QtCore/QString>

class QmlObjectListModel;

class HealthAndArmingCheckProblem : public QObject
{
    Q_OBJECT
public:
    HealthAndArmingCheckProblem(const QString& message, const QString& description, const QString& severity)
    : _message(message), _description(description), _severity(severity) {}

    Q_PROPERTY(QString message                            READ message                CONSTANT)
    Q_PROPERTY(QString description                        READ description            CONSTANT)
    Q_PROPERTY(QString severity                           READ severity               CONSTANT)
    Q_PROPERTY(bool expanded                              READ expanded               WRITE setExpanded NOTIFY expandedChanged)

    const QString& message() const { return _message; }
    const QString& description() const { return _description; }
    const QString& severity() const { return _severity; }

    bool expanded() const { return _expanded; }
    void setExpanded(bool expanded) { _expanded = expanded; emit expandedChanged(); }

signals:
    void expandedChanged();
private:
    const QString _message;
    const QString _description;
    const QString _severity;
    bool _expanded{false};
};


class HealthAndArmingCheckReport : public QObject
{
    Q_OBJECT
    Q_MOC_INCLUDE("QmlObjectListModel.h")
public:

    Q_PROPERTY(bool supported                              READ supported               NOTIFY updated)
    Q_PROPERTY(bool healthAndArmingChecksSupported         READ healthAndArmingChecksSupported NOTIFY updated)
    Q_PROPERTY(bool capabilityKnown                        READ capabilityKnown         NOTIFY updated)
    Q_PROPERTY(bool valid                                  READ valid                   NOTIFY updated)
    Q_PROPERTY(bool armCheckValid                          READ armCheckValid           NOTIFY updated)
    Q_PROPERTY(bool canArm                                 READ canArm                  NOTIFY updated)
    Q_PROPERTY(bool takeoffCheckValid                      READ takeoffCheckValid       NOTIFY updated)
    Q_PROPERTY(bool canTakeoff                             READ canTakeoff              NOTIFY updated)
    Q_PROPERTY(bool missionStartCheckValid                 READ missionStartCheckValid  NOTIFY updated)
    Q_PROPERTY(bool canStartMission                        READ canStartMission         NOTIFY updated)
    Q_PROPERTY(bool missionResumeCheckValid                READ missionResumeCheckValid NOTIFY updated)
    Q_PROPERTY(bool canResumeMission                       READ canResumeMission        NOTIFY updated)
    Q_PROPERTY(bool hasWarningsOrErrors                    READ hasWarningsOrErrors     NOTIFY updated)
    Q_PROPERTY(QString gpsState                            READ gpsState                NOTIFY updated)
    Q_PROPERTY(QmlObjectListModel* problemsForCurrentMode  READ problemsForCurrentMode  NOTIFY updated)

    HealthAndArmingCheckReport(QObject *parent = nullptr);
    virtual ~HealthAndArmingCheckReport();

    bool supported() const { return _supported; }
    bool healthAndArmingChecksSupported() const { return _healthAndArmingChecksSupported; }
    bool capabilityKnown() const { return _capabilityKnown; }
    bool valid() const { return _valid; }
    bool armCheckValid() const { return _valid && _currentModeMapped; }
    bool canArm() const { return _canArm; }
    bool takeoffCheckValid() const { return _valid && _takeoffModeGroup != -1; }
    bool canTakeoff() const { return _canTakeoff; }
    bool missionStartCheckValid() const { return _valid && _missionModeGroup != -1; }
    bool canStartMission() const { return _canStartMission; }
    bool missionResumeCheckValid() const { return _valid && _missionModeGroup != -1; }
    bool canResumeMission() const { return _canResumeMission; }
    bool hasWarningsOrErrors() const { return _hasWarningsOrErrors; }

    const QString& gpsState() const { return _gpsState; }

    QmlObjectListModel* problemsForCurrentMode() { return _problemsForCurrentMode; }

    void update(uint8_t compid, const events::HealthAndArmingChecks::Results& results, int flightModeGroup);

    void setHealthAndArmingChecksCapability(bool supported);
    void setModeGroups(int takeoffModeGroup, int missionModeGroup);
    void invalidate();

signals:
    void updated();

private:
    bool _supported{false};
    bool _healthAndArmingChecksSupported{false};
    bool _capabilityKnown{false};
    bool _valid{false};
    bool _currentModeMapped{false};
    bool _canArm{false}; ///< whether arming is possible for the current mode
    bool _canTakeoff{false};
    bool _canStartMission{false};
    bool _canResumeMission{false};
    bool _hasWarningsOrErrors{false};
    QString _gpsState{};

    int _takeoffModeGroup{-1};
    int _missionModeGroup{-1};

    QmlObjectListModel* _problemsForCurrentMode = nullptr; ///< list of HealthAndArmingCheckProblem*
};
