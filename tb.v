`timescale 1ns/1ps

module tb_skid_buffer;
    reg        clk;
    reg        rst;
    // Upstream Interface (Master Side)
    reg  [7:0] in_data;
    reg        in_valid;  
    wire       in_ready;
    // Downstream Interface (Slave Side)
    wire [7:0] out_data;
    wire       out_valid;
    reg        out_ready;

    // Instantiate DUT
    skid_buffer dut (
        .clk       (clk),
        .rst       (rst),
        .in_data   (in_data),
        .in_valid  (in_valid),
        .in_ready  (in_ready),
        .out_data  (out_data),
        .out_valid (out_valid),
        .out_ready (out_ready)
    );

    // 100 MHz clock (10 ns period)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Scoreboard FIFOs to verify strict in-order delivery and exact beat count
    reg [7:0] expected_q [0:255];
    integer   wr_ptr;
    integer   rd_ptr;
    integer   err_cnt;

    // Track previous cycle's output to check valid-ready stability rule
    reg       prev_out_valid;
    reg       prev_out_ready;
    reg [7:0] prev_out_data;

    always @(posedge clk) begin
        if (rst) begin
            prev_out_valid <= 1'b0;
            prev_out_ready <= 1'b0;
            prev_out_data  <= 8'd0;
        end else begin
            // Rule check: If out_valid was 1 and out_ready was 0 on the previous cycle,
            // out_valid must stay 1 and out_data must remain unchanged.
            if (prev_out_valid && !prev_out_ready) begin
                if (!out_valid) begin
                    $display("ERROR @ %0t: out_valid dropped while stalled!", $time);
                    err_cnt = err_cnt + 1;
                end
                if (out_data !== prev_out_data) begin
                    $display("ERROR @ %0t: out_data changed (%0h -> %0h) while stalled!",
                             $time, prev_out_data, out_data);
                    err_cnt = err_cnt + 1;
                end
            end

            // Record accepted input beats
            if (in_valid && in_ready) begin
                expected_q[wr_ptr] = in_data;
                wr_ptr = wr_ptr + 1;
            end

            // Verify consumed output beats against expected order
            if (out_valid && out_ready) begin
                if (rd_ptr >= wr_ptr) begin
                    $display("ERROR @ %0t: Unexpected out_valid handshake (data=%0h) with empty scoreboard!",
                             $time, out_data);
                    err_cnt = err_cnt + 1;
                end else if (out_data !== expected_q[rd_ptr]) begin
                    $display("ERROR @ %0t: Order/data mismatch! Expected=%0h, Got=%0h",
                             $time, expected_q[rd_ptr], out_data);
                    err_cnt = err_cnt + 1;
                end
                rd_ptr = rd_ptr + 1;
            end

            prev_out_valid <= out_valid;
            prev_out_ready <= out_ready;
            prev_out_data  <= out_data;
        end
    end

    // Waveform and console logging
    initial begin
        $dumpfile("skid_buffer.vcd");
        $dumpvars(0, tb_skid_buffer);
        $monitor("t=%0t rst=%b | in_v=%b in_r=%b in_d=%0h | out_v=%b out_r=%b out_d=%0h | main_v=%b skid_v=%b skid_d=%0h",
                 $time, rst, in_valid, in_ready, in_data,
                 out_valid, out_ready, out_data,
                 dut.main_valid, dut.skid_valid, dut.skid_reg);
    end

    // Stimulus scenarios
    integer i;
    reg [7:0] beat_val;

    initial begin
        rst      = 1'b1;
        in_data  = 8'd0;
        in_valid = 1'b0;
        out_ready = 1'b0;
        wr_ptr   = 0;
        rd_ptr   = 0;
        err_cnt  = 0;
        beat_val = 8'h10;

        // 1. Reset phase
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        out_ready = 1'b1;

        // 2. Back-to-back streaming with downstream ready
        for (i = 0; i < 4; i = i + 1) begin
            @(negedge clk);
            in_valid = 1'b1;
            in_data  = beat_val;
            beat_val = beat_val + 8'h01;
            @(posedge clk);
            while (!in_ready) @(posedge clk);
        end

        // 3. Stall downstream (out_ready = 0) while sending 2 beats:
        //    First goes to main_reg, second skids into skid_reg, then in_ready de-asserts
        @(negedge clk);
        out_ready = 1'b0;
        in_valid  = 1'b1;
        in_data   = beat_val; // Beat A (should go to main_reg)
        beat_val  = beat_val + 8'h01;

        @(negedge clk);
        in_valid  = 1'b1;
        in_data   = beat_val; // Beat B (should skid into skid_reg)
        beat_val  = beat_val + 8'h01;

        // Hold stall and try driving another beat while in_ready == 0
        repeat (2) begin
            @(negedge clk);
            in_valid = 1'b1;
            in_data  = 8'hEE; // Should NOT be accepted while in_ready == 0
        end

        // Release stall: Beat A drains first, then Beat B drains from skid_reg
        @(negedge clk);
        in_valid  = 1'b0;
        out_ready = 1'b1;

        repeat (4) @(posedge clk);

        // 4. Randomized traffic & backpressure stress test
        for (i = 0; i < 40; i = i + 1) begin
            @(negedge clk);
            in_valid  = ($random % 100) < 70; // ~70% valid rate
            out_ready = ($random % 100) < 60; // ~60% ready rate
            if (in_valid) begin
                in_data  = beat_val;
                beat_val = beat_val + 8'h01;
            end
        end

        // Flush remaining beats
        @(negedge clk);
        in_valid  = 1'b0;
        out_ready = 1'b1;

        repeat (10) @(posedge clk);

        if (rd_ptr !== wr_ptr) begin
            $display("ERROR: Unconsumed beats left! Accepted=%0d, Consumed=%0d", wr_ptr, rd_ptr);
            err_cnt = err_cnt + 1;
        end

        if (err_cnt == 0)
            $display("TEST PASSED: All %0d beats delivered in strict order with 0 protocol errors.", wr_ptr);
        else
            $display("TEST FAILED: %0d error(s) detected.", err_cnt);

        $finish;
    end

endmodule
