`default_nettype none
package axi_udp_pkg;

  localparam bit [47:0] BROADCAST_MAC    = 48'hffffffffffff;
  localparam bit [31:0] BROADCAST_IP     = 32'hffffffff;

  localparam bit [15:0] ETHERTYPE_ARP    = 16'h0806;
  localparam bit [15:0] ETHERTYPE_IPV4   = 16'h0800;


  localparam bit [15:0] ARP_HW_TYPE      = 16'h0001;
  localparam bit [15:0] ARP_PROTO_TYPE   = 16'h0800;
  localparam bit [7:0]  ARP_HW_SIZE      = 8'h06;
  localparam bit [7:0]  ARP_PROTO_SIZE   = 8'h04;

  localparam bit [15:0] ARP_OPER_REQUEST = 16'h0001;
  localparam bit [15:0] ARP_OPER_REPLY   = 16'h0002;

endpackage : axi_udp_pkg
`default_nettype wire
