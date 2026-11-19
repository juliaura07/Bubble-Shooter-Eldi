`timescale 1ns/1ps
// Control del juego: nivel actual, perdiste y puntaje.
// - Cuando el tablero queda vacio (y no hay bola en juego) se carga el siguiente nivel:
//   0 -> 1 -> 2 -> 0 (despues del nivel 3 vuelve al nivel 1).
// - Si una columna se llena, 'perdido' pasa a 1 y se queda asi hasta el reinicio.
// - Puntaje en BCD: 10 puntos por burbuja eliminada (las unidades siempre valen 0,
//   asi que cada eliminacion suma 1 en las decenas). Despues de 9990 vuelve a 0000.
module control_juego (
    input  wire       reloj,
    input  wire       reinicio,
    input  wire       tablero_vacio,       // todas las casillas en 00
    input  wire       bola_activa,         // la FSM del disparo no esta en ESPERAR
    input  wire       pierde,              // 1 ciclo: la bola no cabe (columna llena)
    input  wire       elimina,             // 1 ciclo por burbuja eliminada
    output reg  [1:0] nivel,               // 0, 1 o 2
    output wire [1:0] nivel_a_cargar,      // nivel que debe copiar el tablero
    output wire       cargar_nivel,        // 1 ciclo: recargar el tablero
    output reg        perdido,
    output reg  [3:0] decenas,
    output reg  [3:0] centenas,
    output reg  [3:0] miles
);
    // ---- cambio de nivel ----
    assign cargar_nivel = tablero_vacio & ~bola_activa & ~perdido;
    wire       ultimo    = (nivel == 2'd2);                     // comparador
    wire [1:0] nivel_sig = ultimo ? 2'd0 : nivel + 2'd1;        // contador 0..2
    // en el reinicio el tablero carga el nivel 1; al pasar de nivel, el siguiente
    assign nivel_a_cargar = reinicio ? 2'd0 : nivel_sig;

    // ---- puntaje BCD (3 contadores de 0 a 9 encadenados) ----
    wire d9 = (decenas  == 4'd9);
    wire c9 = (centenas == 4'd9);
    wire m9 = (miles    == 4'd9);
    wire inc_dec = elimina;                  // +10 puntos
    wire inc_cen = inc_dec & d9;             // acarreo de decenas
    wire inc_mil = inc_cen & c9;             // acarreo de centenas
    wire [3:0] decenas_sig  = inc_dec ? (d9 ? 4'd0 : decenas  + 4'd1) : decenas;
    wire [3:0] centenas_sig = inc_cen ? (c9 ? 4'd0 : centenas + 4'd1) : centenas;
    wire [3:0] miles_sig    = inc_mil ? (m9 ? 4'd0 : miles    + 4'd1) : miles;

    always @(posedge reloj) begin
        if (reinicio) begin
            nivel    <= 2'd0;
            perdido  <= 1'b0;
            decenas  <= 4'd0;
            centenas <= 4'd0;
            miles    <= 4'd0;
        end else begin
            nivel    <= cargar_nivel ? nivel_sig : nivel;
            perdido  <= perdido | pierde;            // se queda en 1
            decenas  <= decenas_sig;
            centenas <= centenas_sig;
            miles    <= miles_sig;
        end
    end
endmodule
