/**
 * Flooding interface
 * Provides simple control for the Flooding module: start/stop and a debug printer.
 */
interface Flooding{
  /** Start flooding module (enable timers) */
  command void start();
  /** Stop flooding module (disable timers) */
  command void stop();
  /** Print neighbors / internal table to FLOODING_CHANNEL */
  command void printNeighbors();
}
