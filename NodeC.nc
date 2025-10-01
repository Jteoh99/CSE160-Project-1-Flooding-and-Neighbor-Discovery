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
    components new AMReceiverC(AM_PACK) as GeneralReceive;

    // Node receives the boot event from MainC
    Node -> MainC.Boot;

    // Node gets incoming data from GeneralReceive for AM_PACK
    Node.Receive -> GeneralReceive;

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

    // Use same channel for both Flooding and NeighborDiscover
    components new FloodingC(AM_PACK) as FloodingC;
}
