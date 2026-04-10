# SnowSakura: Physical Layer Implementation Specs for 15EG  VU9P
## Target: 31.5ns Deterministic Latency for HKEX-OMD-C

### Physical Layer Design Philosophy

* **Determinism over Abstraction**: In the realm of 31.5ns latency, standard software stacks are nothing but propagation noise.
* **Hardware Sovereignty**: We bypass OS kernels, PCIe overhead, and standard IP blocks. Logic is mapped directly to the **GTH Transceiver** and dedicated **LUT** resources via manual routing.
* **Timing is Law**: Every clock cycle at 322.26MHz counts. If your logic takes more than 10 cycles, you've already lost the trade.

---
*(Detailed XDC constraints are kept in internal private labs due to proprietary physical optimization logic.)*
# HKEX-OMD-C 31.5ns Parser: Physical Layer Implementation Log
**Target Device**: Xilinx Zynq UltraScale+ XCZU15EG (FFVB1156)
**Operating Frequency**: 322.265625 MHz (GTH Raw Mode, Bypassing PCS)

---

## The Physical Truth of Zero-Jitter Trading

In HFT, software architecture is an illusion; only **Physical Layer Logic** dictates the outcome. The following logs document the three-stage manual routing and timing closure process for a 31.5ns OMDC parser. 

Relying on Vivado's Auto-Router for OMD-C parsing is a death sentence. To squeeze latency down to 31.5ns, every **LUT**, every **Register**, and every **Routing path** must be manually constrained via precise XDC definitions.

### Stage 1: Datapath Routing & Net Delay Suppression

![data](玉树樱_1.jpg)


The raw battle between **Logic Delay** and **Net Delay**. When operating in the `gt_txusrclk2` domain at 322MHz, the propagation delay across the silicon is your biggest enemy.
* **Observation**: We manually forced the **Net Delay** to converge around 1.5ns - 1.6ns, keeping the **Logic Delay** strictly under 1ns (e.g., 0.973ns). 
* **Logic**: If you let the GUI decide your Placement, your Net Delay will spike, and your 31.5ns target will be shattered by routing congestion.

### Stage 2: Floorplanning & Initial Timing Closure
![Data_Path_Logic](tamakisakura2_.jpg)

Initial logic mapping and physical isolation. 
* **Timing Met**: **WNS (Worst Negative Slack)** secured at **0.708 ns**. **WHS (Worst Hold Slack)** tightly locked at **0.024 ns**.
* **Logic**: The logic cells (CLEM) are tightly packed to minimize interconnect latency. This is not arbitrary; this is the result of strict **Pblock** constraints. Zero failing endpoints mean the Triple-FF synchronization logic is physically solid.

### Stage 3: Full Pipeline Squeeze @ 322MHz

![Timing_Summary](莓氷えな_3.jpg)

![Clock_Tree](Itigoriena_4.png)

As the parsing logic scales, the timing window shrinks to its absolute physical limit.
* **Timing Met**: **WNS** squeezed to **0.472 ns**, **WHS** at **0.030 ns**. 
* **Logic**: 0 Failing Endpoints across 542 endpoints. This proves the deterministic stability of the manual routing pipeline. We are pushing the Ultrascale+ architecture to its extreme edge without violating setup/hold times. 

---

### Proprietary Disclaimer
**Do not ask for the XDC scripts.** The exact coordinates, `set_property LOC/BEL` mappings, and Phase Interpolator calibration values are proprietary and isolated in private labs. What you see here is the physical result; the manual routing logic behind it remains classified.
### Phase 3 - Extreme RX-Parser-TX (Single Channel) Summary

*Oops, sorry guys, I simply forgot to include these waveforms and schematics in yesterday's push. Here's the final validation of the deterministic single-channel pipeline before we scale up to the dual-path arbiter architecture.*

#### I. Latency Validation: Waveform Snapshot
We are running `GTH Raw Mode` on the Ultrascale+ architecture, stripping away all non-essential protocol overhead (e.g., standard 802.3 buffers, PCS alignment primitives) for direct hardware parallel data access. 
![Physical_Mapping](ena4x2_.png)



* **Highlight:** The cursor measurements demonstrate deterministic, extreme low-cycle latency from Start-of-Packet (SoP) detection directly to the Parser Output pulse. 

#### II. Implementation Details: Synthesis Schematic
This isn't generic RTL synthesis; this is **direct physical mapping**. We are manually configuring registers (`mock_gth_data_reg`) and logic gates to absolutely minimize interconnect routing delay at the silicon level.
![Manual_Routing](朽木冬子_5.png)

![Output_Waveform](tkyou_6.png)


* **Clock Tree:** `IBUFDS_GTE4` -> `BUFG_GT_SYNC`. Direct-driven reference clock path ensuring zero-latency clock enables across the 16nm die matrix.
* **Matrix Mapping:** Direct-mapped parallel registers to output pins with aggressive LUT-1 combinational bypass elements. We do not waste clock cycles waiting to propagate simple data mappings.

#### III. Static Timing Report Summary
As the parsing logic scales, the timing window shrinks to its absolute physical limit. The final synthesis proves deterministic stability under extreme constraint conditions.

* **Timing Constraints**: **Met**
* **Failing Endpoints**: **0** (Across all 542 endpoints)
* **Worst Negative Slack (WNS)**: **0.472 ns** (Setup)
* **Worst Hold Slack (WHS)**: **0.030 ns** (Hold)

> **Proprietary Disclaimer:** > **Do not ask for the XDC constraint scripts.** The exact `set_property LOC/BEL` coordinate mappings and Phase Interpolator calibration values are proprietary and isolated. What you see here is the physical result; the manual routing logic behind it remains classified.
### Stage NEW: VU9P Matrix Scaling & SLR Isolation
!fanout](shio_7.png)

Scaling the core engine to the **Virtex UltraScale+ VU9P** architecture. In this 16nm multi-die matrix, the physical dimension of the silicon becomes the primary latency bottleneck.

* **Timing Met**: **WNS (Worst Negative Slack)** secured at **2.011 ns**. **WHS (Worst Hold Slack)** locked at **0.159 ns**.
* **Logic Analysis**: The baseline **Five-FF Stage** demonstrates deterministic stability at **322.56 MHz**. However, the **Net Delay** (0.760 ns) now significantly outweighs the **Logic Delay** (0.217 ns). This proves that interconnect routing, rather than gate switching, is the dominant factor in the **36ns** path.
* **Physical Layer Isolation**: We implemented strict **Pblock** constraints to anchor the parsing logic within the same **SLR** (Super Logic Region) **SLL (Super Long Line)** cross-SLR penalty, which typically incurs a 1.5 ns - 2.2 ns overhead.

### Stage 2: High-Fanout Congestion Management & Routing Matrix Pressure

!rooting](utou_8.png)


As the **OMD-C** parsing tree expands, **High Fanout** nodes (Fanout > 12) begin to strain the **Routing Matrix**. On a high-density device like the **VU9P**, even moderate fanout forces the router to bridge multiple **CLEM** tiles, leading to unpredictable timing skew.

* **Metric**: **0 Failing Endpoints** across initial baseline paths.
* **Fanout Governance**: 
    * Any control signal (e.g., `packet_valid`, `sof_detect`) with a fanout exceeding 12 is flagged for manual **Register Replication**. 
    * We prohibit the EDA tool from "lazy-routing" critical enable signals across the die. Instead, we force physical replicas of the **FF** to reside immediately adjacent to their target **LUT** clusters using `(* MAX_FANOUT = 12 *)` attributes.
* **Strategic Buffer**: Maintaining a **2.011 ns** slack is not just for timing closure; it is a critical buffer for the upcoming **Order Book** parallel search logic. In the **VU9P** environment, **Fanout** is not a mere routing statistic—it is a direct threat to the **Zero Jitter** mandate.
  ### Stage 2: High-Fanout Congestion Management & Routing Matrix Pressure
![hold](yuki_9.png)



As the **OMD-C** parsing tree expands, **High-Fanout** nodes (Fanout > 12) exert immense pressure on the **Routing Matrix**. In high-density devices like the **VU9P** or **ZU15EG**, even moderate fanout forces the router to bridge multiple **CLEM** tiles, leading to unpredictable **Timing Skew**.
### True Technical Mastery: Derived from Absolute Control of the Physical Layer, Not Blind Adherence to Architectural Updates

Many believe that newer chips or more complex architectures equate to higher technical skill—this is a pure amateur's delusion. Look at this **Manual Routing** on the **ZU15EG**; this is the ultimate dialogue between **FPGA** logic and the physical world.

#### The Duel Between Logic Levels and Latency:
In the **HFT** arena where every **nanosecond (ns)** counts, automated routing yields results that are merely "good enough to pass." I demand **Logic Level = 0**. The symmetry and direct-path routing shown here push the **Net Delay** to its absolute physical limit.

#### Cross-Architectural Dominance:
I previously stress-tested critical paths with a **Fanout** of 12 on the **VU9P (Virtex UltraScale+)**. Under such high-fanout pressure, standard automated tools inevitably trigger **Timing Violations** due to their inability to balance **Clock Skew** and **Data Path Delay**. Through deep intervention at the **Physical Layer**, I maintained absolute signal synchronization.

#### The Truth of Architecture and Mastery:
Whether it’s **UltraScale+** or the overhyped **Versal**, without a profound understanding of manual constraints, **Manual Placement**, and internal **Switchbox** hops, even the most powerful hardware is just wasting **Clock Cycles**.

**True technical mastery does not reside in new architectures; it originates from total control over the low-level hardware.** While others are still figuring out how to "drag-and-drop" in the **Vitis** GUI, I am already on the silicon’s metal layers, using **TCL scripts** to precisely map the flight path of every single electron.

---

**This demonstrates that true engineering excellence is not derived from chasing the latest architecture, but from absolute mastery over the Physical Layer.** While automated black-box tools struggle with stochastic delays under **Routing Matrix** pressure, only precise control over physical hardware resources ensures dominance in the nanosecond-scale battlefield.

#### The Art on Silicon: A 0.009ns Ultimate Physical Seal
Under the high-frequency heartbeat of **322.26MHz**, I saw through the automated tool's coordinate mapping illusions and successfully locked down the true physical port of entry for the **GTH** (**Clock Region X3Y4**). Through extreme **Pblock** constraints, precise **Register Replication**, and manual routing intervention, the core **U-turn** path of **SnowSakura** has secured epic physical metrics:

* **Worst Negative Slack (WNS): 0.511 ns** — Under the lethal 1.2ns cross-module deadline, I forcefully extracted an absolute margin of half a nanosecond.
* **Logic Level = 0** — The signal launches from **RX** with zero logic gate attrition, driving straight into the **TX** core relying purely on bare **Copper Traces**.
* **Worst Hold Slack (WHS): 0.009 ns** — A mere 9 picoseconds! This means our parsing logic has been relentlessly pinned at absolute zero distance to the physical pins, perfectly illustrating what "flying close to the ground" means in **HFT**.

#### Absolute Mastery over the Physical Layer
This period of extreme **Physical Layer** squeezing has allowed me to truly achieve absolute control over every metal routing trace and every internal **Switchbox**. The single-path, low-level foundation for handling the **HKEX OMD-C** protocol is now rock-solid.
<img width="1059" height="567" alt="Snipaste_2026-03-31_23-39-34" src="https://github.com/user-attachments/assets/675dee75-401b-4367-a812-52f95b177943" />

<img width="2057" height="996" alt="image" src="https://github.com/user-attachments/assets/13a22890-0a25-494c-ae6e-c1f6e36d687a" />

New Simulation
<img width="1102" height="544" alt="Snipaste_2026-04-11_02-34-34" src="https://github.com/user-attachments/assets/4b26d169-1d64-4091-823c-cb75858f31ca" />
<img width="1110" height="735" alt="Snipaste_2026-04-11_03-05-14" src="https://github.com/user-attachments/assets/c923b34a-d88c-4106-a2ae-c7aaa1ba1a93" />









