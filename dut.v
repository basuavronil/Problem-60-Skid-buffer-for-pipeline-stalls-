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
    
    // Upstream ready: Accept data as long as the skid holding register is empty
    assign in_ready  = !skid_valid;

    // Downstream valid: Valid data exists if either register is occupied
    assign out_valid = main_valid || skid_valid;

    // Datapath MUX: Drive skid_reg data first during stall drain; otherwise main_reg
    assign out_data  = skid_valid ? skid_reg : main_reg;

    // ------------------------------------------------------------------------
    // Synchronous Register Logic
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) 
            begin
              main_reg   <= 8'd0;
              skid_reg   <= 8'd0;
              main_valid <= 1'b0;
              skid_valid <= 1'b0;
            end 
        else 
            begin
            // 1. Upstream Transfer Handling (Master -> Skid Buffer)
              if (in_valid && in_ready) 
                begin
                    if (out_ready || !out_valid) 
                    // slave is ready to receive data 
                    // but both the skid buffer and the main buffer is empty
                    begin
                    // Slave is OPEN: Push directly into main register
                      main_reg   <= in_data;
                      main_valid <= 1'b1;
                    end 
                  else 
                      begin
                    // Slave is STALLED (out_ready == 0): Skid in-flight item into holding register
                       skid_reg   <= in_data;
                       skid_valid <= 1'b1;
                      end
                end 
            else if (out_ready) 
                begin
                // No incoming data, but downstream consumer is reading main register
                  main_valid <= 1'b0;
                end

            // 2. Skid Holding Register Drain Handling
            if (out_ready && skid_valid) 
                begin
                // Downstream resumed: Clear skid register flag after sending held data
                  skid_valid <= 1'b0;
                end
        end
    end

endmodule
