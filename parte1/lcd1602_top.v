module lcd1602_top (
    input clk,
    input reset,
    output rs,
    output rw,
    output enable,
    output [7:0] data
);

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
        .rs      (rs),
        .rw      (rw),
        .enable  (enable),
        .data    (data)
    );

endmodule