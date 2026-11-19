`timescale 1ns/1ps
// ROM de los 3 niveles (LUT): cada nivel es un vector constante de 256 celdas x 2 bits.
// Celda (fila, columna) en los bits [(fila*16 + columna)*2 +: 2].
//   . = 00 vacio   R = 01 rojo   V = 10 verde   A = 11 azul
// Todos se resuelven con la secuencia de colores R V R A R R V V A A R V A R V A.
//
//   Nivel 1 (facil, 8 disparos)   Nivel 2 (medio, 16 disparos)   Nivel 3 (original)
//   . A . V . R V . V .           V . A . A . R . A V            R R V V A A V V R R
//   . R . V . . R . R .           V . A . V . A . V V            R V V A A A A V V R
//                                 A . R . V . R . R .            V V A A R R A A V V
//                                 R . V . R . R . . .            . A A R R R R A A .
//                                 R . . . . . . . . .            . . R R . . R R . .
module rom_nivel (
    input  wire [1:0]   nivel,             // 0, 1 o 2 (nivel 1, 2 o 3 en pantalla)
    output wire [511:0] todas_celdas       // nivel completo (carga del tablero)
);
    localparam [511:0] NIVEL_1 = 512'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000110840002248c;
    localparam [511:0] NIVEL_2 = 512'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000112100011213000a3232000b1332;
    localparam [511:0] NIVEL_3 = 512'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050500003d57c000af5fa0006bfe90005afa5;

    // MUX 3:1 de 512 bits
    assign todas_celdas = (nivel == 2'd0) ? NIVEL_1 :
                          (nivel == 2'd1) ? NIVEL_2 :
                                            NIVEL_3;
endmodule
