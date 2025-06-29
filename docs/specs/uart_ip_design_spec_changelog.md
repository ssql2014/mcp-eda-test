# UART IP Design Specification - Change Log

## Version 1.1 - 2025-06-29

### Major Changes

1. **Runtime Baud Rate Configuration**
   - Added `baud_div` input ports to TX and RX modules
   - Connected BAUD register to modules for dynamic configuration
   - Updated interface descriptions to document new ports

2. **RX Data Integrity Enhancement**
   - Added WAIT state to RX state machine
   - Prevents data overrun by design
   - Updated functional description to reflect new behavior

3. **TX Performance Improvement**
   - Removed transmission start delay
   - Start bit transmitted immediately
   - Updated timing specifications

4. **Documentation Updates**
   - Added version information (v1.1)
   - Updated block diagram to show baud divider connection
   - Enhanced baud rate calculation section with rounding formula
   - Added TX timing section
   - Updated verification plan for new features
   - Added design updates section (10.1)

### Bug Fixes

1. Fixed baud rate register connection issue
2. Eliminated RX data loss vulnerability
3. Removed TX start bit delay
4. Cleaned up unused signals

### Interface Changes

- TX Module: Added `baud_div[15:0]` input
- RX Module: Added `baud_div[15:0]` input
- No changes to external interfaces (backward compatible)

### Known Issues Resolved

- Runtime baud rate configuration now functional
- RX data overrun eliminated
- TX transmission delay removed

## Version 1.0 - Initial Release

- Basic UART functionality
- APB interface
- Fixed baud rate only
- Known issues with data overrun and configuration