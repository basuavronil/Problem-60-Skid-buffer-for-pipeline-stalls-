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

    // Can take new input if skid_reg is empty or is being drained this cycle
    assign in_ready = !skid_valid;
    assign out_valid = main_valid;
    assign out_data  = main_reg;

    always @(posedge clk) begin
        if (rst) begin
            main_reg   <= 8'd0;
            skid_reg   <= 8'd0;
            main_valid <= 1'b0;
            skid_valid <= 1'b0;
        end else begin
            // 1. Downstream takes current output beat
            if (out_valid && out_ready) begin
              if (skid_valid) begin
                 // Drain the older skid_reg beat into main_reg first; keep order intact
                main_reg   <= skid_reg;
                main_valid <= 1'b1;
                skid_valid <= 1'b0;
                end 
              else if (in_valid && in_ready) begin
                 // Skid is empty and old main_reg beat is consumed: load new beat directly
                 main_reg   <= in_data;
                 main_valid <= 1'b1;
               end 
              else begin
                 main_valid <= 1'b0;
              end
           end

            // 2. Downstream is NOT taking current output beat
            else if (in_valid && in_ready) begin
                if (!main_valid) begin
                    // main_reg was empty, load directly
                    main_reg   <= in_data;
                    main_valid <= 1'b1;
                end else if (!skid_valid) begin
                    // main_reg is busy holding older data, park new beat in skid_reg
                    skid_reg   <= in_data;
                    skid_valid <= 1'b1;
                end
            end
        end
    end
endmodule
