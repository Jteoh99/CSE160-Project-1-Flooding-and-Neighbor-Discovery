from TestSim import TestSim

# Small test: 3-node line topology

def main():
    s = TestSim()
    s.runTime(1)
    # create a tiny topology file on the fly using existing reading method isn't trivial
    # We'll rely on existing topo/long_line.topo but only use first 3 nodes by setting numMote
    s.loadTopo("long_line.topo")
    s.loadNoise("no_noise.txt")
    s.bootAll()
    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.GENERAL_CHANNEL)
    s.addChannel(s.FLOODING_CHANNEL)
    s.addChannel(s.NEIGHBOR_CHANNEL)

    s.runTime(1)
    # Ping: use TestSim.ping which sends a CommandMsg that Node's CommandHandler.ping event receives
    s.ping(1, 2, "Hello from 1 to 2")
    s.runTime(5)

if __name__ == '__main__':
    main()
