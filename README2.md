# AXI / Valid-Ready Handshake Timing: Forward Register Slice vs. Skid Buffer

## #1. Forward vs. Backpressure Control Signals

* **Forward Scenario (`m_valid` / `out_valid`) — Sequential in BOTH:**
  * **Forward Register Slice:** **Sequential** $\rightarrow$ `assign m_valid = valid_reg;` (FF-to-FF)
  * **Skid Buffer:** **Sequential** $\rightarrow$ `assign m_valid = main_valid;` (FF-to-FF)

* **Backpressure Scenario (`s_ready` / `in_ready`) — Only Skid Buffer is Sequential:**
  * **Forward Register Slice (Pipeline):** **Combinational** $\rightarrow$ `assign s_ready = m_ready | (~valid_reg);`
  * **Skid Buffer:** **Sequential** $\rightarrow$ `assign s_ready = ~skid_valid;`

---

## #2. Two Golden Rules: Combinational vs. Sequential in Verilog

### Rule 1: `assign` with Direct Input on RHS $\rightarrow$ **Combinational**
* When the `LHS` of a continuous `assign` statement depends directly on any **module input port** (or a wire driven combinationally from an input port), the path from that input to the `LHS` is **combinational**.
* Changes on the input ripple straight through the logic gates (`|`, `&`, `~`) to the output **within the same clock cycle**—no flip-flop boundary exists.
* **Example:** `assign s_ready = m_ready | (~valid_reg);` $\rightarrow$ Direct combinational path from input `m_ready` to output `s_ready`.

### Rule 2: Inside `always @(posedge clk)` $\rightarrow$ **Sequential**
* When the exact same logic expression sits inside a clocked `always @(posedge clk)` block (using non-blocking `<=`), the flip-flop acts as a **clock-edge barrier**.
* Input changes settle before the clock edge, and the flip-flop's `Q` output updates **only after `posedge clk`** (after $T_{\text{cq}}$).
* **Example:** `valid_reg <= s_valid;` inside `always @(posedge clk)` $\rightarrow$ Creates a clean **FF-to-FF sequential boundary** (`assign m_valid = valid_reg;`).

---

## #3. Forward `valid` Path (FF-to-FF in Both)

```text
[Upstream FF] ──► (s_valid / in_valid) ──► [valid_reg / main_valid FF] ──► (m_valid / out_valid) ──► [Downstream FF]
```

* **Launch (`T0`):** Upstream FF drives `s_valid` / `in_valid`.
* **Register (`T1`):** Internal FF (`valid_reg` or `main_valid`) captures and drives **`m_valid` / `out_valid`**.
* **Sample (`T2`):** Downstream FF captures **`m_valid` / `out_valid`**.
* Splits forward `valid` into **two FF-to-FF segments** in both designs.

---

## #4. Backward `ready` Bottleneck (Forward Slice Issue)

```text
[Upstream Master] ---> (s_valid / s_data) ---> [Flop] ---> (m_valid / m_data) ---> [Downstream Slave]
                  <--- (s_ready) <----------- [ OR/AND ] <--- (m_ready) <----------
                                              ^ No flip-flop boundary!
```

* Combinational `s_ready` (`m_ready | ~valid_reg`) $\rightarrow$ No FF-to-FF boundary backward $\rightarrow$ Downstream delay leaks upstream $\rightarrow$ **Setup violations** at high frequency.

---

## #5. Why Any Logic Gate (`|`, `&`, `~`) in `assign` Is Combinational

* **`assign s_ready = m_ready | (~valid_reg);`** $\rightarrow$ **Combinational** (`m_ready` ripples through `|` in the same cycle).
* **`assign s_ready = m_ready & (~valid_reg);`** $\rightarrow$ **Still combinational** (`m_ready` still on RHS) **+ cuts throughput in half** (adds bubble cycles when `valid_reg == 1`).
* **`assign s_ready = ~skid_valid;`** $\rightarrow$ **Sequential** (direct `Q` output of a flip-flop, no `m_ready` in path).

---

## #6. Forward Register Slice RTL

```verilog
module axi_handshake_reg (
    input  wire        clk,        
    input  wire        rst_n,               
    input  wire [31:0] s_data,        
    input  wire        s_valid,               
    output wire        s_ready,                                         
    output wire [31:0] m_data,   
    output wire        m_valid,             
    input  wire        m_ready          
);
    reg [31:0] data_reg;
    reg        valid_reg;        

    assign s_ready = m_ready | (~valid_reg); // Combinational ready (Rule 1)
    assign m_data  = data_reg;               // Sequential data (Rule 2)
    assign m_valid = valid_reg;              // Sequential valid (Rule 2)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg <= 1'b0;    
            data_reg  <= 32'h0;
        end else if (s_ready) begin
            valid_reg <= s_valid;
            if (s_valid) data_reg <= s_data;
        end
    end
endmodule
```

---

## #7. How the Skid Buffer Solves It

* **Registers `s_ready` (`~skid_valid`):** Creates a true FF-to-FF boundary in the backward direction.
* **Adds `skid_reg`:** Catches the 1 in-flight beat during the 1-cycle stall reaction window.
* **Zero bubble cycles:** Drains `skid_reg` $\rightarrow$ `main_reg` seamlessly at 1 beat/cycle.

```verilog
module axi_skid_buffer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] s_data,
    input  wire        s_valid,
    output wire        s_ready,
    output wire [31:0] m_data,
    output wire        m_valid,
    input  wire        m_ready
);
    reg [31:0] main_reg, skid_reg;
    reg        main_valid, skid_valid;

    assign s_ready = ~skid_valid; // Sequential ready (FF Q output)
    assign m_valid = main_valid;  // Sequential valid (FF Q output)
    assign m_data  = main_reg;    // Sequential data  (FF Q output)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            main_reg   <= 32'h0;
            skid_reg   <= 32'h0;
            main_valid <= 1'b0;
            skid_valid <= 1'b0;
        end else begin
            if (m_valid && m_ready) begin
                if (skid_valid) begin
                    main_reg   <= skid_reg;
                    main_valid <= 1'b1;
                    skid_valid <= 1'b0;
                end else if (s_valid && s_ready) begin
                    main_reg   <= s_data;
                    main_valid <= 1'b1;
                end else begin
                    main_valid <= 1'b0;
                end
            end else if (s_valid && s_ready) begin
                if (!main_valid) begin
                    main_reg   <= s_data;
                    main_valid <= 1'b1;
                end else if (!skid_valid) begin
                    skid_reg   <= s_data;
                    skid_valid <= 1'b1;
                end
            end
        end
    end
endmodule
```

---

## #8. Quick Summary Table

| Scenario / Signal | Forward Register Slice (Pipeline) | Skid Buffer |
| :--- | :--- | :--- |
| **Forward (`m_valid` / `out_valid`)** | **Sequential** (`assign m_valid = valid_reg;`) | **Sequential** (`assign m_valid = main_valid;`) |
| **Backpressure (`s_ready` / `in_ready`)** | **Combinational** (`assign s_ready = m_ready \| (~valid_reg);`) | **Sequential** (`assign s_ready = ~skid_valid;`) |
| **Registers** | 1 data + 1 valid | 2 data + 2 valid |
| **Throughput** | 1 beat/cycle | 1 beat/cycle (0 bubbles) |
