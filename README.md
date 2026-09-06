## Industrial Skid Buffer (Register Slice)

### Module Overview
The `skid_buffer` is a zero-latency, full-throughput pipeline register stage (Skid Buffer) designed to isolate combinational handshaking paths (`ready`/`valid`) between upstream Master and downstream Slave interfaces. 

By utilizing a primary storage register alongside a secondary holding register, it safely absorbs in-flight data during sudden downstream stalls (`out_ready = 0`) without dropping transfers or introducing bubble cycles into the pipeline.

---

### Internal Architecture & State Management

The module relies on two internal 8-bit data registers paired with corresponding single-bit occupancy flags:

* **`main_reg` / `main_valid`**: Primary data path used during standard continuous streaming.
* **`skid_reg` / `skid_valid`**: Emergency holding slot used exclusively to capture in-flight upstream data when the downstream receiver suddenly halts.
