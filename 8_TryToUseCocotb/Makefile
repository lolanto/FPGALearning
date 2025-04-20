# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# PWD := $(shell cygpath -m $(shell pwd))
PWD := $(shell pwd)
$(info Current working directory: $(PWD))

VERILOG_SOURCES += $(PWD)/test_top.v
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = Top

# MODULE is the basename of the Python test file
MODULE = test_my_design

PYTHON_ARCH = 64bit

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim