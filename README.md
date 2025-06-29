# MCP EDA Test - UART IP with APB Interface

A production-ready UART IP core with AMBA APB interface, developed as a test project for MCP (Model Context Protocol) EDA tools.

## Features

- **Full-duplex UART communication** with 8N1 frame format
- **Runtime configurable baud rate** via APB register
- **AMBA APB3 slave interface** with 4 memory-mapped registers
- **Data integrity protection** with RX WAIT state
- **Interrupt support** for TX ready and RX valid events
- **Overflow detection** with status flags
- **Synchronous design** with single clock domain
- **Parameterized design** for flexibility

## Repository Structure

```
mcp-eda-test/
├── rtl/uart/              # RTL source files
│   ├── uart_tx.v         # UART transmitter module
│   ├── uart_rx.v         # UART receiver module
│   └── uart_apb.v        # APB wrapper with registers
├── docs/specs/           # Design documentation
│   ├── uart_ip_design_spec.md       # Complete design specification
│   └── uart_ip_design_spec_changelog.md  # Version history
└── logs/reviews/         # Code review reports
    ├── uart_ip_code_review.md      # Initial code review
    ├── uart_ip_gemini_review.md    # Gemini AI review
    └── uart_ip_post_fix_review.md  # Post-fix verification
```

## Quick Start

### Integration Example

```verilog
uart_apb #(
    .CLK_FREQ(50000000),    // 50MHz system clock
    .BAUD_RATE(115200),     // Default baud rate
    .APB_ADDR_WIDTH(12)
) u_uart (
    // Clock and reset
    .clk(clk),
    .rst_n(rst_n),
    
    // APB interface
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .paddr(paddr),
    .pwdata(pwdata),
    .prdata(prdata),
    .pready(pready),
    .pslverr(pslverr),
    
    // UART signals
    .uart_tx(uart_tx),
    .uart_rx(uart_rx),
    
    // Interrupt
    .uart_irq(uart_irq)
);
```

### Register Map

| Address | Register | Description |
|---------|----------|-------------|
| 0x000   | DATA     | TX/RX Data Register |
| 0x004   | STATUS   | Status Register (RO) |
| 0x008   | CTRL     | Control Register |
| 0x00C   | BAUD     | Baud Rate Divisor |

## Version History

### v1.1 (2025-06-29) - Current
- Fixed runtime baud rate configuration
- Eliminated RX data loss with WAIT state
- Removed TX transmission delay
- Improved baud rate accuracy
- Code cleanup and optimization

### v1.0 - Initial Release
- Basic UART functionality
- APB interface implementation

## Development Tools Used

This project was developed using MCP-enabled EDA tools:
- **Verible** - SystemVerilog linting and formatting
- **Gemini AI** - Code review and analysis
- **MCP Zen Tools** - Comprehensive development assistance

## Code Quality

- ✅ All modules pass Verible linting
- ✅ Critical bugs identified and fixed
- ✅ Comprehensive code reviews completed
- ✅ Production-ready for basic applications

## Known Limitations

1. Fixed frame format (8N1 only)
2. No parity bit support
3. Single-entry TX FIFO
4. No hardware flow control (RTS/CTS)
5. No break detection/generation

## Future Enhancements

- Configurable data bits (5-9)
- Parity generation and checking
- Deeper TX/RX FIFOs
- Hardware flow control
- DMA interface support

## License

This project is provided as-is for educational and testing purposes.

## Acknowledgments

Developed as a demonstration of MCP (Model Context Protocol) capabilities for EDA tool integration.