/**
 * Flooding interface
 * Provides simple control for the Flooding module: start/stop.
 */
interface Flooding{
  //Start flooding module (enable timers)
  command void start();
  //Stop flooding module (disable timers)
  command void stop();
  //Send a packet through the flooding protocol
  command error_t send(pack *packet, uint16_t dest);
  
  // Event signaled when a LinkState packet is received
  event void linkStateReceived(pack *packet);
  
  // Event signaled when a packet needs routing (not flooding)
  event uint16_t routePacket(pack *packet);
}
