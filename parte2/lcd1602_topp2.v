module lcd1602_topp2 (
    input clk,          // P23 - 50 MHz
    input reset,        // P90 - botón K2 (activo en bajo)
    input [3:0] temp1,  // P1=P58, P2=P59, P3=P60, P4=P61 - DIP switches 1-4
    input [3:0] temp2,  // P1=P64, P2=P65, P3=P67, P4=P68 - DIP switches 5-8
    output rs,          // P85
    output rw,          // P99
    output enable,      // P100
    output [7:0] data   // D0=P101, D1=P103, D2=P104, D3=P105,
                        // D4=P110, D5=P111, D6=P112, D7=P113
);

    wire [3:0] temp1_w;
    wire [3:0] temp2_w;

    // DIP switches son activo en bajo, se invierten
    assign temp1_w = ~temp1;
    assign temp2_w = ~temp2;

    LCD1602_controller #(
        .NUM_COMMANDS    (4),
        .NUM_DATA_ALL    (32),
        .NUM_DATA_PERLINE(16),
        .DATA_BITS       (8),
        .COUNT_MAX       (800000)
    ) u_lcd (
        .clk     (clk),
        .reset   (reset),
        .ready_i (1'b1),
        .temp1   (temp1_w),
        .temp2   (temp2_w),
        .rs      (rs),
        .rw      (rw),
        .enable  (enable),
        .data    (data)
    );

endmodule