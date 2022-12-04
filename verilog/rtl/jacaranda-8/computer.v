// Copyright 2021 cpu-dev
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`default_nettype none

module computer(
`ifdef USE_POWER_PINS
    inout vdd,	// User area 1 1.8V supply
    inout vss,	// User area 1 digital ground
`endif
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_adr_i,
    input [31:0] wbs_dat_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    output [2:0] irq
);

    wire rx;
    wire tx;
    assign io_oeb[37:0] = 38'h00_0000_0000;

    // UART - GPIO
    assign io_out[37] = tx;
    assign rx = io_in[36];

    wire [7:0] instr;
    wire [7:0] pc;
    wire [7:0] rd_data;
    wire [7:0] rs_data;
    wire mem_w_en;
    wire [7:0] mem_r_data;
    wire [7:0] _mem_r_data;
    wire busy_flag;
    wire receive_flag;
    reg tx_en;
    reg rx_en;
    wire begin_flag;
    reg [7:0] tx_data;
    wire [7:0] rx_data;

    reg [7:0] int_vec;
    reg [7:0] int_en;

    wire int_req;

    wire reg_w_en;

    wire [7:0] instr_mem_addr;
    wire [7:0] instr_mem_data; 
    wire instr_mem_en;

    wire [7:0] wb_instr_req_addr;

    wire [31:0] uart_clk_freq;

    assign instr_mem_addr = reset ? wb_instr_req_addr: pc;

    reg [7:0] gpio_out;
    wire [7:0] gpio_in;

    assign io_out[35:28] = gpio_out;
    assign gpio_in   = io_out[27:20];

    wire reset;

    assign reset = la_data_in[0];

    wire clock;
    assign clock = wb_clk_i;

    wishbone wb(.wb_clk_i(wb_clk_i),
                .wb_rst_i(wb_rst_i),
                .wbs_stb_i(wbs_stb_i),
                .wbs_cyc_i(wbs_cyc_i),
                .wbs_we_i(wbs_we_i),
                .wbs_sel_i(wbs_sel_i),
                .wbs_adr_i(wbs_adr_i),
                .wbs_dat_i(wbs_dat_i),
                .wbs_ack_o(wbs_ack_o),
                .wbs_dat_o(wbs_dat_o),
                .instr_mem_addr(wb_instr_req_addr),
                .instr_mem_data(instr_mem_data),
                .instr_mem_en(instr_mem_en),
                .uart_freq(uart_clk_freq)
            );

    instr_mem instr_mem(.addr(instr_mem_addr),
                        .w_data(instr_mem_data),
                        .w_en(instr_mem_en),
                        .r_data(instr),
                        .clock(wb_clk_i),
                        .reset(reset));

    cpu cpu(.clock(clock),
            .reset(reset),
            .instr(instr),
            .pc(pc),
            .rd_data(rd_data),
            .rs_data(rs_data),
            .mem_w_en(mem_w_en),
            .mem_r_data(mem_r_data),
            .int_req(int_req),
            .int_en(int_en),
            .int_vec(int_vec),
            .reg_w_en(reg_w_en));

    always @(posedge clock) begin
        if(reset) begin
            tx_en <= 1'b0;
            rx_en <= 1'b0;
        end else if(rs_data == 8'd255 && mem_w_en == 1) begin
            tx_en <= rd_data[0];
            rx_en <= rd_data[1];
        end
    end

    always @(posedge clock) begin
        if(reset) begin
            tx_data <= 8'b0;
        end else if(rs_data == 8'd253 && mem_w_en == 1) begin
            tx_data <= rd_data;
        end else begin
            tx_data <= tx_data;
        end
    end

    always @(posedge clock) begin
        if(reset) begin
            gpio_out <= 8'b0;
        end else if(rs_data == 8'd251 && mem_w_en == 1) begin
            gpio_out <= rd_data;
        end else begin
            gpio_out <= gpio_out;
        end
    end

    assign begin_flag = (rs_data == 8'd253) & (mem_w_en == 1);

    data_mem data_mem(.addr(rs_data),
                      .w_data(rd_data),
                      .w_en(mem_w_en),
                      .r_data(_mem_r_data),
                      .clock(clock));

    assign mem_r_data = (rs_data == 8'd254) ? {6'b0, receive_flag, busy_flag}
                      : (rs_data == 8'd252) ? rx_data
                      : (rs_data == 8'd251) ? gpio_out
                      : (rs_data == 8'd250) ? int_vec
                      : (rs_data == 8'd249) ? gpio_in
                      : _mem_r_data;   

    always @(posedge clock) begin
        if(reset) begin
            int_en <= 8'b0;
        end else if(int_req == 1'b1) begin
            int_en <= 8'h00;
        end else if(int_req == 1'b0) begin
            int_en <= 8'h01;
        end
    end

    always @(posedge clock) begin
        if(reset) begin
            int_vec <= 8'b0;
        end else if(rs_data == 8'd250 && mem_w_en == 1'b1) begin
            int_vec <= rd_data;
        end else begin
            int_vec <= int_vec;
        end
    end

    UART UART(.clk(clock),
              .reset(reset),
              .tx_en(tx_en),
              .rx_en(rx_en),
              .begin_flag(begin_flag),
              .rx(rx),
              .tx_data(tx_data),
              .tx(tx),
              .rx_data(rx_data),
              .busy_flag(busy_flag),
              .receive_flag(receive_flag),
              .int_req(int_req),
              .access_addr(rs_data),
              .reg_w_en(reg_w_en),
              .clk_freq(uart_clk_freq)
        );

endmodule
