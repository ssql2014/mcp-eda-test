module uart_tx #(
    parameter CLK_FREQ = 50000000,  // Clock frequency in Hz
    parameter BAUD_RATE = 115200,   // Default baud rate
    parameter BAUD_DIV_WIDTH = 16   // Width of baud divider
)(
    input wire clk,
    input wire rst_n,
    
    // Data interface
    input wire [7:0] tx_data,
    input wire tx_valid,
    output reg tx_ready,
    
    // Baud rate control
    input wire [BAUD_DIV_WIDTH-1:0] baud_div,
    
    // UART output
    output reg tx
);

    // Baud rate generation
    // Use rounding for better accuracy
    localparam DEFAULT_BAUD_DIV = (CLK_FREQ + BAUD_RATE / 2) / BAUD_RATE;
    
    // State machine states
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;
    
    // Internal registers
    reg [1:0] state;
    reg [BAUD_DIV_WIDTH-1:0] baud_cnt;
    reg [2:0] bit_cnt;
    reg [7:0] tx_data_reg;
    reg baud_tick;
    
    // Baud rate generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= 0;
            baud_tick <= 1'b0;
        end else begin
            if (state != IDLE) begin
                if (baud_cnt == baud_div - 1) begin
                    baud_cnt <= 0;
                    baud_tick <= 1'b1;
                end else begin
                    baud_cnt <= baud_cnt + 1;
                    baud_tick <= 1'b0;
                end
            end else begin
                baud_cnt <= 0;
                baud_tick <= 1'b0;
            end
        end
    end
    
    // Transmitter state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx <= 1'b1;
            tx_ready <= 1'b1;
            bit_cnt <= 0;
            tx_data_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    tx_ready <= 1'b1;
                    if (tx_valid) begin
                        tx_data_reg <= tx_data;
                        tx_ready <= 1'b0;
                        state <= START;
                        // Start bit transmitted immediately
                        tx <= 1'b0;
                    end
                end
                
                START: begin
                    tx <= 1'b0;  // Start bit
                    if (baud_tick) begin
                        state <= DATA;
                        bit_cnt <= 0;
                    end
                end
                
                DATA: begin
                    if (baud_tick) begin
                        tx <= tx_data_reg[bit_cnt];
                        if (bit_cnt == 7) begin
                            state <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end
                
                STOP: begin
                    if (baud_tick) begin
                        tx <= 1'b1;  // Stop bit
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule