/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 * docker run --rm -it --mount type=bind,source="C:\Users\jteoh\Dropbox\PC\Documents\GitHub\CSE160\CSE160 Project 1 Flooding and Neighbor Discovery",target=/workspace -w /workspace ucmercedandeslab/tinyos_debian:latest /bin/bash
 * make micaz sim
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
   // Remove Receive interface
   // FloodingC handles all packet reception

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface Flooding;
   uses interface NeighborDiscover;
   uses interface LinkState;
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
         call LinkState.start(); // Start the link state routing
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   // Remove Receive.receive event - FloodingC handles all packet reception now

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      uint16_t nextHop;
      
      dbg(GENERAL_CHANNEL, ">>> PING PREP: Node %hu preparing to ping Node %hu\n", 
          TOS_NODE_ID, destination);
      
      makePack(&sendPackage, TOS_NODE_ID, destination, 30, PROTOCOL_PING, sequenceNum++, payload, PACKET_MAX_PAYLOAD_SIZE);
      
      // Check if we have a route to the destination
      if (call LinkState.hasRoute(destination)) {
         nextHop = call LinkState.getNextHop(destination);
         dbg(GENERAL_CHANNEL, ">>> LINK-STATE ROUTE: to %hu via next-hop %hu\n", 
             destination, nextHop);
         call LinkState.route(&sendPackage, nextHop);
      } else {
         // No route available - fall back to flooding
         uint16_t* neighbors;
         uint8_t numNeighbors;
         
         neighbors = call NeighborDiscover.getNeighbors();
         numNeighbors = call NeighborDiscover.getNumNeighbors();
         
         if (numNeighbors > 0) {
            dbg(GENERAL_CHANNEL, ">>> FLOODING: No route to %hu, using flooding\n", destination);
            call Flooding.send(&sendPackage, 0); // dest parameter ignored, floods to all neighbors
         } else {
            dbg(GENERAL_CHANNEL, "!! ERROR: No neighbors to reach %hu\n", destination);
         }
      }
   }

   event void CommandHandler.printNeighbors(){
      // Call the NeighborDiscover interface to print neighbors
      call NeighborDiscover.printNeighbors();
   }

   event void CommandHandler.printRouteTable(){
      // Print link-state routing table
      call LinkState.printRoutingTable();
   }

   event void CommandHandler.printLinkState(){
      // Print link-state advertisements
      call LinkState.printLinkState();
   }

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   // Handle LinkState packets received through flooding
   event void Flooding.linkStateReceived(pack *packet) {
      call LinkState.receive(packet);
   }

   // Handle packet routing requests from flooding module
   event uint16_t Flooding.routePacket(pack *packet) {
      if (call LinkState.hasRoute(packet->dest)) {
         uint16_t nextHop = call LinkState.getNextHop(packet->dest);
         dbg(GENERAL_CHANNEL, ">>> ROUTING: [%hu->%hu] via next-hop %hu\n", 
             packet->src, packet->dest, nextHop);
         return nextHop;
      }
      dbg(GENERAL_CHANNEL, ">>> NO ROUTE: [%hu->%hu] will use flooding\n", 
          packet->src, packet->dest);
      // Return invalid route to indicate flooding should be used
      return 0xFFFF;
   }

   // Handle neighbor changes - trigger LSA updates
   event void NeighborDiscover.neighborsChanged() {
      call LinkState.updateLinkState();
   }

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
