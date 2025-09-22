#include "../../includes/am_types.h"

generic configuration NeighborDiscoveryC(int channel) {
    provides interface NeighborDiscovery;
}

implementation{
    components new NeighborDiscoveryP();
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

    components new TimerMilliC() as neighborTimer;  
    NeighborDiscoveryP.neighborTimer -> neighborTimer;

    components RandomC as Random;
    NeighborDiscoveryP.Random -> Random;

    components SimpleSendP;
    NeighborDiscoveryP.SimpleSend -> SimpleSendP;
}