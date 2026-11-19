`timescale 1ns/1ps
// Prueba control_juego: puntaje BCD de 10 en 10, cambio de nivel 1 -> 2 -> 3 -> 1,
// perdiste (se queda y bloquea el cambio de nivel) y reinicio.
module control_juego_tb;
    reg  reloj = 1'b0, reinicio = 1'b1;
    always #5 reloj = ~reloj;

    reg        tablero_vacio = 1'b0, bola_activa = 1'b0, pierde = 1'b0, elimina = 1'b0;
    wire [1:0] nivel, nivel_a_cargar;
    wire       cargar_nivel, perdido;
    wire [3:0] decenas, centenas, miles;

    control_juego dut (.reloj(reloj), .reinicio(reinicio),
                       .tablero_vacio(tablero_vacio), .bola_activa(bola_activa),
                       .pierde(pierde), .elimina(elimina),
                       .nivel(nivel), .nivel_a_cargar(nivel_a_cargar), .cargar_nivel(cargar_nivel),
                       .perdido(perdido), .decenas(decenas), .centenas(centenas), .miles(miles));

    integer errores = 0, k;

    task revisar(input cond, input [8*64-1:0] mensaje);
    begin
        if (cond) $display("[PASS] %0s", mensaje);
        else begin
            errores = errores + 1;
            $display("[FAIL] %0s (nivel=%0d perdido=%b puntaje=%0d%0d%0d0)", mensaje, nivel, perdido, miles, centenas, decenas);
        end
    end
    endtask

    task eliminar(input integer n);         // n pulsos de 1 ciclo
    begin
        for (k = 0; k < n; k = k + 1) begin
            elimina = 1'b1; @(negedge reloj); elimina = 1'b0; @(negedge reloj);
        end
    end
    endtask

    task vaciar;                            // el tablero queda vacio 1 ciclo
    begin
        tablero_vacio = 1'b1; #1;
        revisar(cargar_nivel == 1'b1, "   cargar_nivel = 1 con el tablero vacio");
        @(negedge reloj); tablero_vacio = 1'b0;
    end
    endtask

    initial begin
        @(negedge reloj); #1;
        revisar(nivel_a_cargar == 2'd0, "1. durante el reinicio se carga el nivel 1");
        @(negedge reloj); reinicio = 1'b0; @(negedge reloj);
        revisar(nivel == 2'd0 && !perdido && {miles, centenas, decenas} == 12'h000, "2. estado inicial");

        eliminar(12);
        revisar({miles, centenas, decenas} == 12'h012, "3. 12 burbujas = 120 puntos");

        tablero_vacio = 1'b1; bola_activa = 1'b1; #1;
        revisar(cargar_nivel == 1'b0, "4. tablero vacio con la bola en juego: espera");
        @(negedge reloj); bola_activa = 1'b0; tablero_vacio = 1'b0;
        revisar(nivel == 2'd0, "4b. el nivel no cambio");

        vaciar;  revisar(nivel == 2'd1, "5. nivel 1 -> nivel 2");
        vaciar;  revisar(nivel == 2'd2, "6. nivel 2 -> nivel 3");
        tablero_vacio = 1'b1; #1;
        revisar(nivel_a_cargar == 2'd0, "7. despues del nivel 3 se carga el nivel 1");
        @(negedge reloj); tablero_vacio = 1'b0;
        revisar(nivel == 2'd0, "7b. vuelve al nivel 1");

        eliminar(88);
        revisar({miles, centenas, decenas} == 12'h100, "8. acarreo: 120 + 880 = 1000 puntos");

        pierde = 1'b1; @(negedge reloj); pierde = 1'b0; @(negedge reloj);
        revisar(perdido == 1'b1, "9. pierde: perdido = 1");
        repeat (5) @(negedge reloj);
        tablero_vacio = 1'b1; #1;
        revisar(perdido == 1'b1 && cargar_nivel == 1'b0, "10. perdido se mantiene y bloquea el cambio de nivel");
        @(negedge reloj); tablero_vacio = 1'b0;

        reinicio = 1'b1; @(negedge reloj); reinicio = 1'b0; @(negedge reloj);
        revisar(nivel == 2'd0 && !perdido && {miles, centenas, decenas} == 12'h000, "11. reinicio: nivel 1, sin perder, puntaje 0");

        if (errores == 0) $display("RESULTADO FINAL control_juego_tb: PASS");
        else              $display("RESULTADO FINAL control_juego_tb: FAIL (%0d errores)", errores);
        $finish;
    end
endmodule
