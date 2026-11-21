### Skid Buffer vs. Depth-2 FIFO
You *can* use a 2-deep FIFO in some designs, and sometimes people do—but a skid buffer is usually preferred at timing-critical `valid`/`ready` boundaries because a standard 2-deep FIFO has a few trade-offs in **latency, control complexity, and area/timing**.

#### 1. Extra Latency & Bubble Cycles
* **Standard 2-deep FIFO:** Typically registers writes on one clock edge and presents read data either on the next cycle (registered output) or combinationally from the read pointer/mux. If you want registered outputs and clean empty/full flags without combinational `ready` loops, transitions between empty, 1-entry, and 2-entry states can easily introduce 1-cycle latency or stall bubbles when switching between pass-through and buffered operation.
* **Skid buffer:** Keeps a simple **1-beat bypass/main path** plus **1 skid register**, specifically tuned so normal flow has zero extra staging delay while a 1-cycle registered `ready` lag is absorbed cleanly.

#### 2. More State & Pointer / Flag Logic Than Needed
* **2-deep FIFO:** Needs read/write pointers (or a 2-bit shift/occupancy tracker), empty/full/almost-full decode logic, and careful handling of simultaneous push + pop when full (`count == 2`).
* **Skid buffer:** Only needs to distinguish **normal flow** vs. **1 skidded beat waiting (`skid_valid`)**, which keeps the control state minimal and easier to verify for timing and handshake corner cases.

#### 3. Area & Muxing Cost on Wide Buses
* A 2-deep FIFO stores **two full data words** (plus pointer/control logic), whereas a skid buffer also uses **two data registers** (`main_reg` and `skid_reg`)—so on data width alone they are similar—but the FIFO's extra pointer/status decode logic adds overhead if you only ever needed to absorb **1 cycle of registered `ready` latency**.

#### When a 2-Deep FIFO *Does* Make Sense
* When you want **elastic buffering across bursts** or multiple cycles of rate mismatch—not just absorbing a 1-cycle registered `ready` delay—or when your design already standardizes on a reusable FIFO macro.

---

### Can a 2-Deep FIFO Solve the 1-Clock-Cycle Latency Issue?
It **can**—if you wire it as a **fall-through / bypass (FWFT) FIFO** where an empty FIFO forwards `data_in` combinationally to `data_out` on the same cycle. The catch is that combinational bypass creates a **combinational path from `in_data` to `out_data`**, which can hurt timing at high clock frequencies and still requires care not to create a combinational loop between `ready` and `valid`.

* **Registered output = 1 cycle of latency:** If the FIFO's output is registered (`out_data` comes from a flip-flop), writing on `posedge clk` means the data takes at least 1 clock edge to appear at `out_data`—regardless of whether the FIFO is 1-deep or 2-deep.
* **Combinational bypass = 0-cycle latency, higher timing risk:** A 2-deep fall-through FIFO *can* achieve 0-cycle latency when empty by muxing `in_data` straight to `out_data`, just like a skid buffer's bypass path—but you lose the clean separation of a dedicated `main_reg` + `skid_reg` designed specifically for registered `ready` backpressure.

---

## 2. Combinational Timing Risks: Setup vs. Hold Violations

When talking about combinational paths risking timing, **it is usually a setup (max-delay) violation**, not a hold violation—though a fast path *can* cause a hold violation in specific situations.

### 1. Why Combinational Paths Normally Hurt *Setup* Timing
* **Setup timing** checks that a signal launched on one clock edge arrives at the next flip-flop **before** the next clock edge:
  $$T_{\text{arrival}} \le T_{\text{clk}} - T_{\text{setup}}$$
* Long combinational logic (or long chains of `ready`/`valid` or bypass muxes across stages) increases **propagation delay**, making the signal arrive *late* and causing a **setup violation** (limiting your maximum clock frequency).

### 2. When a Fast Path Causes a *Hold* Violation
* **Hold timing** checks that a signal stays stable **after** the active clock edge so the receiving flip-flop doesn't capture the *new* value instead of the *previous* one:
  $$T_{\text{data\_change}} \ge T_{\text{hold}} + T_{\text{skew}}$$
* If a signal launches on `posedge clk` and travels through a very short, fast combinational path (or has clock skew where the launch clock is late relative to the capture clock), it can reach the next flip-flop **too soon** after the clock edge and overwrite the previous data—that is a **hold violation**.
* An "empty" wire itself doesn't make a signal go faster than physics allows; a path only fails hold when its delay is **too small** relative to clock skew and flip-flop hold time (which EDA tools fix by inserting delay/buffer cells, not by making logic slower on purpose).

### How This Connects to Skid Buffers
* Registering `ready` or isolating stages with flip-flops breaks long combinational chains across module boundaries so **setup slack** doesn't degrade at high frequencies.
* Once synthesized and placed, Static Timing Analysis (STA) checks **both** setup (max delay) and hold (min delay) on every path—including bypass muxes and handshake signals.


# Forward Register Slice vs. Skid Buffer

## 1. Key Differences

| Feature | Forward Register Slice (Without Skid Buffer) | Skid Buffer (With Skid Buffer) | 
| ----- | ----- | ----- | 
| **`in_ready` Path** | **Combinational** (`!out_valid || out_ready`) — reacts immediately in the same cycle | **Sequential / Registered** (`!skid_valid`) — updates only after `posedge clk` | 
| **Backpressure Timing** | Extends downstream `out_ready` logic into upstream logic, increasing **setup timing** risk | Isolates backpressure at a flip-flop boundary to break long combinational paths | 
| **Role of `out_ready`** | Directly gates `in_ready` combinationally and controls register load | Excluded from `in_ready`; used inside `always @(posedge clk)` for drain/stall register updates | 
| **Data Storage** | 1 data register (`out_data`) + 1 valid register (`out_valid`) | 2 data registers (`main_reg`, `skid_reg`) + 2 valid registers (`main_valid`, `skid_valid`) | 
| **In-Flight Beat Handling** | Relies on immediate combinational `in_ready` drop so no extra beat is pushed while stalled | Parks 1 in-flight beat in `skid_reg` during the 1-cycle registered `ready` reaction window | 
| **Throughput** | 1 beat/cycle when unblocked (subject to combinational `out_ready` delay) | 1 beat/cycle with zero bubble cycles on drain/load transitions | 

## 2. Combinational vs. Sequential `in_ready` (Why `assign` Alone Doesn't Decide)

A continuous `assign` statement simply drives a `wire`—it does not by itself make a signal combinational or sequential. What determines whether `in_ready` is **combinational** or **sequential (registered)** is what sits on the right-hand side (`RHS`) of that `assign`:

* **Combinational `in_ready` (`assign in_ready = !out_valid || out_ready;`):**
  Even though it is written with `assign`, the RHS uses a logic gate/MUX (`||`) combining `out_valid` and `out_ready`. Any change on `out_ready` immediately flows through that `||` gate onto `in_ready` within the **same clock cycle** without waiting for a clock edge. That gate delay (plus whatever logic generated `out_ready` downstream) is part of the combinational path.

* **Sequential / Registered `in_ready` (`assign in_ready = !skid_valid;`):**
  Here `skid_valid` is the direct **Q output of a flip-flop** (`always @(posedge clk)`). The `assign` just routes that flop's Q output to the `in_ready` wire—there is no `out_ready` logic in the path, and `in_ready` only changes **after `posedge clk`** when `skid_valid` updates.

## 3. Verilog Implementations

### Forward Register Slice (Combinational `in_ready`)

```
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

```
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
