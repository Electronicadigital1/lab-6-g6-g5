module LCD1602_controller #(parameter NUM_COMMANDS = 4, 
                                      NUM_DATA_ALL = 32,  
                                      NUM_DATA_PERLINE = 16,
                                      DATA_BITS = 8,
                                      COUNT_MAX = 800000)(
    input clk,            
    input reset,          
    input ready_i,
    input [3:0] temp1,
    input [3:0] temp2,
    output reg rs,        
    output reg rw,
    output enable,    
    output reg [DATA_BITS-1:0] data
);

localparam IDLE              = 3'b000;
localparam CONFIG_CMD1       = 3'b001;
localparam WR_STATIC_TEXT_1L = 3'b010;
localparam CONFIG_CMD2       = 3'b011;
localparam WR_STATIC_TEXT_2L = 3'b100;
localparam WR_DIN_TEXT       = 3'b101;

// Sub-estados para WR_DIN_TEXT
localparam SetCursor1  = 3'd0;
localparam WR_DEC1     = 3'd1;
localparam WR_UNI1     = 3'd2;
localparam SetCursor2  = 3'd3;
localparam WR_DEC2     = 3'd4;
localparam WR_UNI2     = 3'd5;

reg [2:0] fsm_state;
reg [2:0] next_state;
reg clk_16ms;
reg [2:0] sel_dinamic;

localparam CLEAR_DISPLAY             = 8'h01;
localparam SHIFT_CURSOR_RIGHT        = 8'h06;
localparam DISPON_CURSOROFF          = 8'h0C;
localparam LINES2_MATRIX5x8_MODE8bit = 8'h38;
localparam START_2LINE               = 8'hC0;

reg [$clog2(COUNT_MAX)-1:0] clk_counter;
reg [$clog2(NUM_COMMANDS):0] command_counter;
reg [$clog2(NUM_DATA_PERLINE):0] data_counter;

reg [DATA_BITS-1:0] static_data_mem [0:NUM_DATA_ALL-1];
reg [DATA_BITS-1:0] config_mem [0:NUM_COMMANDS-1]; 

initial begin
    fsm_state       <= IDLE;
    command_counter <= 'b0;
    data_counter    <= 'b0;
    sel_dinamic     <= 'b0;
    rs              <= 1'b0;
    rw              <= 1'b0;
    data            <= 8'b0;
    clk_16ms        <= 1'b0;
    clk_counter     <= 'b0;
    $readmemh("data2.txt", static_data_mem);    
    config_mem[0] <= LINES2_MATRIX5x8_MODE8bit;
    config_mem[1] <= SHIFT_CURSOR_RIGHT;
    config_mem[2] <= DISPON_CURSOROFF;
    config_mem[3] <= CLEAR_DISPLAY;
end

// Divisor de frecuencia
always @(posedge clk) begin
    if (clk_counter == COUNT_MAX-1) begin
        clk_16ms    <= ~clk_16ms;
        clk_counter <= 'b0;
    end else begin
        clk_counter <= clk_counter + 1;
    end
end

// Bloque 1: registro de estado
always @(posedge clk_16ms) begin
    if (reset == 0)
        fsm_state <= IDLE;
    else
        fsm_state <= next_state;
end

// Bloque 2: lógica de próximo estado
always @(*) begin
    case(fsm_state)
        IDLE:              next_state = (ready_i) ? CONFIG_CMD1 : IDLE;
        CONFIG_CMD1:       next_state = (command_counter == NUM_COMMANDS) ? WR_STATIC_TEXT_1L : CONFIG_CMD1;
        WR_STATIC_TEXT_1L: next_state = (data_counter == NUM_DATA_PERLINE) ? CONFIG_CMD2 : WR_STATIC_TEXT_1L;
        CONFIG_CMD2:       next_state = WR_STATIC_TEXT_2L;
        WR_STATIC_TEXT_2L: next_state = (data_counter == NUM_DATA_PERLINE) ? WR_DIN_TEXT : WR_STATIC_TEXT_2L;
        WR_DIN_TEXT:       next_state = WR_DIN_TEXT; // bucle infinito
        default:           next_state = IDLE;
    endcase
end

// Bloque 3: datapath
always @(posedge clk_16ms) begin
    if (reset == 0) begin
        command_counter <= 'b0;
        data_counter    <= 'b0;
        sel_dinamic     <= 'b0;
        data            <= 'b0;
        $readmemh("data2.txt", static_data_mem);
    end else begin
        case (next_state)
            IDLE: begin
                command_counter <= 'b0;
                data_counter    <= 'b0;
                sel_dinamic     <= 'b0;
                rs              <= 1'b0;
                data            <= 'b0;
            end
            CONFIG_CMD1: begin
                rs              <= 1'b0;
                command_counter <= command_counter + 1;
                data            <= config_mem[command_counter];
            end
            WR_STATIC_TEXT_1L: begin
                rs           <= 1'b1;
                data_counter <= data_counter + 1;
                data         <= static_data_mem[data_counter];
            end
            CONFIG_CMD2: begin
                data_counter <= 'b0;
                rs           <= 1'b0;
                data         <= START_2LINE;
            end
            WR_STATIC_TEXT_2L: begin
                rs           <= 1'b1;
                data_counter <= data_counter + 1;
                data         <= static_data_mem[NUM_DATA_PERLINE + data_counter];
                sel_dinamic  <= 'b0;
            end
            WR_DIN_TEXT: begin
                case (sel_dinamic)
                    SetCursor1: begin
                        rs          <= 1'b0;
                        data        <= 8'h80 + 8'h0B; // línea 1, posición 11
                        sel_dinamic <= WR_DEC1;
                    end
                    WR_DEC1: begin
                        rs          <= 1'b1;
                        data        <= (temp1 / 10) + 8'h30;
                        sel_dinamic <= WR_UNI1;
                    end
                    WR_UNI1: begin
                        rs          <= 1'b1;
                        data        <= (temp1 % 10) + 8'h30;
                        sel_dinamic <= SetCursor2;
                    end
                    SetCursor2: begin
                        rs          <= 1'b0;
                        data        <= 8'hC0 + 8'h0B; // línea 2, posición 11
                        sel_dinamic <= WR_DEC2;
                    end
                    WR_DEC2: begin
                        rs          <= 1'b1;
                        data        <= (temp2 / 10) + 8'h30;
                        sel_dinamic <= WR_UNI2;
                    end
                    WR_UNI2: begin
                        rs          <= 1'b1;
                        data        <= (temp2 % 10) + 8'h30;
                        sel_dinamic <= SetCursor1; // vuelve al inicio
                    end
                endcase
            end
        endcase
    end
end

assign enable = clk_16ms;

endmodule