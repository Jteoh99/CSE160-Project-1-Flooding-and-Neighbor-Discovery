#include "../../includes/am_types.h"

generic configuration FloodingC(int channel) {
    provides interface Flooding;
    provides interface NeighborDiscover;
}

implementation{
    components FloodingP;
    Flooding = FloodingP.Flooding;

    // Wire packet reception using AM_FLOODING
    components new AMReceiverC(AM_FLOODING) as FloodReceive;
    FloodingP.Receive -> FloodReceive;
    
    // Wire beacon reception using AM_PACK for neighbor discovery
    components new AMReceiverC(AM_PACK) as BeaconReceive;
    FloodingP.BeaconReceive -> BeaconReceive;
    
    // Wire AMPacket interface for getting sender information
    components ActiveMessageC;
    FloodingP.AMPacket -> ActiveMessageC;

    // Timer used for aging and maintenance
    components new TimerMilliC() as floodTimer;
    FloodingP.floodTimer -> floodTimer;

    // Use AM_FLOODING for flooding packets
    components new SimpleSendC(AM_FLOODING) as FloodSend;
    FloodingP.SimpleSend -> FloodSend;

    // Use AM_PACK for neighbor discovery (beacons) - separate from flooding
    components new NeighborDiscoverC(AM_PACK) as NeighborDiscoverC;
    FloodingP.NeighborDiscover -> NeighborDiscoverC;
    NeighborDiscover = NeighborDiscoverC;
}
