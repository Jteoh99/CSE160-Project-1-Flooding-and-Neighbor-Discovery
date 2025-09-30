#include "../../includes/am_types.h"

generic configuration FloodingC(int channel) {
    provides interface Flooding;
}

implementation{
    components FloodingP;
    Flooding = FloodingP.Flooding;

    // Timer used for aging and maintenance
    components new TimerMilliC() as floodTimer;
    FloodingP.floodTimer -> floodTimer;

    // Use project's SimpleSend implementation for sending
    components new SimpleSendC(channel) as FloodSend;
    FloodingP.SimpleSend -> FloodSend;
}
