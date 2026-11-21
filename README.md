# SKid Buffer (Chipmonk)
<img width="617" height="176" alt="image" src="https://github.com/user-attachments/assets/a945ba85-09fe-40bc-b252-9e03c9580fad" />

<img width="635" height="382" alt="image" src="https://github.com/user-attachments/assets/d4229712-0450-40a4-badb-5406ae5b4d67" />

<img width="630" height="358" alt="image" src="https://github.com/user-attachments/assets/511dcee2-fa83-42a1-aa5a-bd0fd4929b3a" />

<img width="431" height="176" alt="image" src="https://github.com/user-attachments/assets/5d456552-cffd-43ff-9958-84f96450b280" />

<img width="636" height="207" alt="image" src="https://github.com/user-attachments/assets/4d352a0f-d606-45a2-a8ee-6f92362f6c88" />

# Why a Combinational `ready` Signal Is a Bottleneck

## Question
Why is a combinational `ready` signal a bottleneck?

## Explanation
A combinational `ready` signal passes directly through logic gates and wires without waiting for a clock edge, which means if `ready` travels backward across multiple pipeline stages or drives many upstream blocks at once, all of those gate and wire delays stack up inside a single clock cycle. In hardware timing, everything inside one clock cycle must finish before the next rising edge arrives, so a long or high-fan-out combinational `ready` path easily becomes the slowest path in the design, limiting how fast your clock can run and making timing closure much harder.

