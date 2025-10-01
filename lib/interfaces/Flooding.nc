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
}
