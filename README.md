# Skid Buffer (Pipeline Register Stage)

## Overview
The `skid_buffer` is a zero-latency, full-throughput pipeline stage designed to decouple combinational handshaking paths (`ready`/`valid`) between upstream Master and downstream Slave interfaces. 

By employing a primary storage register alongside a secondary holding register, it safely absorbs in-flight data during sudden downstream stalls (`out_ready = 0`) without dropping transfers or introducing bubble cycles into the pipeline.

---

## Architecture & Data Flow

The module utilizes two internal data registers paired with corresponding single-bit occupancy flags:

* **`main_reg` / `main_valid`**: Primary data path used during normal continuous streaming.
* **`skid_reg` / `skid_valid`**: Emergency holding slot used exclusively to capture in-flight upstream data when the downstream receiver halts.

```text
                  +-----------------------------------+
                  |            SKID BUFFER            |
                  |                                   |
                  |   +----------+     +----------+   |
-- in_data [7:0] -+-->| main_reg |---->|          |   |
                  |   +----------+     |  DATAPATH|   |-- out_data [7:0]
                  |                    |    MUX   |---|
                  |   +----------+     |          |   |
                  +-->| skid_reg |---->|          |   |
                      +----------+     +----------+   |
                                            ^         |
                                            |         |
                                       skid_valid     |
                                                      |
-- in_valid ------------------------------------------|-- out_valid
<- in_ready (<-- !skid_valid) ------------------------|<- out_ready

Handshake State MatrixBuffer StateUpstream Handshake (in_valid && in_ready)Downstream Readiness (out_ready)Internal ActionMUX Selection (out_data)Idle / Empty0XHolds empty state (main_valid=0, skid_valid=0).main_regDirect Stream11Data flows directly into main_reg.main_regStall Triggered10In-flight item skids into skid_reg (skid_valid=1). Deasserts in_ready.skid_regStalled / Full0 (Blocked)0Holds both registers (main_valid=1, skid_valid=1).skid_regRecovery Drain01Drains skid_reg to Slave. Clears skid_valid to 0, re-asserting in_ready.skid_reg $\rightarrow$ main_regPort DefinitionsUpstream Interface (Master Side)clk: System Clock.rst: Synchronous Active-High Reset.in_data[7:0]: 8-bit Input Data Payload.in_valid: Input Data Valid Flag.in_ready: Input Ready Backpressure Signal (assign in_ready = !skid_valid).Downstream Interface (Slave Side)out_data[7:0]: 8-bit Output Data Payload (assign out_data = skid_valid ? skid_reg : main_reg).out_valid: Output Data Valid Flag (assign out_valid = main_valid || skid_valid).out_ready: Downstream Ready/Accept Signal from Slave.Key FeaturesZero-Bubble Throughput: Maintains 100% processing efficiency ($1$ transaction per clock cycle) under backpressure recovery.Timing Closure Optimization: Eliminates long combinational paths on ready loops, maximizing achievable operating frequency ($F_{max}$).Origin-Based Naming Convention: Clean port abstraction using directional prefixes (in_ and out_).Robust Reset Guarantee: Synchronous reset forces occupancy flags low (main_valid = 0, skid_valid = 0), preventing false assertions on startup.
