`timescale 1ns/1ps
// Tablero de juego en registros: 10x10 celdas de 2 bits.
// Direccion de una celda = {fila[3:0], columna[3:0]} (se reservan 16x16 posiciones; se usan 10x10).
// Cada celda es un registro propio de 2 bits con:
//   comparador (dir_escr = su direccion) + AND con hab_escr  -> enable de escritura
//   MUX de reinicio que carga el nivel inicial (contenido_inicial)
// - Lectura 1 (dir_lect): para dibujar la pantalla.
// - Lectura 2 (ocupada): ocupacion de las 10 filas de la columna col_consulta, para el disparo.
// - Lectura 3 (dir_arriba): color de la casilla de arriba, para comparar al chocar.
module tablero (
    input  wire         reloj,
    input  wire         reinicio,
    input  wire [511:0] contenido_inicial,              // nivel inicial (todas las celdas)
    input  wire [7:0]   dir_lect,             // lectura para el dibujo
    output wire [1:0]   dato_lect,
    input  wire [7:0]   dir_arriba,             // lectura del color de una casilla (la de arriba)
    output wire [1:0]   dato_arriba,
    input  wire [3:0]   col_consulta,              // columna que se consulta
    output wire [9:0]   ocupada,               // ocupada[f] = 1 si la fila f de col_consulta tiene burbuja
    input  wire         hab_escr,                // escritura
    input  wire [7:0]   dir_escr,
    input  wire [1:0]   dato_escr,
    output wire         vacio              // 1 si todas las casillas estan en 00
);
    wire [511:0] celdas;                    // todas las celdas juntas (solo cables)

    genvar f, c;
    generate
        for (f = 0; f < 16; f = f + 1) begin : g_fila
            for (c = 0; c < 16; c = c + 1) begin : g_col
                localparam [7:0] DIR = f * 16 + c;
                if (f < 10 && c < 10) begin : g_celda
                    reg  [1:0] valor;
                    wire       hab_escr_celda = hab_escr && (dir_escr == DIR);       // comparador + AND
                    always @(posedge reloj) begin
                        if (reinicio)    valor <= contenido_inicial[DIR * 2 +: 2];
                        else if (hab_escr_celda) valor <= dato_escr;
                    end
                    assign celdas[DIR * 2 +: 2] = valor;
                end else begin : g_vacia
                    assign celdas[DIR * 2 +: 2] = 2'b00;          // posicion fuera del tablero
                end
            end
        end
    endgenerate

    // lectura para el dibujo (MUX con la direccion como selector)
    assign dato_lect = celdas[{dir_lect, 1'b0} +: 2];

    // lectura del color de la casilla de arriba (para comparar)
    assign dato_arriba = celdas[{dir_arriba, 1'b0} +: 2];

    // ocupacion de la columna col_consulta: 10 lecturas en paralelo + OR de sus 2 bits
    assign ocupada[0] = |celdas[{4'd0, col_consulta, 1'b0} +: 2];
    assign ocupada[1] = |celdas[{4'd1, col_consulta, 1'b0} +: 2];
    assign ocupada[2] = |celdas[{4'd2, col_consulta, 1'b0} +: 2];
    assign ocupada[3] = |celdas[{4'd3, col_consulta, 1'b0} +: 2];
    assign ocupada[4] = |celdas[{4'd4, col_consulta, 1'b0} +: 2];
    assign ocupada[5] = |celdas[{4'd5, col_consulta, 1'b0} +: 2];
    assign ocupada[6] = |celdas[{4'd6, col_consulta, 1'b0} +: 2];
    assign ocupada[7] = |celdas[{4'd7, col_consulta, 1'b0} +: 2];
    assign ocupada[8] = |celdas[{4'd8, col_consulta, 1'b0} +: 2];
    assign ocupada[9] = |celdas[{4'd9, col_consulta, 1'b0} +: 2];

    // tablero vacio: NOR de todos los bits de todas las casillas
    assign vacio = ~|celdas;
endmodule
