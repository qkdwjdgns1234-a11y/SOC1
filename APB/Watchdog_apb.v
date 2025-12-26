`timescale 1ns/1ns
`default_nettype none

module watchdog_apb (
    // APB interface
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [7:0]  PADDR,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output wire        PREADY,
    output wire        PSLVERR,

    // Watchdog clock domain
    input  wire        WDOGCLK,

    // outputs
    output wire        WDOGINT
);

    // APB always ready, no error
    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

    // --------------------------------------------------
    // Registers
    // --------------------------------------------------
    reg        en;
    reg        tmr_en;
    reg        one_shot;
    reg [3:0]  clk_src;
    reg [31:0] period;
    reg        kick_pulse;

    // --------------------------------------------------
    // APB write
    // --------------------------------------------------
    always @(posedge PCLK or negedge PRESETn)
        if (!PRESETn) begin
            en         <= 1'b0;
            tmr_en     <= 1'b0;
            one_shot   <= 1'b0;
            clk_src    <= 4'd0;
            period     <= 32'd100;
            kick_pulse <= 1'b0;
        end else begin
            kick_pulse <= 1'b0; // default

            if (PSEL && PENABLE && PWRITE) begin
                case (PADDR)
                    8'h00: begin
                        en       <= PWDATA[0];
                        tmr_en   <= PWDATA[1];
                        one_shot <= PWDATA[2];
                    end
                    8'h04: clk_src <= PWDATA[3:0];
                    8'h08: period  <= PWDATA;
                    8'h14: kick_pulse <= 1'b1; // write = kick
                    default: ;
                endcase
            end
        end

    // --------------------------------------------------
    // Watchdog core instance
    // --------------------------------------------------
    wire [31:0] tmr;
    wire        to_flag;

    watchdog_core u_wdog (
        .clk      (WDOGCLK),
        .rst_n    (PRESETn),
        .en       (en),
        .tmr_en   (tmr_en),
        .one_shot (one_shot),
        .kick     (kick_pulse),
        .clk_src  (clk_src),
        .period   (period),
        .tmr      (tmr),
        .to_flag  (to_flag)
    );

    assign WDOGINT = to_flag;

    // --------------------------------------------------
    // APB read (combinational MUX)
    // --------------------------------------------------
    always @(*) begin
        PRDATA = 32'b0;
        if (PSEL && !PWRITE) begin
            case (PADDR)
                8'h00: PRDATA = {29'b0, one_shot, tmr_en, en};
                8'h04: PRDATA = {28'b0, clk_src};
                8'h08: PRDATA = period;
                8'h0C: PRDATA = tmr;
                8'h10: PRDATA = {31'b0, to_flag};
                default: PRDATA = 32'b0;
            endcase
        end
    end

endmodule

`default_nettype wire