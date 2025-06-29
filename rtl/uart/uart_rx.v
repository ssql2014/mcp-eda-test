module uart_rx #(
    parameter CLK_FREQ = 50000000,  // Clock frequency in Hz
    parameter BAUD_RATE = 115200,   // Default baud rate
    parameter BAUD_DIV_WIDTH = 16   // Width of baud divider
)(
    input wire clk,
    input wire rst_n,
    
    // UART input
    input wire rx,
    
    // Data interface
    output reg [7:0] rx_data,
    output reg rx_valid,
    input wire rx_ready,
    
    // Baud rate control
    input wire [BAUD_DIV_WIDTH-1:0] baud_div
);

    // Baud rate generation
    // Use rounding for better accuracy
    localparam DEFAULT_BAUD_DIV = (CLK_FREQ + BAUD_RATE / 2) / BAUD_RATE;
    wire [BAUD_DIV_WIDTH-1:0] half_baud_div = baud_div >> 1;
    
    // State machine states
    localparam IDLE  = 3'b000;
    localparam START = 3'b001;
    localparam DATA  = 3'b010;
    localparam STOP  = 3'b011;
    localparam WAIT  = 3'b100;  // Wait for rx_ready before accepting new data
    
    // Internal registers
    reg [2:0] state;
    reg [BAUD_DIV_WIDTH-1:0] baud_cnt;
    reg [2:0] bit_cnt;
    reg [7:0] rx_data_shift;
    reg rx_sync1, rx_sync2;
    
    // Synchronize RX input to avoid metastability
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end
    
    // Receiver state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rx_data <= 0;
            rx_valid <= 1'b0;
            bit_cnt <= 0;
            baud_cnt <= 0;
            rx_data_shift <= 0;
        end else begin
            // Clear valid when data is accepted
            if (rx_valid && rx_ready) begin
                rx_valid <= 1'b0;
            end
            
            case (state)
                IDLE: begin
                    baud_cnt <= 0;
                    bit_cnt <= 0;
                    if (!rx_sync2) begin  // Start bit detected
                        state <= START;
                    end
                end
                
                START: begin
                    if (baud_cnt == half_baud_div - 1) begin
                        // Sample at middle of start bit
                        if (!rx_sync2) begin
                            // Valid start bit
                            baud_cnt <= 0;
                            state <= DATA;
                        end else begin
                            // False start bit
                            state <= IDLE;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end
                
                DATA: begin
                    if (baud_cnt == baud_div - 1) begin
                        // Sample at middle of data bit
                        rx_data_shift <= {rx_sync2, rx_data_shift[7:1]};
                        baud_cnt <= 0;
                        
                        if (bit_cnt == 7) begin
                            state <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end
                
                STOP: begin
                    if (baud_cnt == baud_div - 1) begin
                        // Check stop bit
                        if (rx_sync2) begin
                            // Valid stop bit
                            rx_data <= rx_data_shift;
                            rx_valid <= 1'b1;
                            state <= WAIT;  // Wait for data to be read
                        end else begin
                            // Framing error - discard data
                            state <= IDLE;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end
                
                WAIT: begin
                    // Wait until data is read before accepting new data
                    if (!rx_valid) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule