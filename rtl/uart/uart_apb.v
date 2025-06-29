module uart_apb #(
    parameter CLK_FREQ = 50000000,  // Clock frequency in Hz
    parameter BAUD_RATE = 115200,   // Default baud rate
    parameter APB_ADDR_WIDTH = 12   // APB address width
)(
    // Clock and reset
    input wire clk,
    input wire rst_n,
    
    // APB interface
    input wire psel,
    input wire penable,
    input wire pwrite,
    input wire [APB_ADDR_WIDTH-1:0] paddr,
    input wire [31:0] pwdata,
    output reg [31:0] prdata,
    output wire pready,
    output wire pslverr,
    
    // UART interface
    output wire uart_tx,
    input wire uart_rx,
    
    // Interrupt
    output wire uart_irq
);

    // Register addresses
    localparam ADDR_DATA    = 12'h000;  // TX/RX data register
    localparam ADDR_STATUS  = 12'h004;  // Status register
    localparam ADDR_CTRL    = 12'h008;  // Control register
    localparam ADDR_BAUD    = 12'h00C;  // Baud rate register
    
    // Control register bits
    localparam CTRL_TX_EN   = 0;
    localparam CTRL_RX_EN   = 1;
    localparam CTRL_TX_IRQ  = 2;
    localparam CTRL_RX_IRQ  = 3;
    
    // Status register bits
    localparam STAT_TX_BUSY = 0;
    localparam STAT_TX_FULL = 1;
    localparam STAT_RX_VALID = 2;
    localparam STAT_RX_OVFL = 3;
    
    // Internal registers
    reg [31:0] ctrl_reg;
    reg [31:0] baud_reg;
    reg rx_overflow;
    
    // TX interface signals
    wire [7:0] tx_data;
    wire tx_valid;
    wire tx_ready;
    
    // RX interface signals
    wire [7:0] rx_data;
    wire rx_valid;
    reg rx_ready;
    
    // TX FIFO signals
    reg tx_fifo_wr;
    reg [7:0] tx_fifo_data;
    wire tx_fifo_full;
    
    // RX data holding register
    reg [7:0] rx_data_reg;
    reg rx_data_valid;
    
    // APB response
    assign pready = 1'b1;  // Always ready
    assign pslverr = 1'b0; // No errors
    
    // Interrupt generation
    assign uart_irq = (ctrl_reg[CTRL_TX_IRQ] & tx_ready) |
                      (ctrl_reg[CTRL_RX_IRQ] & rx_data_valid);
    
    // APB write interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg <= 32'h00000003; // Enable TX and RX by default
            baud_reg <= CLK_FREQ / BAUD_RATE;
            tx_fifo_wr <= 1'b0;
            tx_fifo_data <= 8'h00;
        end else begin
            tx_fifo_wr <= 1'b0;
            
            if (psel && penable && pwrite) begin
                case (paddr)
                    ADDR_DATA: begin
                        if (!tx_fifo_full && ctrl_reg[CTRL_TX_EN]) begin
                            tx_fifo_data <= pwdata[7:0];
                            tx_fifo_wr <= 1'b1;
                        end
                    end
                    ADDR_CTRL: begin
                        ctrl_reg <= pwdata;
                    end
                    ADDR_BAUD: begin
                        baud_reg <= pwdata;
                    end
                endcase
            end
        end
    end
    
    // APB read interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prdata <= 32'h00000000;
        end else begin
            if (psel && !pwrite) begin
                case (paddr)
                    ADDR_DATA: begin
                        prdata <= {24'h000000, rx_data_reg};
                    end
                    ADDR_STATUS: begin
                        prdata <= {28'h0000000,
                                   rx_overflow,
                                   rx_data_valid,
                                   tx_fifo_full,
                                   !tx_ready};
                    end
                    ADDR_CTRL: begin
                        prdata <= ctrl_reg;
                    end
                    ADDR_BAUD: begin
                        prdata <= baud_reg;
                    end
                    default: begin
                        prdata <= 32'h00000000;
                    end
                endcase
            end
        end
    end
    
    // RX data handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data_reg <= 8'h00;
            rx_data_valid <= 1'b0;
            rx_overflow <= 1'b0;
            rx_ready <= 1'b0;
        end else begin
            rx_ready <= 1'b0;
            
            // Clear on read
            if (psel && !pwrite && (paddr == ADDR_DATA) && rx_data_valid) begin
                rx_data_valid <= 1'b0;
            end
            
            // Store new RX data
            if (rx_valid && ctrl_reg[CTRL_RX_EN]) begin
                if (rx_data_valid) begin
                    rx_overflow <= 1'b1;
                end else begin
                    rx_data_reg <= rx_data;
                    rx_data_valid <= 1'b1;
                    rx_ready <= 1'b1;
                end
            end
            
            // Clear overflow on status read
            if (psel && !pwrite && (paddr == ADDR_STATUS)) begin
                rx_overflow <= 1'b0;
            end
        end
    end
    
    // Simple TX FIFO (1 deep for now)
    reg tx_fifo_valid;
    reg [7:0] tx_fifo_reg;
    
    assign tx_fifo_full = tx_fifo_valid;
    assign tx_data = tx_fifo_reg;
    assign tx_valid = tx_fifo_valid & ctrl_reg[CTRL_TX_EN];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_fifo_valid <= 1'b0;
            tx_fifo_reg <= 8'h00;
        end else begin
            if (tx_fifo_wr && !tx_fifo_full) begin
                tx_fifo_reg <= tx_fifo_data;
                tx_fifo_valid <= 1'b1;
            end else if (tx_valid && tx_ready) begin
                tx_fifo_valid <= 1'b0;
            end
        end
    end
    
    // UART TX instance
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .BAUD_DIV_WIDTH(32)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),
        .baud_div(baud_reg),
        .tx(uart_tx)
    );
    
    // UART RX instance
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .BAUD_DIV_WIDTH(32)
    ) u_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_ready(rx_ready),
        .baud_div(baud_reg)
    );

endmodule