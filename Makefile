COMPONENT=NodeC


INCLUDE=-IdataStructures
INCLUDE+=-IdataStructures/interfaces/ -IdataStructures/modules
INCLUDE+=-Ilib/interfaces -Ilib/modules
CFLAGS += -DTOSH_DATA_LENGTH=28
CFLAGS+=$(INCLUDE)

# Convenience targets for generating TOSSIM Python bindings and running the sim
.PHONY: bindings sim

bindings: CommandMsg.py packet.py

CommandMsg.py: includes/CommandMsg.h
	nescc-mig python -python-classname=CommandMsg includes/CommandMsg.h CommandMsg -o $@

packet.py: includes/packet.h
	nescc-mig python -python-classname=pack includes/packet.h pack -o packet.py

# Run the simulator (requires TOSSIM and python in PATH). Use python2 if needed.
sim: bindings
	@echo "Running TestSim.py (ensure TOSSIM is installed and python is correct)"
	python TestSim.py

include $(TINYOS_ROOT_DIR)/Makefile.include
