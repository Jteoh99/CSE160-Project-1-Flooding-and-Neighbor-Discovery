/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/protocol.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   // Remove Receive interface - FloodingC handles all packet reception

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface Flooding;
   uses interface NeighborDiscover;
}

implementation{
   pack sendPackage;
   uint16_t sequenceNum = 0;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();

      //dbg(GENERAL_CHANNEL, "Node booted and wiring check\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         call NeighborDiscover.findNeighbors();
         call NeighborDiscover.printNeighbors();
         call Flooding.start(); // Start the flooding module
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   // Remove Receive.receive event - FloodingC handles all packet reception now

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      uint16_t* neighbors;
      uint8_t numNeighbors;
      
      dbg(FLOODING_CHANNEL, "PING_START: Node %hu pinging Node %hu (seq=%hu, payload='%s')\n", 
          TOS_NODE_ID, destination, sequenceNum, payload);
      makePack(&sendPackage, TOS_NODE_ID, destination, 30, PROTOCOL_PING, sequenceNum++, payload, PACKET_MAX_PAYLOAD_SIZE);
      
      // Get neighbors and send through flooding module
      neighbors = call NeighborDiscover.getNeighbors();
      numNeighbors = call NeighborDiscover.getNumNeighbors();
      
      if (numNeighbors > 0) {
         dbg(FLOODING_CHANNEL, "PING_SEND: Node %hu sending via flooding to all neighbors (dest=%hu)\n", 
             TOS_NODE_ID, destination);
         call Flooding.send(&sendPackage, 0); // dest parameter ignored, floods to all neighbors
      } else {
         dbg(FLOODING_CHANNEL, "PING_FAIL: Node %hu has no neighbors to send to\n", TOS_NODE_ID);
      }
   }

   event void CommandHandler.printNeighbors(){
      // Call the NeighborDiscover interface to print neighbors
      call NeighborDiscover.printNeighbors();
   }

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
