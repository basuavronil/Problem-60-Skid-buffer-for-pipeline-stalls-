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
    reg [7:0] main_reg, skid_reg;
    reg       main_valid, skid_valid;

    assign in_ready  = !skid_valid;
    assign out_valid = main_valid;
    assign out_data  = main_reg;

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
                    main_reg   <= in_data;
                    main_valid <= 1'b1;
                end else if (!out_ready && out_valid) 
                    begin
                    skid_reg   <= in_data;
                    skid_valid <= 1'b1;
                    end
            end else if (out_ready && main_valid && !skid_valid) begin
                main_valid <= 1'b0;
            end

            // 2. Skid Drain Handling
          if (out_ready && main_valid && skid_valid) begin
                main_reg   <= skid_reg;
                skid_valid <= 1'b0;
            end

        end
    end

endmodule
