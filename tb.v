`timescale 1ns / 1ps

module skid_buffer_tb;

    reg        clk;
    reg        rst;

    // Master Signals
    reg  [7:0] in_data;
    reg        in_valid;
    wire       in_ready;

    // Slave Signals
    wire [7:0] out_data;
    wire       out_valid;
    reg        out_ready;

    // Unit Under Test (UUT)
    skid_buffer uut (
        .clk(clk),
        .rst(rst),
        .in_data(in_data),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .out_data(out_data),
        .out_valid(out_valid),
        .out_ready(out_ready)
    );

    // Clock Generation (100 MHz)
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        in_valid = 0;
        in_data = 8'h00;
        out_ready = 1;

        // Reset Sequence
        #15 rst = 0;

        // --- Cycle 1: Normal Pass-Through ---
        @(posedge clk);
        in_valid <= 1;
        in_data  <= 8'hA1;

        // --- Cycle 2: Stream Second Item ---
        @(posedge clk);
        in_data  <= 8'hB2;

        // --- Cycle 3: Downstream Stalls (out_ready = 0) ---
        @(posedge clk);
        out_ready <= 0;        // Slave drops ready
        in_data   <= 8'hC3;    // Master sends 0xC3 (Skids into skid_reg)

        // --- Cycle 4: Verify Backpressure Asserted ---
        @(posedge clk);
        in_data   <= 8'hD4;    // Master attempts 0xD4 (Must be blocked)
        
        #1;
        $display("[%0tn] STALL CHECK: in_ready = %b (Expected: 0)", $time, in_ready);
        $display("[%0tn] STALL CHECK: out_data = 0x%h (Expected: B2)", $time, out_data);

        // --- Cycle 5: Slave Recovers (out_ready = 1) ---
        @(posedge clk);
        out_ready <= 1;
        in_valid  <= 0;

        #1;
        $display("[%0tn] DRAIN CHECK: out_data = 0x%h (Expected: C3)", $time, out_data);
        
        @(posedge clk);
        #1;
        $display("[%0tn] RESTORED: in_ready = %b (Expected: 1)", $time, in_ready);

        $finish;
    end

endmodule
