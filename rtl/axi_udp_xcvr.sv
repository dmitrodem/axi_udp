//                              -*- Mode: Verilog -*-
// Filename        : axi_udp_xcvr.sv
// Description     : xxx
// Author          : Dmitriy Dyomin
// Created On      : Tue Dec 19 23:59:51 2023
// Last Modified By: Dmitriy Dyomin
// Last Modified On: Tue Dec 19 23:59:51 2023
// Update Count    : 0
// Status          : Unknown, Use with caution!

`default_nettype none
module axi_udp_xcvr #(
   parameter MAC_MSB = 24'h010203,
   parameter MAC_LSB = 24'h040506,
   parameter IP_MSB = 16'hc0a8,
   parameter IP_LSB = 16'h0602
) (
  input wire        clk,
  input wire        aresetn,

  output wire [7:0] m_axis_tdata,
  output wire       m_axis_tlast,
  output wire       m_axis_tvalid,
  input wire        m_axis_tready,

  input wire [7:0]  s_axis_tdata,
  input wire        s_axis_tlast,
  input wire        s_axis_tvalid,
  output wire       s_axis_tready
);

  wire [7:0]   eth2arp_axis_tdata;
  wire         eth2arp_axis_tlast;
  wire         eth2arp_axis_tvalid;
  wire         eth2arp_axis_tready;

  wire [7:0]   eth2ip_axis_tdata;
  wire         eth2ip_axis_tlast;
  wire         eth2ip_axis_tvalid;
  wire         eth2ip_axis_tready;

  wire         eth_rx_hdr_valid;
  wire [47:0]  eth_rx_hdr_dst_mac;
  wire [47:0]  eth_rx_hdr_src_mac;
  wire [15:0]  eth_rx_hdr_ethertype;

  wire         arp2fsm_valid;
  wire         arp2fsm_ready;
  wire [15:0]  arp2fsm_opcode;
  wire [47:0]  arp2fsm_src_mac;
  wire [31:0]  arp2fsm_src_ip;
  wire [47:0]  arp2fsm_dst_mac;
  wire [31:0]  arp2fsm_dst_ip;

  wire         fsm2arp_req;
  wire         fsm2arp_ack;
  wire [15:0]  fsm2arp_opcode;
  wire [47:0]  fsm2arp_src_mac;
  wire [31:0]  fsm2arp_src_ip;
  wire [47:0]  fsm2arp_dst_mac;
  wire [31:0]  fsm2arp_dst_ip;

  wire         arp_lookup_req;
  wire         arp_lookup_valid;
  wire [31:0]  arp_lookup_ip;
  wire [47:0]  arp_lookup_mac;

  wire         arp2eth_req;
  wire         arp2eth_ack;
  wire [47:0]  arp2eth_dst_mac;
  wire [47:0]  arp2eth_src_mac;
  wire [15:0]  arp2eth_ethertype;
  wire [7:0]   arp2eth_axis_tdata;
  wire         arp2eth_axis_tlast;
  wire         arp2eth_axis_tvalid;
  wire         arp2eth_axis_tready;

  wire         port1_req;
  wire         port1_ack;
  wire [47:0]  port1_dst_mac;
  wire [47:0]  port1_src_mac;
  wire [15:0]  port1_ethertype;
  wire [7:0]   port1_axis_tdata;
  wire         port1_axis_tlast;
  wire         port1_axis_tvalid;
  wire         port1_axis_tready;

  wire         port2_req;
  wire         port2_ack;
  wire [47:0]  port2_dst_mac;
  wire [47:0]  port2_src_mac;
  wire [15:0]  port2_ethertype;
  wire [7:0]   port2_axis_tdata;
  wire         port2_axis_tlast;
  wire         port2_axis_tvalid;
  wire         port2_axis_tready;

  wire         port3_req;
  wire         port3_ack;
  wire [47:0]  port3_dst_mac;
  wire [47:0]  port3_src_mac;
  wire [15:0]  port3_ethertype;
  wire [7:0]   port3_axis_tdata;
  wire         port3_axis_tlast;
  wire         port3_axis_tvalid;
  wire         port3_axis_tready;


  axi_eth_rx #(
    .DEBUG   (1),
    .MAC_MSB (MAC_MSB),
    .MAC_LSB (MAC_LSB),
    .IP_MSB  (IP_MSB),
    .IP_LSB  (IP_LSB))
  eth_rx0 (
    .clk               (clk),
    .aresetn           (aresetn),

    .mac_axis_tdata    (s_axis_tdata),
    .mac_axis_tlast    (s_axis_tlast),
    .mac_axis_tvalid   (s_axis_tvalid),
    .mac_axis_tready   (s_axis_tready),

    .arp_axis_tvalid   (eth2arp_axis_tvalid),
    .arp_axis_tdata    (eth2arp_axis_tdata),
    .arp_axis_tlast    (eth2arp_axis_tlast),
    .arp_axis_tready   (eth2arp_axis_tready),

    .ip_axis_tvalid    (eth2ip_axis_tvalid),
    .ip_axis_tdata     (eth2ip_axis_tdata),
    .ip_axis_tlast     (eth2ip_axis_tlast),
    .ip_axis_tready    (eth2ip_axis_tready),

    .eth_hdr_valid     (eth_rx_hdr_valid),
    .eth_hdr_dst_mac   (eth_rx_hdr_dst_mac),
    .eth_hdr_src_mac   (eth_rx_hdr_src_mac),
    .eth_hdr_ethertype (eth_rx_hdr_ethertype));

  axi_arp_rx #(
    .DEBUG   (1),
    .MAC_MSB (MAC_MSB),
    .MAC_LSB (MAC_LSB),
    .IP_MSB  (IP_MSB),
    .IP_LSB  (IP_LSB))
    arp_rx0 (
    .clk           (clk),
    .aresetn       (aresetn),

    .s_axis_tvalid (eth2arp_axis_tvalid),
    .s_axis_tdata  (eth2arp_axis_tdata),
    .s_axis_tlast  (eth2arp_axis_tlast),
    .s_axis_tready (eth2arp_axis_tready),

    .arp_valid     (arp2fsm_valid),
    .arp_ready     (arp2fsm_ready),
    .arp_opcode    (arp2fsm_opcode),
    .arp_src_mac   (arp2fsm_src_mac),
    .arp_src_ip    (arp2fsm_src_ip),
    .arp_dst_mac   (arp2fsm_dst_mac),
    .arp_dst_ip    (arp2fsm_dst_ip));

  axi_arp_fsm #(
    .DEBUG   (1),
    .MAC_MSB (MAC_MSB),
    .MAC_LSB (MAC_LSB),
    .IP_MSB  (IP_MSB),
    .IP_LSB  (IP_LSB))
  arp_fsm0 (
    .clk            (clk),
    .aresetn        (aresetn),

    .arp_rx_valid   (arp2fsm_valid),
    .arp_rx_ready   (arp2fsm_ready),
    .arp_rx_opcode  (arp2fsm_opcode),
    .arp_rx_src_mac (arp2fsm_src_mac),
    .arp_rx_src_ip  (arp2fsm_src_ip),
    .arp_rx_dst_mac (arp2fsm_dst_mac),
    .arp_rx_dst_ip  (arp2fsm_dst_ip),

    .arp_tx_req     (fsm2arp_req),
    .arp_tx_ack     (fsm2arp_ack),
    .arp_tx_opcode  (fsm2arp_opcode),
    .arp_tx_src_mac (fsm2arp_src_mac),
    .arp_tx_src_ip  (fsm2arp_src_ip),
    .arp_tx_dst_mac (fsm2arp_dst_mac),
    .arp_tx_dst_ip  (fsm2arp_dst_ip),

    .arp_lookup_req   (arp_lookup_req),
    .arp_lookup_ip    (arp_lookup_ip),
    .arp_lookup_valid (arp_lookup_valid),
    .arp_lookup_mac   (arp_lookup_mac));

 axi_arp_tx #(
    .DEBUG   (1),
    .MAC_MSB (MAC_MSB),
    .MAC_LSB (MAC_LSB),
    .IP_MSB  (IP_MSB),
    .IP_LSB  (IP_LSB))
  arp_tx0 (
   .clk             (clk),
   .aresetn         (aresetn),

   .arp_req         (fsm2arp_req),
   .arp_ack         (fsm2arp_ack),
   .arp_opcode      (fsm2arp_opcode),
   .arp_src_mac     (fsm2arp_src_mac),
   .arp_src_ip      (fsm2arp_src_ip),
   .arp_dst_mac     (fsm2arp_dst_mac),
   .arp_dst_ip      (fsm2arp_dst_ip),

   .eth_req         (arp2eth_req),
   .eth_ack         (arp2eth_ack),
   .eth_dst_mac     (arp2eth_dst_mac),
   .eth_src_mac     (arp2eth_src_mac),
   .eth_ethertype   (arp2eth_ethertype),
   .eth_axis_tdata  (arp2eth_axis_tdata),
   .eth_axis_tlast  (arp2eth_axis_tlast),
   .eth_axis_tvalid (arp2eth_axis_tvalid),
   .eth_axis_tready (arp2eth_axis_tready));

  axi_eth_tx #(
    .DEBUG   (1),
    .MAC_MSB (MAC_MSB),
    .MAC_LSB (MAC_LSB),
    .IP_MSB  (IP_MSB),
    .IP_LSB  (IP_LSB))
  eth_tx0 (
    .clk               (clk),
    .aresetn           (aresetn),

    .port0_req         (arp2eth_req),
    .port0_ack         (arp2eth_ack),
    .port0_dst_mac     (arp2eth_dst_mac),
    .port0_src_mac     (arp2eth_src_mac),
    .port0_ethertype   (arp2eth_ethertype),
    .port0_axis_tdata  (arp2eth_axis_tdata),
    .port0_axis_tlast  (arp2eth_axis_tlast),
    .port0_axis_tvalid (arp2eth_axis_tvalid),
    .port0_axis_tready (arp2eth_axis_tready),

    .port1_req         (port1_req),
    .port1_ack         (port1_ack),
    .port1_dst_mac     (port1_dst_mac),
    .port1_src_mac     (port1_src_mac),
    .port1_ethertype   (port1_ethertype),
    .port1_axis_tdata  (port1_axis_tdata),
    .port1_axis_tlast  (port1_axis_tlast),
    .port1_axis_tvalid (port1_axis_tvalid),
    .port1_axis_tready (port1_axis_tready),

    .port2_req         (port2_req),
    .port2_ack         (port2_ack),
    .port2_dst_mac     (port2_dst_mac),
    .port2_src_mac     (port2_src_mac),
    .port2_ethertype   (port2_ethertype),
    .port2_axis_tdata  (port2_axis_tdata),
    .port2_axis_tlast  (port2_axis_tlast),
    .port2_axis_tvalid (port2_axis_tvalid),
    .port2_axis_tready (port2_axis_tready),

    .port3_req         (port3_req),
    .port3_ack         (port3_ack),
    .port3_dst_mac     (port3_dst_mac),
    .port3_src_mac     (port3_src_mac),
    .port3_ethertype   (port3_ethertype),
    .port3_axis_tdata  (port3_axis_tdata),
    .port3_axis_tlast  (port3_axis_tlast),
    .port3_axis_tvalid (port3_axis_tvalid),
    .port3_axis_tready (port3_axis_tready),

    .mac_axis_tdata    (m_axis_tdata),
    .mac_axis_tlast    (m_axis_tlast),
    .mac_axis_tvalid   (m_axis_tvalid),
    .mac_axis_tready   (m_axis_tready));

  assign port1_req         = 1'b0;
  assign port1_dst_mac     = 48'h0;
  assign port1_src_mac     = 48'h0;
  assign port1_ethertype   = 16'h0;
  assign port1_axis_tdata  = 8'h0;
  assign port1_axis_tlast  = 1'b0;
  assign port1_axis_tvalid = 1'b0;

  assign port2_req         = 1'b0;
  assign port2_dst_mac     = 48'h0;
  assign port2_src_mac     = 48'h0;
  assign port2_ethertype   = 16'h0;
  assign port2_axis_tdata  = 8'h0;
  assign port2_axis_tlast  = 1'b0;
  assign port2_axis_tvalid = 1'b0;

  assign port3_req         = 1'b0;
  assign port3_dst_mac     = 48'h0;
  assign port3_src_mac     = 48'h0;
  assign port3_ethertype   = 16'h0;
  assign port3_axis_tdata  = 8'h0;
  assign port3_axis_tlast  = 1'b0;
  assign port3_axis_tvalid = 1'b0;

  initial begin
    $timeformat(-6, 0, "us", 10);
  end

endmodule : axi_udp_xcvr
`default_nettype wire
