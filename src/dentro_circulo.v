`timescale 1ns/1ps
// dentro = 1 si (px-cx)^2 + (py-cy)^2 <= R^2
module dentro_circulo #(
    parameter integer R = 15
)(
    input  wire [9:0] px,
    input  wire [9:0] py,
    input  wire [9:0] cx,
    input  wire [9:0] cy,
    output wire       dentro
);
    localparam signed [10:0] R_CON_SIGNO = R;
    localparam signed [14:0] R_CUAD = R * R;

    // restadores con signo
    wire signed [10:0] dx = $signed({1'b0, px}) - $signed({1'b0, cx});
    wire signed [10:0] dy = $signed({1'b0, py}) - $signed({1'b0, cy});

    // caja: solo dentro de ella |dx|,|dy| <= R (y alcanzan 7 bits)
    wire en_caja = (dx >= -R_CON_SIGNO) && (dx <= R_CON_SIGNO) && (dy >= -R_CON_SIGNO) && (dy <= R_CON_SIGNO);

    wire signed [14:0] dx_ext = $signed(dx[6:0]);   // extension de signo a 15 bits
    wire signed [14:0] dy_ext = $signed(dy[6:0]);

    // multiplicadores (cuadrados) + sumador + comparador
    wire signed [14:0] dx_cuad = dx_ext * dx_ext;
    wire signed [14:0] dy_cuad = dy_ext * dy_ext;
    wire signed [14:0] dist_cuad  = dx_cuad + dy_cuad;

    assign dentro = en_caja && (dist_cuad <= R_CUAD);
endmodule
