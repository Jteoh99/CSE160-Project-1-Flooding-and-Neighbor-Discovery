/* FloodingC.nc
 * Configuration wrapper for FloodingP implementation.
 * Use with a channel AM type number (see includes/am_types.h) when instantiating.
 */

#include "../../includes/am_types.h"

generic configuration FloodingC(int channel) {
    provides interface Flooding;
}

implementation{
    components new FloodingP();
    Flooding = FloodingP.Flooding;

    // Timer used for aging and maintenance
    components new TimerMilliC() as floodTimer;
    FloodingP.floodTimer -> floodTimer;

    // Use project's SimpleSend implementation for sending
    components SimpleSendC(channel);
    FloodingP.SimpleSend -> SimpleSendC;
}
