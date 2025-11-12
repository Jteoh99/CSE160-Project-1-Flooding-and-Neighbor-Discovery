#include "../../includes/am_types.h"

configuration LinkStateC {
    provides interface LinkState;
    uses interface NeighborDiscover;
}

implementation{
    components LinkStateP;
    LinkState = LinkStateP.LinkState;

    // Timer for periodic LSA generation
    components new TimerMilliC() as LSATimerC;
    LinkStateP.LSATimer -> LSATimerC;

    // Timer for routing table calculation
    components new TimerMilliC() as CalculationTimerC;
    LinkStateP.CalculationTimer -> CalculationTimerC;

    // Random component for timing variations
    components RandomC;
    LinkStateP.Random -> RandomC.Random;

    // Use flooding for link-state packet transmission
    components new SimpleSendC(AM_FLOODING) as LSASendC;
    LinkStateP.SimpleSend -> LSASendC;

    // Wire NeighborDiscover interface
    LinkStateP.NeighborDiscover = NeighborDiscover;
}