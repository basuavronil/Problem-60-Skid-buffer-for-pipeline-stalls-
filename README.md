# Skid Buffer 
<img width="617" height="176" alt="image" src="https://github.com/user-attachments/assets/a945ba85-09fe-40bc-b252-9e03c9580fad" />

<img width="635" height="382" alt="image" src="https://github.com/user-attachments/assets/d4229712-0450-40a4-badb-5406ae5b4d67" />

<img width="630" height="358" alt="image" src="https://github.com/user-attachments/assets/511dcee2-fa83-42a1-aa5a-bd0fd4929b3a" />

<img width="431" height="176" alt="image" src="https://github.com/user-attachments/assets/5d456552-cffd-43ff-9958-84f96450b280" />

<img width="636" height="207" alt="image" src="https://github.com/user-attachments/assets/4d352a0f-d606-45a2-a8ee-6f92362f6c88" />

# Why a Combinational `ready` Signal Is a Bottleneck

## Question
Why is a combinational `ready` signal a bottleneck?

## Explanation
A combinational ready signal can chain delays across multiple stages inside a single clock cycle, easily creating a slow timing path that caps your clock frequency.

<img width="638" height="278" alt="image" src="https://github.com/user-attachments/assets/7f2b4256-5c72-48f8-975d-c87eea4a1a15" />

<img width="799" height="283" alt="image" src="https://github.com/user-attachments/assets/ef25984c-fcca-4d28-9daf-cfadf3233a41" />

<img width="653" height="326" alt="image" src="https://github.com/user-attachments/assets/6c9a5402-769a-4601-8cdc-df73698f2732" />

<img width="742" height="343" alt="image" src="https://github.com/user-attachments/assets/f14c3a9d-2ef3-4eab-b6c2-094b1fe2cdab" />

<img width="802" height="388" alt="image" src="https://github.com/user-attachments/assets/38dec5c7-6062-4482-a117-bcb2cd455250" />

<img width="783" height="304" alt="image" src="https://github.com/user-attachments/assets/dcf6f977-0ba0-44e3-83b9-8c8b6a382ec7" />

# Pipelining the `ready` Signal & Skid Buffer Placement

## 1. Why We Pipeline `ready` (Making It Sequential)
* **The Problem (Long Combinational `ready`):** In a basic valid-ready pipeline, `ready` propagates backward combinationally across multiple stages inside a single clock cycle, accumulating large cell and wire delays that create a critical timing bottleneck.
* **The Fix (Sequential `ready`):** By inserting a flip-flop (`FF`) on the `ready` path, we pipeline `ready` and convert it into a sequential signal. This breaks the long combinational chain into shorter, clock-bounded segments, eliminating accumulated cell delays and improving maximum clock frequency ($F_{\max}$).

## 2. How the `ready` Flip-Flop and Skid Buffer Are Positioned
* **Same Boundary, Opposite Paths:** Both sit at the **exact same interface boundary** between the upstream **Master** (Sender) and downstream **Slave** (Receiver), operating on two opposite signal paths:
  * **Backward Path (`Slave → Master`):** The registered **`ready` flip-flop** sits on the backward control path, delaying the backpressure signal by 1 clock cycle to break timing.
  * **Forward Path (`Master → Slave`):** The **Skid Buffer** (extra data/valid holding register) sits on the forward datapath, safely capturing any in-flight `data` and `valid` beat that arrives during that 1-cycle `ready` delay so nothing is overwritten or lost.


# Skid Buffer vs. 1-Deep / 2-Deep FIFOs & Timing Considerations

---

## 1. Why Do We Use a Skid Buffer Instead of a 1-Deep or 2-Deep FIFO?

### Skid Buffer vs. Depth-1 FIFO
A standard **1-deep registered FIFO** adds **1 cycle of latency** on every transfer and **cannot accept a new beat while full**, whereas a **skid buffer** gives you **0-cycle bypass/throughput** when unblocked and **1 extra beat of headroom** when backpressure arrives.

* **Latency (0 Cycles vs. 1 Cycle):**
  * **Depth-1 FIFO:** Incoming data is written into the FIFO register on one clock edge and only appears at the output on a later cycle (typically 1-cycle latency in a standard registered FIFO).
  * **Skid buffer:** When downstream is ready (`out_ready == 1`) and there is no stalled/buffered beat waiting (`!skid_valid`), data passes through without waiting an extra cycle in a staging FIFO.
* **Full-Throughput & Backpressure Behavior:**
  * **Depth-1 FIFO:** Once that 1 slot is occupied and not being read, `full` is asserted (`ready = 0`). If `ready` is registered (to avoid a long combinational timing path), `ready` only drops on the *next* cycle—meaning an in-flight beat arriving during that 1-cycle delay has nowhere to go if the single slot is already holding an unconsumed word.
  * **Skid buffer:** Designed specifically around **registered `ready`** (breaking long backward timing paths). It keeps `main_reg` for the active/current beat and uses `skid_reg` as a dedicated parking slot for the **one extra beat** that arrives while `ready` is transitioning from `1` to `0`, preserving strict in-order delivery without dropping data or creating combinational backpressure loops.

---

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

endmodule

```
