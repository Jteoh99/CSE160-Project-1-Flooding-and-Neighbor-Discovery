#include "../../includes/am_types.h"

generic configuration FloodingC(int channel) {
    provides interface Flooding;
    provides interface NeighborDiscover;
}

implementation{
    components FloodingP;
    Flooding = FloodingP.Flooding;

    // Wire packet reception
    components new AMReceiverC(channel) as FloodReceive;
    FloodingP.Receive -> FloodReceive;

    // Timer used for aging and maintenance
    components new TimerMilliC() as floodTimer;
    FloodingP.floodTimer -> floodTimer;

    // Use project's SimpleSend implementation for sending
    components new SimpleSendC(channel) as FloodSend;
    FloodingP.SimpleSend -> FloodSend;

    // Wire NeighborDiscover interface
    components new NeighborDiscoverC(channel) as NeighborDiscoverC;
    FloodingP.NeighborDiscover -> NeighborDiscoverC;
    NeighborDiscover = NeighborDiscoverC;
}
