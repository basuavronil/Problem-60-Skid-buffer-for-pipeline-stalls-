# Q. What happens when both the slave stalls and both the main buffer and the skid buffer is full (main_valid == 1) && (Skid_valid == 1) and then the Slave gives (ready == 1) 

``` text
1. During the stall, the main register held beat A and the skid register captured beat B, which arrived
 while the upstream hadn’t yet seen the stall (the one-cycle ready latency).
2. When the slave asserts ready, A leaves from the main register. The slave sees data = main.
3. On that same clock edge, B moves from the skid register into the main register, and the skid becomes
empty.
4. ready to the upstream master is deasserted while the skid is full. It reasserts only once the skid
 is empty, so no data is lost.

```
