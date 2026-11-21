# Forward Register Slice vs. Skid Buffer

## 1. What is a Forward Register Slice?

A **forward register slice** (often called a **forward pipeline stage** or **data/valid register slice**) is a single-stage pipeline buffer placed on a `valid`/`ready`/`data` handshake interface whose **forward path (`valid` and `data`) is registered on the clock edge**, while its **backward path (`ready`) is driven combinationally**.

### How It Works
* **Forward path (`out_data`, `out_valid`):** Captures `in_data` and `in_valid` on `posedge clk` whenever the stage can accept a beat (`in_ready`). This breaks long combinational `data` and `valid` paths between pipeline stages or blocks.
* **Backward path (`in_ready`):** Driven combinationally by `!out_valid || out_ready`. If the output register is empty (`!out_valid`) or downstream is consuming the current beat right now (`out_ready`), `in_ready` is `1` in that very same cycle.

### Why It's Called "Forward"
Unlike a **reverse register slice** (which registers `ready` backward and leaves `valid`/`data` combinational) or a **full skid buffer** (which registers `ready` backward *and* adds a `skid_reg` so `valid`/`data` stay registered with full throughput), a forward register slice puts its flip-flops in the **forward (`valid`/`data`) direction**.

### Key Pros & Cons
* **Pros:** Uses only one register stage (`out_data` + `out_valid`), breaks combinational `data`/`valid` paths, and gives immediate same-cycle `in_ready` updates without extra skid storage.
* **Cons:** Because `in_ready` combinationally depends on `out_ready`, downstream backpressure logic can still form a long combinational path into the upstream master at high clock frequencies.

---

## 2. Key Differences: Forward Slice vs. Skid Buffer

| Feature | Forward Register Slice (Without Skid Buffer) | Skid Buffer (With Skid Buffer) | 
| :--- | :--- | :--- | 
| **`in_ready` Path** | **Combinational** (`!out_valid \|\| out_ready`) — reacts immediately in the same cycle | **Sequential / Registered** (`!skid_valid`) — updates only after `posedge clk` | 
| **Backpressure Timing** | Extends downstream `out_ready` logic into upstream logic, increasing **setup timing** risk | Isolates backpressure at a flip-flop boundary to break long combinational paths | 
| **Role of `out_ready`** | Directly gates `in_ready` combinationally and controls register load | Excluded from `in_ready`; used inside `always @(posedge clk)` for drain/stall register updates | 
| **Data Storage** | 1 data register (`out_data`) + 1 valid register (`out_valid`) | 2 data registers (`main_reg`, `skid_reg`) + 2 valid registers (`main_valid`, `skid_valid`) | 
| **In-Flight Beat Handling** | Relies on immediate combinational `in_ready` drop so no extra beat is pushed while stalled | Parks 1 in-flight beat in `skid_reg` during the 1-cycle registered `ready` reaction window | 
| **Throughput** | 1 beat/cycle when unblocked (subject to combinational `out_ready` delay) | 1 beat/cycle with zero bubble cycles on drain/load transitions | 

---

## 3. Combinational vs. Sequential `in_ready` (Why `assign` Alone Doesn't Decide)

A continuous `assign` statement simply drives a `wire`—it does not by itself make a signal combinational or sequential. What determines whether `in_ready` is **combinational** or **sequential (registered)** is what sits on the right-hand side (`RHS`) of that `assign`:

* **Combinational `in_ready` (`assign in_ready = !out_valid || out_ready;`):**
  Even though it is written with `assign`, the RHS uses a logic gate/MUX (`||`) combining `out_valid` and `out_ready`. Any change on `out_ready` immediately flows through that `||` gate onto `in_ready` within the **same clock cycle** without waiting for a clock edge. That gate delay (plus whatever logic generated `out_ready` downstream) is part of the combinational path.

* **Sequential / Registered `in_ready` (`assign in_ready = !skid_valid;`):**
  Here `skid_valid` is the direct **Q output of a flip-flop** (`always @(posedge clk)`). The `assign` just routes that flop's Q output to the `in_ready` wire—there is no `out_ready` logic in the path, and `in_ready` only changes **after `posedge clk`** when `skid_valid` updates.

---

## 4. Verilog Implementations

### Forward Register Slice (Combinational `in_ready`)

```verilog
module forward_register_slice (
    input  wire       clk,
    input  wire       rst,

    // Upstream Interface (Master Side)
    input  wire [7:0] in_data,
    input  wire       in_valid,
    output wire       in_ready,

    // Downstream Interface (Slave Side)
    output reg  [7:0] out_data,
    output reg        out_valid,
    input  wire       out_ready
);

    // Combinational ready: can accept new beat if empty OR if downstream is taking current beat
    assign in_ready = !out_valid || out_ready;

    always @(posedge clk) begin
        if (rst) begin
            out_data  <= 8'd0;
            out_valid <= 1'b0;
        end else if (in_ready) begin
            out_data  <= in_data;
            out_valid <= in_valid;
        end
    end

endmodule
```

### Skid Buffer (Sequential / Registered `in_ready` + `skid_reg`)

```verilog
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

    // Internal Data & Valid Registers
    reg [7:0] main_reg, skid_reg;
    reg       main_valid, skid_valid;

    // Sequential/registered ready (via skid_valid): breaks combinational backpressure path
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
            // 1. Downstream consumes current output beat
            if (out_valid && out_ready) begin
                if (skid_valid) begin
                    // Drain older skidded beat into main_reg first
                    main_reg   <= skid_reg;
                    main_valid <= 1'b1;
                    skid_valid <= 1'b0;
                end else if (!skid_valid && in_valid && in_ready) begin
                    // Skid is empty and old main_reg beat is consumed: load new beat directly
                    main_reg   <= in_data;
                    main_valid <= 1'b1;
                end else begin
                    // Nothing left to drive out
                    main_valid <= 1'b0;
                end
            end
            // 2. Downstream stalls (!out_ready or !out_valid)
            else if (in_valid && in_ready) begin
                if (!main_valid) begin
                    // main_reg is empty: load directly
                    main_reg   <= in_data;
                    main_valid <= 1'b1;
                end else if (!skid_valid) begin
                    // main_reg is occupied: park in-flight beat in skid_reg
                    skid_reg   <= in_data;
                    skid_valid <= 1'b1;
                end
            end
        end
    end

endmodule
```
