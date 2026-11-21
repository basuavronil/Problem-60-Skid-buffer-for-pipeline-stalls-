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

<img width="638" height="278" alt="image" src="https://github.com/user-attachments/assets/7f2b4256-5c72-48f8-975d-c87eea4a1a15" />

<img width="799" height="283" alt="image" src="https://github.com/user-attachments/assets/ef25984c-fcca-4d28-9daf-cfadf3233a41" />

<img width="653" height="326" alt="image" src="https://github.com/user-attachments/assets/6c9a5402-769a-4601-8cdc-df73698f2732" />

<img width="742" height="343" alt="image" src="https://github.com/user-attachments/assets/f14c3a9d-2ef3-4eab-b6c2-094b1fe2cdab" />

<img width="802" height="388" alt="image" src="https://github.com/user-attachments/assets/38dec5c7-6062-4482-a117-bcb2cd455250" />

<img width="783" height="304" alt="image" src="https://github.com/user-attachments/assets/dcf6f977-0ba0-44e3-83b9-8c8b6a382ec7" />
