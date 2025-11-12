from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.FLOODING_CHANNEL);
    s.addChannel(s.NEIGHBOR_CHANNEL);   
    s.addChannel(s.ROUTING_CHANNEL);

    # Wait for neighbor discovery to complete
    print("Waiting for neighbor discovery...")
    s.runTime(30);  # Increased from 20 to 30

    print("\nTest 1: Basic Link-State Functionality")
    
    # Test 1: Print link-state database
    print("Step 1: Print link-state database for Node 5")
    s.linkStateDMP(5);
    s.runTime(2);
    
    # Test 2: Print routing table  
    print("Step 2: Print routing table for Node 5")
    s.routeDMP(5);
    s.runTime(2);
    
    # Test 3: Wait for LSA propagation and check another node
    print("Step 3: Wait for LSA propagation (60 seconds)")  # Increased from 30 to 60
    s.runTime(60);
    
    print("Step 4: Print link-state database for Node 10")
    s.linkStateDMP(10);
    s.runTime(2);
    
    print("Step 5: Print routing table for Node 10")  
    s.routeDMP(10);
    s.runTime(2);
    
    # Test 4: Test routing functionality with a ping
    print("Step 6: Test routing with ping from Node 3 to Node 15")
    s.ping(3, 15, "Link-State Test");
    s.runTime(5);

if __name__ == '__main__':
    main()