`timescale 1ns/1ns

module tb_watchdog_apb;

    reg         PCLK;
    reg         PRESETn;
    reg         WDOGCLK;

    reg         PSEL;
    reg         PENABLE;
    reg         PWRITE;
    reg [7:0]   PADDR;
    reg [31:0]  PWDATA;
    wire [31:0] PRDATA;
    wire        WDOGINT;

    // clock generation
    always #5  PCLK    = ~PCLK;     // 100MHz
    always #20 WDOGCLK = ~WDOGCLK;  // slower watchdog clock

    // DUT
    watchdog_apb dut (
        .PCLK     (PCLK),
        .PRESETn  (PRESETn),
        .PSEL     (PSEL),
        .PENABLE  (PENABLE),
        .PWRITE   (PWRITE),
        .PADDR    (PADDR),
        .PWDATA   (PWDATA),
        .PRDATA   (PRDATA),
        .PREADY   (),
        .PSLVERR  (),
        .WDOGCLK  (WDOGCLK),
        .WDOGINT  (WDOGINT)
    );

    // --------------------------------------------------
    // APB write task
    // --------------------------------------------------
    task apb_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge PCLK);
            PSEL   <= 1'b1;
            PWRITE <= 1'b1;
            PENABLE<= 1'b0;
            PADDR  <= addr;
            PWDATA <= data;

            @(posedge PCLK);
            PENABLE <= 1'b1;

            @(posedge PCLK);
            PSEL   <= 1'b0;
            PENABLE<= 1'b0;
            PWRITE <= 1'b0;
        end
    endtask

    // --------------------------------------------------
    // APB read task
    // --------------------------------------------------
    task apb_read(input [7:0] addr);
        begin
            @(posedge PCLK);
            PSEL   <= 1'b1;
            PWRITE <= 1'b0;
            PENABLE<= 1'b0;
            PADDR  <= addr;

            @(posedge PCLK);
            PENABLE <= 1'b1;

            @(posedge PCLK);
            $display("[READ] addr=0x%02h data=0x%08h", addr, PRDATA);

            PSEL   <= 1'b0;
            PENABLE<= 1'b0;
        end
    endtask

    // --------------------------------------------------
    // Test sequence
    // --------------------------------------------------
    initial begin
        // init
        PCLK = 0; WDOGCLK = 0;
        PSEL = 0; PENABLE = 0; PWRITE = 0;
        PADDR = 0; PWDATA = 0;
        PRESETn = 0;

        #50 PRESETn = 1;

        // configure watchdog
        apb_write(8'h08, 32'd10);   // period
        apb_write(8'h00, 32'b11);   // en=1, tmr_en=1

        // kick a few times
        repeat (3) begin
            #100 apb_write(8'h14, 32'h1);
        end

        $display("=== stop kicking, wait for timeout ===");
        wait (WDOGINT == 1'b1);
        $display(">>> WATCHDOG TIMEOUT <<<");

        apb_read(8'h10); // status
        apb_read(8'h0C); // counter

        #100 $finish;
    end

endmodule