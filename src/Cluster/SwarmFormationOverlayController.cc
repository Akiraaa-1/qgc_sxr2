#include "SwarmFormationOverlayController.h"

#include "SwarmUiSharedState.h"

SwarmFormationOverlayController::SwarmFormationOverlayController(QObject *parent)
    : QObject(parent)
{
    refreshTargets();
}

void SwarmFormationOverlayController::refreshTargets()
{
    const QVariantList nextTargets = SwarmUiSharedState::instance().formationTargets();
    if (nextTargets == _targets) {
        return;
    }

    _targets = nextTargets;
    emit targetsChanged();
}
