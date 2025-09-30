configuration NodeAppC {
	provides interface Boot;
}

implementation {
	components MainC, NodeC, CommandHandlerC;

	components new AMReceiverC(AM_FLOODING) as FloodingReceive;

	// Instantiate Flooding and NeighborDiscovery modules
	components FloodingC(AM_FLOODING);
	components NeighborDiscoverC(AM_PACK);

	// Wire Flooding receive to the AM receiver for the flooding AM type
	FloodingC.Receive -> FloodingReceive;

	// Wire NodeC's Flooding and NeighborDiscovery uses to the components
	NodeC.Flooding -> FloodingC;
	NodeC.NeighborDiscover -> NeighborDiscoverC;

	// Boot comes from NodeC
	Boot = NodeC;

	// Wire NodeC to CommandHandlerC and let NodeC keep its existing Sender binding
	NodeC.CommandHandler -> CommandHandlerC;
}
