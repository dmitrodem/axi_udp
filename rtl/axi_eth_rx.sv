`default_nettype none
import axi_udp_pkg::*;
module axi_eth_rx #(
  parameter DEBUG   = 1,
  parameter MAC_MSB = 24'h010203,
  parameter MAC_LSB = 24'h040506,
  parameter IP_MSB = 16'hc0a8,
  parameter IP_LSB = 16'h0602)
(
  input wire         clk,
  input wire         aresetn,


  input wire [7:0]   mac_axis_tdata,
  input wire         mac_axis_tlast,
  input wire         mac_axis_tvalid,
  output wire        mac_axis_tready,

  output wire        arp_axis_tvalid,
  output wire [7:0]  arp_axis_tdata,
  output wire        arp_axis_tlast,
  input  wire        arp_axis_tready,

  output wire        ip_axis_tvalid,
  output wire [7:0]  ip_axis_tdata,
  output wire        ip_axis_tlast,
  input wire         ip_axis_tready,

  output wire        eth_hdr_valid,
  output wire [47:0] eth_hdr_dst_mac,
  output wire [47:0] eth_hdr_src_mac,
  output wire [15:0] eth_hdr_ethertype
);

  localparam string TAG          = "axi_eth_rx";

  localparam bit [47:0] THIS_MAC = {MAC_MSB[23:0], MAC_LSB[23:0]};
  localparam bit [31:0] THIS_IP  = { IP_MSB[15:0],  IP_LSB[15:0]};

  typedef enum bit [1:0] {
    S_HEADER,
    S_PROTOCOL
  } state_t;

  typedef struct packed {
    state_t    state;
    bit [3:0]  index;
    bit [47:0] destination_mac;
    bit [47:0] source_mac;
    bit [15:0] ethertype;
    bit        valid;
    bit        pvalid;
  } reg_t;

  localparam reg_t RES_reg = '{
    state           : S_HEADER,
    index           : 'h0,
    destination_mac : 'h0,
    source_mac      : 'h0,
    ethertype       : 'h0,
    valid           : 'h0,
    pvalid          : 'h0
  };

  reg_t r;
  reg_t rin;

  bit tready;
  
  always_comb begin
    reg_t v;
    v = r;

    v.pvalid = r.valid;

    case (r.state)
      S_HEADER: begin
        if (mac_axis_tvalid) begin
          case (r.index)
            'h00: v.destination_mac[47-:8] = mac_axis_tdata;
            'h01: v.destination_mac[39-:8] = mac_axis_tdata;
            'h02: v.destination_mac[31-:8] = mac_axis_tdata;
            'h03: v.destination_mac[23-:8] = mac_axis_tdata;
            'h04: v.destination_mac[15-:8] = mac_axis_tdata;
            'h05: v.destination_mac[ 7-:8] = mac_axis_tdata;
            'h06: v.source_mac[47-:8]      = mac_axis_tdata;
            'h07: v.source_mac[39-:8]      = mac_axis_tdata;
            'h08: v.source_mac[31-:8]      = mac_axis_tdata;
            'h09: v.source_mac[23-:8]      = mac_axis_tdata;
            'h0a: v.source_mac[15-:8]      = mac_axis_tdata;
            'h0b: v.source_mac[ 7-:8]      = mac_axis_tdata;
            'h0c: v.ethertype[15-:8]       = mac_axis_tdata;
            'h0d: begin
              v.ethertype[7-:8] = mac_axis_tdata;
              v.valid = ((r.destination_mac == BROADCAST_MAC) ||
                         (r.destination_mac == THIS_MAC));
              if (mac_axis_tlast) begin
                v.state = S_HEADER;
                v.index = 'h0;
                v.valid = 0;
              end else begin
                v.state = S_PROTOCOL;
              end
            end
          endcase
          v.index = r.index + 1;
        end
      end // case: S_HEADER
      S_PROTOCOL: begin
        if (mac_axis_tlast) begin
          v.state = S_HEADER;
          v.index = 'h0;
          v.valid = 0;
        end
      end
      default:;
    endcase // case (r.state)

    if (~aresetn) begin
      v = RES_reg;
    end

    rin = v;

    tready = 1'b0;
    case (r.state)
      S_HEADER   : tready = 1'b1;
      S_PROTOCOL : begin
        case (r.ethertype)
          ETHERTYPE_ARP  : tready = arp_axis_tready;
          ETHERTYPE_IPV4 : tready = ip_axis_tready;
          default        : tready = 1'b1;
        endcase // case (r.ethertype)
      end      
      default:;
    endcase // case (r.state)   
  end

  always_ff @(posedge clk) begin
    r <= rin;
    if (DEBUG) begin
      if (r.valid && ~r.pvalid) begin
        $display("%t : %-12s : DST %012h, SRC %012h, TYPE %04h",
                 $time, TAG,
                 r.destination_mac,
                 r.source_mac,
                 r.ethertype);
      end
    end
  end

  assign arp_axis_tdata  = mac_axis_tdata;
  assign arp_axis_tlast  = mac_axis_tlast;
  assign arp_axis_tvalid = mac_axis_tvalid && r.valid && (r.ethertype == ETHERTYPE_ARP);

  assign ip_axis_tdata  = mac_axis_tdata;
  assign ip_axis_tlast  = mac_axis_tlast;
  assign ip_axis_tvalid = mac_axis_tvalid && r.valid && (r.ethertype == ETHERTYPE_IPV4);

  assign mac_axis_tready = tready;

  assign eth_hdr_valid     = r.valid;
  assign eth_hdr_dst_mac   = r.destination_mac;
  assign eth_hdr_src_mac   = r.source_mac;
  assign eth_hdr_ethertype = r.ethertype;

endmodule : axi_eth_rx
`default_nettype wire
