`timescale 1ns/1ns
`default_nettype none

module watchdog_core (
    input  wire        clk,        // watchdog clock
    input  wire        rst_n,      // active-low reset

    input  wire        en,         // prescaler enable
    input  wire        tmr_en,     // watchdog enable
    input  wire        one_shot,   // one-shot mode
    input  wire        kick,       // reload pulse from CPU
    input  wire [3:0]  clk_src,    // clock divider select
    input  wire [31:0] period,     // reload value

    output reg  [31:0] tmr,        // down counter
    output wire        to_flag     // timeout flag
);

    // timeout when counter reaches 0
    assign to_flag = (tmr == 32'b0);

    // --------------------------------------------------
    // Prescaler (free running counter)
    // pre[0] = clk/2, pre[1] = clk/4, ...
    // --------------------------------------------------
    reg [7:0] pre;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            pre <= 8'd0;
        else if (en)
            pre <= pre + 1'b1;

    // --------------------------------------------------
    // Clock source select
    // --------------------------------------------------
    wire tmr_clk_src;
    assign tmr_clk_src =
        (clk_src[3] == 1'b0) ? pre[clk_src[2:0]] :
        (clk_src == 4'd8)    ? 1'b1 :
                               1'b0;

    // --------------------------------------------------
    // Edge detect (1-cycle tick)
    // --------------------------------------------------
    reg tmr_clk_src_d;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            tmr_clk_src_d <= 1'b0;
        else
            tmr_clk_src_d <= tmr_clk_src;

    wire tmr_clk = ~tmr_clk_src_d & tmr_clk_src;

    // --------------------------------------------------
    // One-shot stop logic
    // --------------------------------------------------
    reg stop;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            stop <= 1'b0;
        else if (!tmr_en)
            stop <= 1'b0;
        else if (to_flag && one_shot)
            stop <= 1'b1;

    // --------------------------------------------------
    // Down counter
    // --------------------------------------------------
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            tmr <= 32'b0;
        else if (!tmr_en)
            tmr <= period;        // load when enabled
        else if (kick)
            tmr <= period;        // CPU kick reload
        else if (to_flag)
            tmr <= period;        // periodic reload
        else if (!stop && tmr_clk)
            tmr <= tmr - 1'b1;

endmodule

`default_nettype wire