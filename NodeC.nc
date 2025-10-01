/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    // Remove Node's own receiver - let FloodingC handle all packet reception

    // Node receives the boot event from MainC
    Node -> MainC.Boot;

    // Node controls the radio through ActiveMessageC
    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    // Node uses SimpleSendC on AM_PACK for sending packets
    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    // Expose NeighborDiscover interface through FloodingC
    Node.NeighborDiscover -> FloodingC.NeighborDiscover;

    Node.Flooding -> FloodingC;

    // Use AM_FLOODING channel for Flooding module
    components new FloodingC(AM_FLOODING) as FloodingC;
}
