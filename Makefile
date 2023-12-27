# Makefile

TOPLEVEL_LANG = verilog
VERILOG_SOURCES += $(shell pwd)/rtl/axi_udp_pkg.sv
VERILOG_SOURCES += $(shell pwd)/rtl/axi_eth_rx.sv
VERILOG_SOURCES += $(shell pwd)/rtl/axi_arp_rx.sv
VERILOG_SOURCES += $(shell pwd)/rtl/axi_arp_fsm.sv
VERILOG_SOURCES += $(shell pwd)/rtl/axi_arp_tx.sv
VERILOG_SOURCES += $(shell pwd)/rtl/axi_eth_tx.sv
VERILOG_SOURCES += $(shell pwd)/rtl/axi_udp_xcvr.sv

TOPLEVEL = axi_udp_xcvr
MODULE = tb_axi_udp_rx

include $(shell cocotb-config --makefiles)/Makefile.sim
