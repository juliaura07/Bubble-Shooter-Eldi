`timescale 1ns/1ps
// Displays de 7 segmentos de la Nexys (8 digitos, anodo comun, todo activo en bajo).
// Multiplexado en el tiempo: se enciende un digito a la vez, muy rapido, y el ojo
// los ve todos encendidos. Con 100 MHz y ANCHO = 17 cada digito se refresca a ~760 Hz.
// Muestra:  [L][nivel][ ][ ][miles][centenas][decenas][0]
//            AN7  AN6                                  AN0
module displays_7seg #(
    parameter ANCHO = 17                   // 1 en simulacion
)(
    input  wire       reloj,
    input  wire       reinicio,
    input  wire [1:0] nivel,               // 0..2 -> se muestra 1..3
    input  wire [3:0] miles,
    input  wire [3:0] centenas,
    input  wire [3:0] decenas,
    output wire [6:0] seg,                 // {g,f,e,d,c,b,a}, activo en bajo
    output wire       dp,                  // punto decimal (apagado)
    output wire [7:0] an                   // anodos, activo en bajo
);
    // ---- contador de refresco: sus 3 bits altos eligen el digito ----
    reg  [ANCHO+2:0] cuenta;
    always @(posedge reloj) begin
        if (reinicio) cuenta <= 0;
        else          cuenta <= cuenta + 1'b1;
    end
    wire [2:0] sel = cuenta[ANCHO+2:ANCHO];

    // ---- MUX 8:1 del digito a mostrar (codigo de 4 bits) ----
    //   0..9 numeros, 10 = letra L, 15 = apagado
    wire [3:0] num_nivel = {2'b00, nivel} + 4'd1;
    wire [3:0] codigo = (sel == 3'd0) ? 4'd0     :     // unidades: siempre 0
                        (sel == 3'd1) ? decenas  :
                        (sel == 3'd2) ? centenas :
                        (sel == 3'd3) ? miles    :
                        (sel == 3'd6) ? num_nivel:
                        (sel == 3'd7) ? 4'd10    :     // L
                                        4'd15;         // AN4, AN5 apagados

    // ---- decodificador a 7 segmentos: LUT de 16 x 7 bits (1 = segmento encendido) ----
    localparam [111:0] SEGMENTOS = {
        7'h00, 7'h00, 7'h00, 7'h00, 7'h00, 7'h38,      // 15..11 apagado, 10 = L
        7'h6F, 7'h7F, 7'h07, 7'h7D, 7'h6D,             // 9 8 7 6 5
        7'h66, 7'h4F, 7'h5B, 7'h06, 7'h3F };           // 4 3 2 1 0
    wire [6:0] encendidos = SEGMENTOS[codigo * 7 +: 7];
    assign seg = ~encendidos;                          // la placa es activa en bajo
    assign dp  = 1'b1;

    // ---- decodificador 3 a 8 de los anodos (activo en bajo) ----
    assign an = ~(8'b0000_0001 << sel);
endmodule
