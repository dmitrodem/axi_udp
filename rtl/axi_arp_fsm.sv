`default_nettype none
import axi_udp_pkg::*;
module axi_arp_fsm #(
  parameter DEBUG   = 1,
  parameter MAC_MSB = 24'h010203,
  parameter MAC_LSB = 24'h040506,
  parameter IP_MSB = 16'hc0a8,
  parameter IP_LSB = 16'h0602)
(
  input wire         clk,
  input wire         aresetn,

  input wire         arp_rx_valid,
  output wire        arp_rx_ready,
  input wire [15:0]  arp_rx_opcode,
  input wire [47:0]  arp_rx_src_mac,
  input wire [31:0]  arp_rx_src_ip,
  input wire [47:0]  arp_rx_dst_mac,
  input wire [31:0]  arp_rx_dst_ip,

  output wire        arp_tx_req,
  input wire         arp_tx_ack,
  output wire [15:0] arp_tx_opcode,
  output wire [47:0] arp_tx_src_mac,
  output wire [31:0] arp_tx_src_ip,
  output wire [47:0] arp_tx_dst_mac,
  output wire [31:0] arp_tx_dst_ip
);

  localparam string TAG = "axi_arp_fsm";

  typedef enum bit [7:0] {
    S_LISTEN,
    S_REQ_REPLY,
    S_SEND_REPLY
  } state_t;

  typedef struct packed {
    state_t state;
    bit [47:0] target_mac;
    bit [31:0] target_ip;
    bit        req;
    bit        req1;
  } reg_t;

  localparam reg_t RES_reg = '{
    state : S_LISTEN,
    target_mac : 'h0,
    target_ip : 'h0,
    req : 1'b0,
    req1 : 1'b0
  };

  reg_t r;
  reg_t rin;

  always_comb begin
    reg_t v;
    v = r;

    v.req1 = 1'b0;
    case (r.state)
      S_LISTEN: begin
        if (arp_rx_valid) begin
          v.state      = S_REQ_REPLY;
          v.target_mac = arp_rx_src_mac;
          v.target_ip  = arp_rx_src_ip;
          v.req        = 1'b1;
          v.req1       = 1'b1;
        end
      end
      S_REQ_REPLY: begin
        if (arp_tx_ack) begin
          v.req    = 1'b0;
          v.state  = S_LISTEN;
        end
      end
      default:;
    endcase // case (r.state)

    if (~aresetn) begin
      v = RES_reg;
    end
    rin = v;
  end

  always_ff @(posedge clk) begin
    r <= rin;
    if (DEBUG) begin
      if (r.req1) begin
        $display("%t : %-12s : MAC %012h, IP %08h",
                 $time, TAG,
                 r.target_mac, r.target_ip);
      end
    end
  end

  assign arp_rx_ready = (r.state == S_LISTEN);

  assign arp_tx_req     = r.req;
  assign arp_tx_opcode  = (arp_rx_opcode == ARP_OPER_REQUEST) ? ARP_OPER_REPLY : 16'h0000;
  assign arp_tx_src_mac = {MAC_MSB[23:0], MAC_LSB[23:0]};
  assign arp_tx_src_ip  = {IP_MSB[15:0],  IP_LSB[15:0]};
  assign arp_tx_dst_mac = arp_rx_src_mac;
  assign arp_tx_dst_ip  = arp_rx_src_ip;
endmodule : axi_arp_fsm
`default_nettype wire
