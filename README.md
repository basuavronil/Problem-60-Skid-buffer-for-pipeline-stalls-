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
