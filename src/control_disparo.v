`timescale 1ns/1ps
// Burbuja disparada con maquina de estados (Moore):
//   ESPERAR   -> espera el disparo
//   DISPARAR  -> sube PASO pixeles por cuadro hasta su fila de llegada
//   VERIFICAR -> compara el color de la bola con la casilla que se esta revisando
//   ELIMINAR  -> mismo color: borra esa casilla y sube a revisar la siguiente
//   AGRUPAR   -> ninguna exploto: la bola se guarda en su casilla
// Cadena vertical: se eliminan todas las burbujas seguidas del mismo color hacia arriba.
module control_disparo #(
    parameter [9:0] Y_INICIAL = 10'd432,     // altura del canon (centro)
    parameter [9:0] PASO    = 10'd8        // pixeles por cuadro
)(
    input  wire       reloj,
    input  wire       reinicio,
    input  wire       pulso_cuadro,          // 1 pulso por cuadro
    input  wire       pulso_disparo,         // 1 pulso por pulsacion
    input  wire [3:0] columna_canon,
    input  wire [1:0] color_siguiente,
    input  wire [9:0] ocupada,                 // ocupacion de la columna de la bola (filas 0..9)
    input  wire [1:0] color_arriba,         // color de la casilla que se revisa (leido del tablero)
    output wire       activa,              // hay una bola en juego (para dibujarla)
    output reg  [3:0] col_bola,                // columna de la bola
    output reg  [9:0] y_bola,                  // altura de la bola (centro, en pixeles)
    output reg  [1:0] color_bola,              // color de la bola
    output wire       lanzar,              // 1 ciclo al disparar (avanza la secuencia)
    output wire [7:0] dir_arriba_bola,          // direccion de la casilla que se revisa
    output wire       hab_escr,                  // escritura en el tablero
    output wire [7:0] dir_escr,
    output wire [1:0] dato_escr,
    output wire       elimina,                 // 1 ciclo por cada burbuja eliminada (para el puntaje)
    output wire       pierde                   // 1 ciclo: la columna ya estaba llena y la bola no cabe
);
    // ---- codificacion de estados ----
    localparam [2:0] ESPERAR   = 3'd0,
                     DISPARAR  = 3'd1,
                     VERIFICAR = 3'd2,
                     ELIMINAR  = 3'd3,
                     AGRUPAR   = 3'd4;
    reg [2:0] estado;

    // ---- registros de la cadena ----
    reg [3:0] fila_llegada;                // donde quedo la bola
    reg [3:0] fila_rev;                    // fila que se esta revisando
    reg       hay_arriba;                  // queda una fila por revisar
    reg       exploto;                     // ya se elimino al menos una

    // ---- decodificador de estado (comparadores) ----
    wire en_esperar   = (estado == ESPERAR);
    wire en_disparar  = (estado == DISPARAR);
    wire en_verificar = (estado == VERIFICAR);
    wire en_eliminar  = (estado == ELIMINAR);
    wire en_agrupar   = (estado == AGRUPAR);

    // ---- fila de llegada: debajo de la ocupada mas baja (MUX en cadena con prioridad) ----
    wire [3:0] fila_destino = ocupada[9] ? 4'd10 :
                            ocupada[8] ? 4'd9  :
                            ocupada[7] ? 4'd8  :
                            ocupada[6] ? 4'd7  :
                            ocupada[5] ? 4'd6  :
                            ocupada[4] ? 4'd5  :
                            ocupada[3] ? 4'd4  :
                            ocupada[2] ? 4'd3  :
                            ocupada[1] ? 4'd2  :
                            ocupada[0] ? 4'd1  :
                                     4'd0;
    wire [4:0] fila_pantalla = {1'b0, fila_destino} + 5'd1;
    wire [9:0] y_destino    = {fila_pantalla, 5'd16};

    // ---- condiciones ----
    assign lanzar  = pulso_disparo & en_esperar;
    wire mover      = en_disparar & pulso_cuadro;
    wire alcanza     = (y_bola <= y_destino + PASO);
    wire llego      = mover & alcanza;                           // llego
    wire mismo_color      = hay_arriba & (color_arriba == color_bola);   // mismo color en la fila revisada
    wire fila_valida = (fila_llegada < 4'd10);                 // columna no llena

    // ---- logica de siguiente estado ----
    wire [2:0] estado_sig = lanzar       ? DISPARAR  :
                            llego         ? VERIFICAR :
                            en_verificar ? (mismo_color ? ELIMINAR : (exploto ? ESPERAR : AGRUPAR)) :
                            en_eliminar  ? VERIFICAR :
                            en_agrupar   ? ESPERAR   :
                                           estado;

    // ---- salidas (dependen solo del estado: Moore) ----
    assign activa     = ~en_esperar;
    assign elimina        = en_eliminar;
    assign pierde         = en_agrupar & (fila_llegada == 4'd10);  // columna llena: la bola quedaria fuera del tablero
    assign dir_arriba_bola = {fila_rev, col_bola};
    assign hab_escr         = en_eliminar | (en_agrupar & fila_valida);
    assign dir_escr      = en_eliminar ? {fila_rev, col_bola} : {fila_llegada, col_bola};
    assign dato_escr      = en_eliminar ? 2'b00 : color_bola;

    // ---- siguiente valor de los registros de la bola ----
    wire [9:0] y_paso     = alcanza ? y_destino : y_bola - PASO;
    wire [9:0] y_bola_sig     = lanzar ? Y_INICIAL : (mover ? y_paso : y_bola);
    wire [3:0] col_bola_sig   = lanzar ? columna_canon : col_bola;
    wire [1:0] color_bola_sig = lanzar ? color_siguiente : color_bola;

    // ---- siguiente valor de los registros de la cadena ----
    // al llegar: se revisa la fila de arriba de la bola
    // al eliminar: se sube una fila; si era la fila 0 (techo) ya no queda nada arriba
    wire [3:0] llegada_sig = llego ? fila_destino : fila_llegada;
    wire [3:0] rev_sig     = llego ? fila_destino - 4'd1 :
                              en_eliminar ? fila_rev - 4'd1 : fila_rev;
    wire       arriba_sig  = llego ? (fila_destino != 4'd0) :
                              en_eliminar ? (fila_rev != 4'd0) : hay_arriba;
    wire       exploto_sig = llego ? 1'b0 : (en_eliminar ? 1'b1 : exploto);

    always @(posedge reloj) begin
        if (reinicio) begin
            estado        <= ESPERAR;
            col_bola         <= 4'd0;
            y_bola           <= Y_INICIAL;
            color_bola       <= 2'b00;
            fila_llegada <= 4'd0;
            fila_rev     <= 4'd0;
            hay_arriba   <= 1'b0;
            exploto      <= 1'b0;
        end else begin
            estado        <= estado_sig;
            col_bola         <= col_bola_sig;
            y_bola           <= y_bola_sig;
            color_bola       <= color_bola_sig;
            fila_llegada <= llegada_sig;
            fila_rev     <= rev_sig;
            hay_arriba   <= arriba_sig;
            exploto      <= exploto_sig;
        end
    end
endmodule
