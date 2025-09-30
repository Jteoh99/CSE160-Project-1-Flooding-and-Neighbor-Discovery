#include "../../includes/am_types.h"

generic configuration NeighborDiscoverC(int channel) {
    provides interface NeighborDiscover;
}

implementation{
    components new NeighborDiscoverP();
    NeighborDiscover = NeighborDiscoverP.NeighborDiscover;

    components new TimerMilliC() as neighborTimer;  
    NeighborDiscoverP.neighborTimer -> neighborTimer;

    components RandomC as Random;
    NeighborDiscoverP.Random -> Random;

    components new SimpleSendC(channel) as NDSSend;
    NeighborDiscoverP.SimpleSend -> NDSSend;
}