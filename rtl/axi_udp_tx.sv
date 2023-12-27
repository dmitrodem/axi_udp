`default_nettype none
import axi_udp_pkg::*;
module axi_udp_tx #(
   parameter MAC_MSB = 24'h010203,
   parameter MAC_LSB = 24'h040506,
   parameter IP_MSB = 16'hc0a8,
   parameter IP_LSB = 16'h0602)
(
  input wire        clk,
  input wire        aresetn,
  output wire [7:0] m_axis_tdata,
  output wire       m_axis_tlast,
  output wire       m_axis_tvalid,
  input wire        m_axis_tready,

  input wire        arp_start,
  input wire [15:0] arp_opcode,
  input wire [47:0] arp_dst_mac,
  input wire [31:0] arp_dst_ip
);

  localparam bit [47:0] MY_MAC        = {MAC_MSB[23:0], MAC_LSB[23:0]};
  localparam bit [31:0] MY_IP         = {IP_MSB[15:0], IP_LSB[15:0]};

  typedef struct packed {
    bit [10:0] index;
    bit arp_running;
    bit arp_gratuitous;
    bit arp_firstrun;
    bit [7:0] m_axis_tdata;
    bit       m_axis_tlast;
    bit       m_axis_tvalid;
  } reg_t;

  localparam     reg_t RES_reg = '{
    index : 'h0,
    arp_running : 'h0,
    arp_gratuitous : 'h1,
    arp_firstrun : 'h1,
    m_axis_tdata : 'h0,
    m_axis_tlast : 'h0,
    m_axis_tvalid : 'h0
  };

  reg_t r;
  reg_t rin;

  always_comb begin
    reg_t v;
    v = r;

    v.m_axis_tvalid = 0;
    if (~r.arp_running && (arp_start || r.arp_firstrun)) begin
      v.arp_running = 1;
      v.index       = 0;
      if (r.arp_firstrun) begin
        v.arp_gratuitous = 1;
        v.arp_firstrun   = 0;
      end
    end

    if (r.arp_running) begin
      case (r.index)
        'h000: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[47-:8];
        'h001: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[39-:8];
        'h002: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[31-:8];
        'h003: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[23-:8];
        'h004: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[15-:8];
        'h005: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[ 7-:8];
        'h006: v.m_axis_tdata = MY_MAC[47-:8];
        'h007: v.m_axis_tdata = MY_MAC[39-:8];
        'h008: v.m_axis_tdata = MY_MAC[31-:8];
        'h009: v.m_axis_tdata = MY_MAC[23-:8];
        'h00a: v.m_axis_tdata = MY_MAC[15-:8];
        'h00b: v.m_axis_tdata = MY_MAC[ 7-:8];
        'h00c: v.m_axis_tdata = ETHERTYPE_ARP[15-:8];
        'h00d: v.m_axis_tdata = ETHERTYPE_ARP[ 7-:8];
        'h00e: v.m_axis_tdata = 8'h00; // hw type = ethernet
        'h00f: v.m_axis_tdata = 8'h01;
        'h010: v.m_axis_tdata = 8'h08; // protocol type = ipv4
        'h011: v.m_axis_tdata = 8'h00;
        'h012: v.m_axis_tdata = 8'h06; // hw size = 6
        'h013: v.m_axis_tdata = 8'h04; // protocol size = 4
        'h014: v.m_axis_tdata = arp_opcode[15-:8];
        'h015: v.m_axis_tdata = arp_opcode[ 7-:8];
        'h016: v.m_axis_tdata = MY_MAC[47-:8];
        'h017: v.m_axis_tdata = MY_MAC[39-:8];
        'h018: v.m_axis_tdata = MY_MAC[31-:8];
        'h019: v.m_axis_tdata = MY_MAC[23-:8];
        'h01a: v.m_axis_tdata = MY_MAC[15-:8];
        'h01b: v.m_axis_tdata = MY_MAC[ 7-:8];
        'h01c: v.m_axis_tdata = MY_IP[31-:8];
        'h01d: v.m_axis_tdata = MY_IP[23-:8];
        'h01e: v.m_axis_tdata = MY_IP[15-:8];
        'h01f: v.m_axis_tdata = MY_IP[ 7-:8];
        'h020: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[47-:8];
        'h021: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[39-:8];
        'h022: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[31-:8];
        'h023: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[23-:8];
        'h024: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[15-:8];
        'h025: v.m_axis_tdata = r.arp_gratuitous ? 8'hff : arp_dst_mac[ 7-:8];
        'h026: v.m_axis_tdata = r.arp_gratuitous ? MY_IP[31-:8] : arp_dst_ip[31-:8];
        'h027: v.m_axis_tdata = r.arp_gratuitous ? MY_IP[23-:8] : arp_dst_ip[23-:8];
        'h028: v.m_axis_tdata = r.arp_gratuitous ? MY_IP[15-:8] : arp_dst_ip[15-:8];
        'h029: v.m_axis_tdata = r.arp_gratuitous ? MY_IP[ 7-:8] : arp_dst_ip[ 7-:8];
      endcase // case (r.index)

      v.index = r.index + 1;
      if (r.index <= 'h029) begin
        v.m_axis_tvalid = 1;
      end
      if (r.index == 'h029) begin
        v.m_axis_tlast = 1;
        v.arp_running  = 0;
        v.arp_gratuitous = 0;
      end else begin
        v.m_axis_tlast = 0;
      end
    end

    if (~aresetn) begin
      v = RES_reg;
    end
    rin <= v;
  end

  always_ff @(posedge clk) begin
    r <= rin;
  end

  assign m_axis_tvalid = r.m_axis_tvalid;
  assign m_axis_tdata = r.m_axis_tdata;
  assign m_axis_tlast = r.m_axis_tlast;

endmodule : axi_udp_tx
`default_nettype wire
