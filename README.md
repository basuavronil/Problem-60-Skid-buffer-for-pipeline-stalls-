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
