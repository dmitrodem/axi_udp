`default_nettype none
module axi_arp_rx #(
  parameter MAC_MSB = 24'h010203,
  parameter MAC_LSB = 24'h040506,
  parameter IP_MSB = 16'hc0a8,
  parameter IP_LSB = 16'h0602)
(
  input wire       clk,
  input wire       aresetn,
  input wire       s_axis_tvalid,
  input wire [7:0] s_axis_tdata,
  input wire       s_axis_tlast,
  output wire      s_axis_tready
);

  typedef struct packed {
    bit [10:0] index;
    bit malformed;
    bit [15:0] opcode;
    bit [47:0] src_mac;
    bit [31:0] src_ip;
    bit [47:0] dst_mac;
    bit [31:0] dst_ip;
  } reg_t;

  localparam reg_t RES_reg = '{
    index : 'h0,
    malformed : 'h0,
    opcode : 'h0,
    src_mac : 'h0,
    src_ip : 'h0,
    dst_mac : 'h0,
    dst_ip : 'h0
  };

  reg_t r;
  reg_t rin;

  always_comb begin
    reg_t v;
    v = r;

    if (s_axis_tvalid) begin
      case (r.index)
        'h000: if (s_axis_tdata != 8'h00) v.malformed = 1; // hw type = ethernet
        'h001: if (s_axis_tdata != 8'h01) v.malformed = 1;
        'h002: if (s_axis_tdata != 8'h08) v.malformed = 1; // protocol type = ipv4
        'h003: if (s_axis_tdata != 8'h00) v.malformed = 1;
        'h004: if (s_axis_tdata != 8'h06) v.malformed = 1; // hw size = 6
        'h005: if (s_axis_tdata != 8'h04) v.malformed = 1; // protocol size = 4
        'h006: v.opcode[15-:8]  = s_axis_tdata;
        'h007: v.opcode[ 7-:8]  = s_axis_tdata;
        'h008: v.src_mac[47-:8] = s_axis_tdata;
        'h009: v.src_mac[39-:8] = s_axis_tdata;
        'h00a: v.src_mac[31-:8] = s_axis_tdata;
        'h00b: v.src_mac[23-:8] = s_axis_tdata;
        'h00c: v.src_mac[15-:8] = s_axis_tdata;
        'h00d: v.src_mac[ 7-:8] = s_axis_tdata;
        'h00e: v.src_ip[31-:8]  = s_axis_tdata;
        'h00f: v.src_ip[23-:8]  = s_axis_tdata;
        'h010: v.src_ip[15-:8]  = s_axis_tdata;
        'h011: v.src_ip[ 7-:8]  = s_axis_tdata;
        'h012: v.dst_mac[47-:8] = s_axis_tdata;
        'h013: v.dst_mac[39-:8] = s_axis_tdata;
        'h014: v.dst_mac[31-:8] = s_axis_tdata;
        'h015: v.dst_mac[23-:8] = s_axis_tdata;
        'h016: v.dst_mac[15-:8] = s_axis_tdata;
        'h017: v.dst_mac[ 7-:8] = s_axis_tdata;
        'h018: v.dst_ip[31-:8]  = s_axis_tdata;
        'h019: v.dst_ip[23-:8]  = s_axis_tdata;
        'h01a: v.dst_ip[15-:8]  = s_axis_tdata;
        'h01b: v.dst_ip[ 7-:8]  = s_axis_tdata;
      endcase // case (r.index)
      v.index = r.index + 1;
    end

    if (~aresetn) begin
      v = RES_reg;
    end
    rin <= v;
  end

  always_ff @(posedge clk) begin
    r <= rin;
  end

  assign s_axis_tready = 1'b1;
endmodule : axi_arp_rx
`default_nettype wire
