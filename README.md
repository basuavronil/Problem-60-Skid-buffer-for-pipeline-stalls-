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
