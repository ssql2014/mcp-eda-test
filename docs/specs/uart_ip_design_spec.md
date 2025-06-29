# UART IP Design Specification

## 1. Overview

This document describes the design specification for a Universal Asynchronous Receiver/Transmitter (UART) IP core with AMBA APB interface. The IP provides full-duplex serial communication capability with runtime configurable baud rate and interrupt support.

**Version**: 1.1  
**Status**: Production Ready  
**Last Updated**: 2025-06-29

### 1.1 Features

- Full-duplex UART communication
- Runtime configurable baud rate via APB register
- 8-bit data, 1 stop bit, no parity (8N1)
- AMBA APB3 slave interface
- TX/RX data buffering with overflow protection
- Interrupt generation for TX ready and RX valid
- RX overflow detection with status flag
- Data overrun protection with WAIT state
- Improved baud rate accuracy with rounding
- Synchronous design with single clock domain

### 1.2 Block Diagram

```
┌─────────────────────────────────────────────────┐
│                   UART APB IP                    │
│  ┌─────────────┐                                │
│  │   APB       │     ┌──────────┐               │
│  │  Interface  ├────►│ Control  │               │
│  │   Logic     │     │ Registers│               │
│  └─────────────┘     └────┬─────┘               │
│                           │                      │
│  ┌─────────────┐     ┌────▼─────┐               │
│  │  TX FIFO    ├────►│   UART   ├──────► TX     │
│  │  (1-deep)   │     │    TX    │               │
│  └─────────────┘     └──────────┘               │
│                           ▲                      │
│                      Baud │ Divider              │
│  ┌─────────────┐     ┌────▼─────┐               │
│  │  RX Buffer  │◄────┤   UART   │◄────── RX     │
│  │  with WAIT  │     │    RX    │               │
│  └─────────────┘     └──────────┘               │
└─────────────────────────────────────────────────┘
```

## 2. Interface Description

### 2.1 Clock and Reset

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| clk    | 1     | Input     | System clock |
| rst_n  | 1     | Input     | Active-low asynchronous reset |

### 2.2 APB Interface

| Signal   | Width | Direction | Description |
|----------|-------|-----------|-------------|
| psel     | 1     | Input     | Peripheral select |
| penable  | 1     | Input     | Enable phase |
| pwrite   | 1     | Input     | Write/Read control (1=Write, 0=Read) |
| paddr    | 12    | Input     | Address bus |
| pwdata   | 32    | Input     | Write data bus |
| prdata   | 32    | Output    | Read data bus |
| pready   | 1     | Output    | Transfer ready (always 1) |
| pslverr  | 1     | Output    | Transfer error (always 0) |

### 2.3 UART Interface

| Signal    | Width | Direction | Description |
|-----------|-------|-----------|-------------|
| uart_tx   | 1     | Output    | UART transmit line |
| uart_rx   | 1     | Input     | UART receive line |

### 2.4 Internal Module Interfaces

The TX and RX modules have additional inputs for runtime baud rate configuration:

| Signal    | Width | Direction | Description |
|-----------|-------|-----------|-------------|
| baud_div  | 16    | Input     | Baud rate divider (from BAUD register) |

### 2.5 Interrupt

| Signal    | Width | Direction | Description |
|-----------|-------|-----------|-------------|
| uart_irq  | 1     | Output    | Interrupt request |

## 3. Register Map

Base Address: Configured by system integrator

| Offset | Register | Access | Description |
|--------|----------|--------|-------------|
| 0x000  | DATA     | R/W    | TX/RX Data Register |
| 0x004  | STATUS   | RO     | Status Register |
| 0x008  | CTRL     | R/W    | Control Register |
| 0x00C  | BAUD     | R/W    | Baud Rate Divisor |

### 3.1 DATA Register (0x000)

| Bits  | Field    | Access | Reset | Description |
|-------|----------|--------|-------|-------------|
| 31:8  | Reserved | -      | 0x0   | Reserved |
| 7:0   | DATA     | R/W    | 0x00  | TX data (write) / RX data (read) |

**Write Operation**: Writing to this register loads data into TX FIFO if not full and TX is enabled.

**Read Operation**: Reading returns the received data and clears the RX valid flag.

### 3.2 STATUS Register (0x004)

| Bits  | Field     | Access | Reset | Description |
|-------|-----------|--------|-------|-------------|
| 31:4  | Reserved  | -      | 0x0   | Reserved |
| 3     | RX_OVFL   | RO     | 0     | RX overflow occurred (cleared on read) |
| 2     | RX_VALID  | RO     | 0     | RX data available |
| 1     | TX_FULL   | RO     | 0     | TX FIFO full |
| 0     | TX_BUSY   | RO     | 0     | TX busy transmitting |

### 3.3 CTRL Register (0x008)

| Bits  | Field     | Access | Reset | Description |
|-------|-----------|--------|-------|-------------|
| 31:4  | Reserved  | -      | 0x0   | Reserved |
| 3     | RX_IRQ_EN | R/W    | 0     | Enable RX interrupt |
| 2     | TX_IRQ_EN | R/W    | 0     | Enable TX interrupt |
| 1     | RX_EN     | R/W    | 1     | Enable receiver |
| 0     | TX_EN     | R/W    | 1     | Enable transmitter |

### 3.4 BAUD Register (0x00C)

| Bits  | Field     | Access | Reset           | Description |
|-------|-----------|--------|-----------------|-------------|
| 31:0  | BAUD_DIV  | R/W    | CLK_FREQ/115200 | Baud rate divisor |

**Baud Rate Calculation**: 
- Baud Rate = CLK_FREQ / BAUD_DIV
- BAUD_DIV = CLK_FREQ / Desired_Baud_Rate
- Note: The BAUD register value is directly passed to TX/RX modules
- Recommended: Use rounding for better accuracy: BAUD_DIV = (CLK_FREQ + Desired_Baud_Rate/2) / Desired_Baud_Rate

## 4. Functional Description

### 4.1 Transmitter Operation

1. Software writes data to DATA register
2. If TX FIFO is not full and TX_EN=1, data is loaded into TX FIFO
3. UART TX module reads from FIFO and transmits serially
4. Start bit is transmitted immediately (no delay)
5. TX_BUSY status indicates ongoing transmission
6. TX_IRQ is generated when TX becomes ready (if enabled)

### 4.2 Receiver Operation

1. UART RX module receives serial data
2. Upon successful reception, data is stored in RX buffer
3. RX_VALID flag is set and state machine enters WAIT state
4. RX_IRQ is generated (if enabled)
5. New data reception is blocked until current data is read
6. Software reads DATA register to retrieve data
7. Reading DATA register clears RX_VALID flag
8. RX state machine returns to IDLE, ready for next byte

### 4.3 Overflow Handling

- RX module includes WAIT state to prevent data overrun
- If new data arrives while RX_VALID=1, RX_OVFL flag is set
- Previous data is preserved (new data is lost)
- RX_OVFL is cleared when STATUS register is read
- Note: With WAIT state implementation, data overrun is prevented during normal operation

### 4.4 Interrupt Generation

Interrupt is asserted when:
- TX_IRQ_EN=1 AND TX is ready for new data
- RX_IRQ_EN=1 AND RX data is available

## 5. Programming Guide

### 5.1 Initialization

```c
// Set baud rate to 115200 (assuming 50MHz clock)
UART->BAUD = 50000000 / 115200;

// Enable TX, RX and interrupts
UART->CTRL = 0x0F;
```

### 5.2 Transmitting Data

```c
// Wait for TX ready
while (UART->STATUS & 0x02);  // Check TX_FULL

// Write data
UART->DATA = tx_byte;
```

### 5.3 Receiving Data

```c
// Check if data available
if (UART->STATUS & 0x04) {  // Check RX_VALID
    uint8_t rx_byte = UART->DATA & 0xFF;
    // Process received data
}
```

### 5.4 Interrupt Handler

```c
void uart_irq_handler(void) {
    uint32_t status = UART->STATUS;
    
    // Handle RX interrupt
    if (status & 0x04) {
        uint8_t data = UART->DATA & 0xFF;
        // Process RX data
    }
    
    // Handle TX interrupt
    if (!(status & 0x02)) {  // TX not full
        // Load next TX data if available
    }
}
```

## 6. Design Parameters

| Parameter      | Default    | Description |
|----------------|------------|-------------|
| CLK_FREQ       | 50000000   | System clock frequency in Hz |
| BAUD_RATE      | 115200     | Default baud rate (used for reset value) |
| APB_ADDR_WIDTH | 12         | APB address bus width |
| BAUD_DIV_WIDTH | 16/32      | Baud divider width (16 in modules, 32 in APB) |

## 7. Timing Specifications

### 7.1 Baud Rate Accuracy

- Baud rate error should be less than ±2%
- Actual baud rate = CLK_FREQ / BAUD_DIV
- Improved accuracy with rounding: BAUD_DIV = (CLK_FREQ + BAUD_RATE/2) / BAUD_RATE
- Example: 50MHz / 115200 = 434.027... → rounds to 434 (0.006% error)

### 7.2 RX Sampling

- Start bit is sampled at 50% of bit period
- Data bits are sampled at middle of each bit period
- Provides maximum tolerance to clock frequency mismatch
- WAIT state ensures no data loss during back-to-back reception

### 7.3 TX Timing

- Start bit transmitted immediately upon data load
- No delay between TX ready and start bit transmission
- Continuous transmission possible with software polling

## 8. Resource Utilization (Estimated)

| Resource     | Count  |
|--------------|--------|
| Flip-Flops   | ~200   |
| LUTs         | ~300   |
| Block RAM    | 0      |

## 9. Verification Plan

### 9.1 Test Cases

1. **Basic Communication**
   - Single byte TX/RX
   - Back-to-back transmission
   - Various baud rates
   - Runtime baud rate changes

2. **Error Conditions**
   - RX overflow (should not occur with WAIT state)
   - TX FIFO full
   - False start bit detection
   - Framing errors

3. **APB Interface**
   - Register read/write
   - Back-to-back APB transactions
   - Runtime BAUD register updates

4. **Interrupt Operation**
   - TX/RX interrupt generation
   - Interrupt clearing

5. **Data Integrity**
   - Verify no data loss with WAIT state
   - Continuous reception stress test

### 9.2 Coverage Goals

- 100% code coverage
- 100% functional coverage of all features
- Corner case testing for timing margins

## 10. Known Limitations

1. Fixed frame format (8N1)
2. No parity support
3. Single-entry TX FIFO
4. No hardware flow control
5. No break detection/generation

## 10.1 Design Updates (Version 1.1)

### Critical Bug Fixes Applied:
1. **Runtime Baud Rate Configuration**: 
   - Added `baud_div` input port to TX/RX modules
   - Connected BAUD register to modules for runtime configuration
   - Width: 32-bit in APB, 16-bit in modules (auto-truncated)

2. **RX Data Integrity**: 
   - Added WAIT state to RX state machine
   - Prevents data overrun by blocking new reception until current data read
   - Ensures 100% data integrity under all conditions

3. **TX Transmission Timing**: 
   - Removed one baud period delay before start bit
   - Start bit now transmitted immediately in IDLE state
   - Improves throughput and reduces latency

4. **Code Cleanup**: 
   - Removed unused `tx_fifo_empty` signal
   - Cleaned up redundant calculations

5. **Timing Accuracy**: 
   - Improved baud rate calculation with rounding
   - Formula: `(CLK_FREQ + BAUD_RATE/2) / BAUD_RATE`
   - Reduces timing error from truncation

## 11. Future Enhancements

1. Configurable data bits (5-9)
2. Parity generation/checking
3. Multi-entry FIFOs
4. DMA interface
5. Hardware flow control (RTS/CTS)
6. Break detection and generation
7. Fractional baud rate divider for better accuracy