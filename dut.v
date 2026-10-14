module skid_buffer (
    input  wire       clk,
    input  wire       rst,

    // Upstream Interface (Master Side)
    input  wire [7:0] in_data,
    input  wire       in_valid,
    output wire       in_ready,

    // Downstream Interface (Slave Side)
    output wire [7:0] out_data,
    output wire       out_valid,
    input  wire       out_ready
);

    // Internal Data Registers
    reg [7:0] main_reg;
    reg [7:0] skid_reg;

    // Internal Occupancy Flags
    reg       main_valid;
    reg       skid_valid;

    // ------------------------------------------------------------------------
    // Combinational Control & Datapath
    // ------------------------------------------------------------------------

    // Upstream ready: deasserted while the skid register is full,
    // reasserts once the skid is empty (registered -> one-cycle latency)
    assign in_ready  = !skid_valid;

    // Downstream valid: skid_valid always implies main_valid, so this is
    // the same as main_valid
    assign out_valid = main_valid || skid_valid;

    // Datapath: main_reg ALWAYS drives the slave (it holds the OLDER beat).
    // skid_reg never drives the output; it only refills main_reg.
    assign out_data  = main_reg;

    // ------------------------------------------------------------------------
    // Synchronous Register Logic
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            main_reg   <= 8'd0;
            skid_reg   <= 8'd0;
            main_valid <= 1'b0;
            skid_valid <= 1'b0;
        end else begin

            // 1. Upstream Transfer Handling (Master -> main / skid)
            if (in_valid && in_ready) begin
                if (out_ready || !out_valid) begin
                    // Slave is OPEN or buffer is EMPTY: push directly into main_reg
                    main_reg   <= in_data;
                    main_valid <= 1'b1;
                end else begin
                    // STALL: main_reg holds beat A and the slave is not ready.
                    // main_reg stays as it is; beat B is parked in skid_reg.
                    skid_reg   <= in_data;
                    skid_valid <= 1'b1;
                end
            end else if (out_ready && main_valid && !skid_valid) begin
                // No incoming data and the slave took main_reg: clear it
                // so the same beat is not sent twice
                main_valid <= 1'b0;
            end

            // 2. Skid Drain Handling
            if (out_ready && main_valid && skid_valid) begin
                // Slave asserted ready: beat A leaves main_reg this edge, and
                // on the SAME edge beat B moves skid_reg -> main_reg.
                // The skid becomes empty, so in_ready goes high again.
                main_reg   <= skid_reg;
                skid_valid <= 1'b0;
            end

        end
    end

endmodule
