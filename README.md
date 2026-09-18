# Zigzag RLE Compression

*Wadhwani Electronics Laboratory, Department of Electrical Engineering, IIT Bombay*

A hardware implementation of image-block compression using **zigzag reordering + run-length encoding (RLE)**, written in VHDL and targeting an Intel/Altera MAX10 FPGA (Quartus Prime + ModelSim).

## Overview

Run-Length Encoding compresses data by replacing consecutive repeated symbols with a `(count, symbol)` pair. Applied directly, row-by-row, RLE performs poorly on 2D data (e.g. image blocks) because runs get broken at row boundaries. This project first reorders an 8x8 block of symbols into a **zigzag traversal order**, keeping spatially adjacent (and therefore likely similar) values next to each other in the stream, before applying RLE. This produces materially better compression on structured, block-like data than naive row-major RLE.

```
AAAAABBCCCC  -->  (5,A) (2,B) (4,C)
```

For a 64-symbol, 8-bit block: best case compresses 512 bits down to 16 bits; worst case (no repetition) expands to 1024 bits.

Each component (encoder, decoder) lives in exactly one place; the top-level project references those same source files rather than keeping its own copies, so there is a single source of truth per module.

## Repository structure

```
encoder/                  RLE Encoder - standalone simulation project
  RLE_encoder.vhd           - matrix fill, zigzag traversal, RLE compression
  Testbench.vhdl            - drives a sample matrix and checks the compressed output
  RLE_encoder.qpf/.qsf

decoder/                  RLE Decoder - standalone simulation project
  RLE_decoder.vhd           - RLE expansion, zigzag-addressed matrix reconstruction
  Testbench.vhdl            - drives a compressed stream and checks the rebuilt matrix
  RLE_decoder.qpf/.qsf

top_level/                Integration + hardware implementation
  RLE.vhd                   - wires the encoder straight into the decoder
  Toplevel.vhdl             - hardware wrapper (clock/switch/LED pin mapping)
  Testbench.vhdl            - full round-trip simulation testbench (pass/fail check)
  SDC1.sdc                  - timing constraints for synthesis
  RLE.qpf/.qsf              - references ../encoder/RLE_encoder.vhd and ../decoder/RLE_decoder.vhd
```

`encoder/` and `decoder/` are independent Quartus projects for simulating each module in isolation. `top_level/` is the integration project: its `.qsf` pulls in the encoder and decoder source files directly from their own folders (no duplicated copies) and adds `RLE.vhd` and `Toplevel.vhdl` on top.

## Design

### RLE Encoder (`RLE_encoder`)

| Port             | Direction | Width | Description                                   |
|------------------|-----------|-------|------------------------------------------------|
| `clk`, `reset`   | in        | 1     | Clock and synchronous reset                    |
| `start`          | in        | 1     | Begin loading the 8x8 input matrix             |
| `data_in`        | in        | 8     | Incoming symbol, one per clock                 |
| `data_out`       | out       | 16    | Compressed `(count, symbol)` pair stream       |
| `done`           | out       | 1     | Asserted once the RLE buffer is ready          |
| `reduced_length` | out       | 8     | Number of valid `(count, symbol)` entries      |

Fills a 64-entry, 8-bit matrix from `data_in`, traverses it in zigzag order, and groups repeated symbols into `(count, symbol)` pairs written to a 64-entry RLE buffer.

### RLE Decoder (`RLE_decoder`)

| Port             | Direction | Width | Description                                    |
|------------------|-----------|-------|-------------------------------------------------|
| `clk`, `reset`   | in        | 1     | Clock and synchronous reset                     |
| `data_in`        | in        | 16    | Compressed `(count, symbol)` pair stream        |
| `start`          | in        | 1     | Begin reading `reduced_length` pairs            |
| `reduced_length` | in        | 8     | Number of valid pairs to read                   |
| `data_out`       | out       | 8     | Reconstructed symbol, output in row-major order |
| `done`           | out       | 1     | Asserted once the 8x8 matrix is fully rebuilt   |

Reads exactly `reduced_length` pairs, expands each `(count, symbol)` back into the matrix at its zigzag position, then streams the reconstructed matrix out in normal row-major order.

### Integration (`RLE`) and hardware top level (`Toplevel`)

`RLE` instantiates the encoder and decoder back-to-back (decoder starts as soon as the encoder finishes), so a matrix fed in is compressed and immediately decompressed for a round-trip correctness check. `Toplevel` wraps `RLE` for hardware deployment:

- `clk` -> on-board 50 MHz clock
- `reset` -> switch 8
- pass / fail flags -> LEDs

## Simulation

Each project ships with a `Testbench.vhdl` that drives sample data through the design and checks the result, raising a pass/fail flag. Run it in ModelSim (via Quartus's built-in NativeLink simulation) from the corresponding project directory:

- `encoder/` - encoder in isolation
- `decoder/` - decoder in isolation
- `top_level/` - full compress -> decompress round trip

## Building for hardware

1. Open `top_level/RLE.qpf` in Quartus Prime.
2. Confirm the project's source files: `Toplevel.vhdl`, `RLE.vhd`, `Testbench.vhdl`, plus `../encoder/RLE_encoder.vhd` and `../decoder/RLE_decoder.vhd` (referenced directly, not copied), and `SDC1.sdc` for timing constraints.
3. Set `Toplevel` as the top-level entity.
4. Assign pins as described above (clock, reset switch, pass/fail LEDs) via the Pin Planner.
5. Compile and program the board.
