`timescale 1ns/1ps
// Columna del canon: contador up/down de 4 bits con saturacion (0 .. NUM_COLS-1).
// Se mueve 1 columna por pulsacion.
module control_canon #(
    parameter [3:0] NUM_COLS = 4'd10,
    parameter [3:0] INICIAL  = 4'd4
)(
    input  wire       reloj,
    input  wire       reinicio,
    input  wire       pulso_izq,
    input  wire       pulso_der,
    output reg  [3:0] columna
);
    wire en_borde_izq  = (columna == 4'd0);                 // comparador = 0
    wire en_borde_der = (columna == NUM_COLS - 4'd1);         // comparador = 9
    wire mover_izq  = pulso_izq  & ~en_borde_izq;
    wire mover_der = pulso_der & ~en_borde_der;

    // MUX 3:1 con prioridad: columna-1 / columna+1 / columna
    wire [3:0] columna_sig = mover_izq  ? columna - 4'd1 :
                          mover_der ? columna + 4'd1 :
                                     columna;

    always @(posedge reloj) begin
        if (reinicio) columna <= INICIAL;
        else       columna <= columna_sig;
    end
endmodule
