# Intel 8086 CPU Model VHDL Implementation

## Project Overview
This project consists of a simplified, synthesizable model of the Intel 8086 Central Processing Unit (CPU) developed using VHDL. The design is modular and hierarchical, specifically optimized for implementation and real-time validation on an FPGA platform using Xilinx Vivado.

---

## Architectural Specifications
The processor replicates the fundamental internal structure of the original 8086 by separating logic into two primary units that operate asynchronously:

### Bus Interface Unit (BIU)
* Manages all interactions with external memory and pre-processes instructions.
* Includes segment registers (CS, DS, SS, ES) and the Instruction Pointer (IP).
* Features a 3-word FIFO instruction queue to simulate the pre-fetch mechanism and decouple the BIU from the Execution Unit.
* Calculates 20-bit physical addresses using the formula: $Physical Address = Segment \times 16 + Offset$.

### Execution Unit (EU)
* Serves as the computational core, containing the Control Unit and the 16-bit Arithmetic Logic Unit (ALU).
* Includes a general-purpose register file (AX, BX, CX, DX) with support for dual-width access for 8-bit and 16-bit operations.
* Manages status flags including Sign (S), Overflow (O), Carry (C), and Zero (Z).

---

## Key Features
* **Standardized Instruction Set**: All instructions are constrained to a fixed length of 16 bits to simplify the fetch-decode cycle and eliminate the complexity of variable-length instructions.
* **Multi-Cycle Control**: A Finite State Machine (FSM) coordinates execution through six distinct stages, including Fetch, Decode, and Execute.
* **Memory Management**: Implements a segmented RAM structure divided into dedicated zones for code (256 words) and data (256 words).
* **Instruction Subset**: Supports approximately 20 instructions covering arithmetic (ADD, SUB, INC, DEC), logic (AND, OR, XOR, NOT, SHL, SHR), data transfer (MOV, LIR, LDR, STD), and flow control (JMP, JZ, JNZ).

---

## Hardware Validation
The design includes dedicated peripheral modules for real-time debugging and verification on an FPGA board:
* **Mono Pulse Generator (MPG)**: Enables single-step execution, allowing the user to advance the processor by one instruction at a time via physical buttons.
* **Seven Segment Display (SSD)**: Provides a multiplexed display to monitor the real-time contents of internal registers and the instruction queue.
* **LED Mapping**: Direct mapping of the status flags to onboard LEDs for immediate visual feedback on the results of arithmetic and logic operations.
