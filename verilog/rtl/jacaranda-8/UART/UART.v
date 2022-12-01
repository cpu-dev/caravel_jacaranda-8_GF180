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

// baud rate 115200bps, stop bit 1bit, data 8bit, no parity, no flow control

module UART(
    input wire clk,
    input wire reset,
    input wire tx_en,
    input wire rx_en,
    input wire begin_flag,
    input wire rx,
    input wire [7:0] tx_data,
    input wire [7:0] access_addr,
    input wire reg_w_en,
    output wire tx,
    output wire[7:0] rx_data,
    output wire busy_flag,
    output wire receive_flag,
    output reg int_req,
    input wire [31:0] clk_freq
);

    parameter BAUD_RATE = 9600;
    parameter CLK_FREQ  = 250000;

    //wire [31:0] clk_count_bit;
    reg state;

    //assign clk_count_bit = clk_freq / BAUD_RATE;
    parameter CLK_COUNT = CLK_FREQ / BAUD_RATE;

    always @(negedge clk) begin
        if(reset) begin
            state <= 1'b0;
            int_req <= 1'b0;
        end else if(state == 1'b0) begin
            int_req <= 1'b0;
            if(receive_flag == 1'b1) begin
                state <= 1'b1;
            end else begin
                state <= state;
            end
        end else if(state == 1'b1) begin
            int_req <= 1'b1;
            if(access_addr == 8'd252 && reg_w_en == 1'b1) begin
                state <= 1'b0;
            end else begin
                state <= state;
            end
        end
    end

    tx tx1(clk, reset, tx_en, begin_flag, tx_data, tx, busy_flag, CLK_COUNT);
    rx rx1(clk, reset, rx_en, rx, rx_data, receive_flag, CLK_COUNT);
    
endmodule
