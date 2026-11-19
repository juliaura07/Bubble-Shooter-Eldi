`timescale 1ns/1ps
// Prueba la FSM del disparo con cadena vertical. Tablero de prueba (fila 0 = arriba):
//   columna 0: R R R          columna 2: R V V V
//   columna 3: V V V V        columna 9: llena de V      resto vacio
// pulso_cuadro llega cada 4 ciclos para simular rapido.
module control_disparo_tb;
    reg  reloj = 1'b0, reinicio = 1'b1;
    always #5 reloj = ~reloj;

    reg  [511:0] contenido_inicial;
    reg  [7:0]   dir_lect = 8'd0;
    wire [1:0]   dato_lect, color_arriba;
    wire [7:0]   dir_arriba_bola;
    wire [9:0]   ocupada;
    reg          pulso_disparo = 1'b0;
    reg  [3:0]   columna_canon = 4'd0;
    reg  [1:0]   color_siguiente = 2'b01;
    wire         activa, lanzar, hab_escr, elimina, pierde;
    wire [3:0]   col_bola;
    wire [9:0]   y_bola;
    wire [1:0]   color_bola;
    wire [7:0]   dir_escr;
    wire [1:0]   dato_escr;

    reg [1:0] cuenta_f = 2'd0;
    always @(posedge reloj) cuenta_f <= cuenta_f + 2'd1;
    wire pulso_cuadro = (cuenta_f == 2'd3);

    tablero u_tablero (.reloj(reloj), .reinicio(reinicio), .contenido_inicial(contenido_inicial),
                   .dir_lect(dir_lect), .dato_lect(dato_lect),
                   .dir_arriba(dir_arriba_bola), .dato_arriba(color_arriba),
                   .col_consulta(col_bola), .ocupada(ocupada),
                   .hab_escr(hab_escr), .dir_escr(dir_escr), .dato_escr(dato_escr));

    control_disparo dut (.reloj(reloj), .reinicio(reinicio), .pulso_cuadro(pulso_cuadro), .pulso_disparo(pulso_disparo),
                   .columna_canon(columna_canon), .color_siguiente(color_siguiente), .ocupada(ocupada),
                   .color_arriba(color_arriba),
                   .activa(activa), .col_bola(col_bola), .y_bola(y_bola), .color_bola(color_bola),
                   .lanzar(lanzar), .dir_arriba_bola(dir_arriba_bola),
                   .hab_escr(hab_escr), .dir_escr(dir_escr), .dato_escr(dato_escr), .elimina(elimina),
                   .pierde(pierde));

    integer errores = 0, disparos = 0, escrituras = 0, eliminadas = 0, perdidas = 0, i, t;
    always @(posedge reloj) begin
        if (lanzar) disparos = disparos + 1;
        if (hab_escr)     escrituras   = escrituras + 1;
        if (elimina)    eliminadas     = eliminadas + 1;
        if (pierde)     perdidas       = perdidas + 1;
    end

    task disparar(input [3:0] c, input [1:0] color);
    begin
        columna_canon = c; color_siguiente = color;
        @(negedge reloj); pulso_disparo = 1'b1;
        @(negedge reloj); pulso_disparo = 1'b0;
        t = 0;
        while (activa && t < 5000) begin @(negedge reloj); t = t + 1; end
        if (t >= 5000) begin errores = errores + 1; $display("[FAIL] la bola nunca termino"); end
    end
    endtask

    // lee una casilla del tablero (task porque necesita un retardo)
    reg [1:0] c0, c1, c2, c3;
    task leer(input [3:0] f, input [3:0] c, output [1:0] v);
    begin dir_lect = {f, c}; #1; v = dato_lect; end
    endtask

    task revisar(input cond, input [8*64-1:0] mensaje);
    begin
        if (cond) $display("[PASS] %0s", mensaje);
        else begin errores = errores + 1; $display("[FAIL] %0s (escrituras=%0d eliminadas=%0d disparos=%0d)", mensaje, escrituras, eliminadas, disparos); end
    end
    endtask

    initial begin
        contenido_inicial = 512'd0;
        for (i = 0; i < 3; i = i + 1)  contenido_inicial[(i*16 + 0)*2 +: 2] = 2'b01;   // columna 0: R R R
        contenido_inicial[(0*16 + 2)*2 +: 2] = 2'b01;                                 // columna 2: R
        for (i = 1; i < 4; i = i + 1)  contenido_inicial[(i*16 + 2)*2 +: 2] = 2'b10;   //            V V V
        for (i = 0; i < 4; i = i + 1)  contenido_inicial[(i*16 + 3)*2 +: 2] = 2'b10;   // columna 3: V V V V
        for (i = 0; i < 10; i = i + 1) contenido_inicial[(i*16 + 9)*2 +: 2] = 2'b10;   // columna 9: llena de V
        for (i = 0; i < 9; i = i + 1)  contenido_inicial[(i*16 + 7)*2 +: 2] = (i % 2) ? 2'b10 : 2'b01; // columna 7: filas 0-8 R/V
        repeat (3) @(negedge reloj);
        reinicio = 1'b0;

        disparar(4'd0, 2'b11);
        leer(3, 0, c0);
        revisar(c0 == 2'b11 && y_bola == 10'd144 && eliminadas == 0 && escrituras == 1,
              "1. azul bajo roja: otro color, se agrupa en (3,0)");

        disparar(4'd0, 2'b11);
        leer(3, 0, c0); leer(2, 0, c1);
        revisar(c0 == 2'b00 && c1 == 2'b01 && eliminadas == 1 && escrituras == 2,
              "2. azul bajo azul: se elimina 1 y para en la roja");

        disparar(4'd2, 2'b10);
        leer(3, 2, c0); leer(2, 2, c1); leer(1, 2, c2); leer(0, 2, c3);
        revisar(c0 == 2'b00 && c1 == 2'b00 && c2 == 2'b00 && c3 == 2'b01 && eliminadas == 4 && escrituras == 5,
              "3. cadena: se eliminan 3 verdes seguidas y para en la roja");

        disparar(4'd3, 2'b10);
        leer(3, 3, c0); leer(0, 3, c1);
        revisar(c0 == 2'b00 && c1 == 2'b00 && eliminadas == 8 && escrituras == 9,
              "4. cadena hasta el techo: se eliminan las 4 verdes");

        disparar(4'd1, 2'b01);
        leer(0, 1, c0);
        revisar(c0 == 2'b01 && eliminadas == 8 && escrituras == 10,
              "5. columna vacia: llega al techo y se agrupa");

        disparar(4'd9, 2'b10);
        leer(9, 9, c0); leer(0, 9, c1);
        revisar(c0 == 2'b00 && c1 == 2'b00 && eliminadas == 18 && escrituras == 20,
              "6. columna llena de verdes: se elimina toda la columna");

        disparar(4'd9, 2'b01);
        leer(0, 9, c0);
        revisar(c0 == 2'b01 && escrituras == 21, "7. columna vaciada: la roja llega al techo");

        // disparo mientras otra bola esta en juego: se ignora
        columna_canon = 4'd5; color_siguiente = 2'b11;
        @(negedge reloj); pulso_disparo = 1'b1; @(negedge reloj); pulso_disparo = 1'b0;
        repeat (20) @(negedge reloj);
        @(negedge reloj); pulso_disparo = 1'b1; @(negedge reloj); pulso_disparo = 1'b0;
        t = 0; while (activa && t < 5000) begin @(negedge reloj); t = t + 1; end
        leer(0, 5, c0);
        revisar(disparos == 8 && escrituras == 22 && c0 == 2'b11 && perdidas == 0, "8. segundo disparo en vuelo: ignorado");

        disparar(4'd7, 2'b11);
        leer(9, 7, c0);
        revisar(c0 == 2'b11 && perdidas == 0 && escrituras == 23, "8b. se agrupa en la fila 9 (la ultima): todavia no pierde");

        disparar(4'd7, 2'b01);
        revisar(perdidas == 1 && escrituras == 23, "8c. columna llena y otro color: no cabe, pierde");

        reinicio = 1'b1; @(negedge reloj); reinicio = 1'b0; @(negedge reloj);
        leer(2, 0, c0); leer(1, 2, c1);
        revisar(c0 == 2'b01 && c1 == 2'b10 && !activa, "9. reinicio recarga el tablero");

        if (errores == 0) $display("RESULTADO FINAL control_disparo_tb: PASS");
        else             $display("RESULTADO FINAL control_disparo_tb: FAIL (%0d errores)", errores);
        $finish;
    end
endmodule
