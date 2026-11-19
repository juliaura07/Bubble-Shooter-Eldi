`timescale 1ns/1ps
// Prueba control_entradas: 3 pulsadores (activos en bajo) + switch (activo en alto), con ANCHO=4.
module control_entradas_tb;
    reg  reloj = 1'b0, reinicio = 1'b1;
    reg  boton_izq = 1'b1, boton_der = 1'b1, boton_disparo = 1'b1;   // 1 = suelto
    reg  interruptor_color = 1'b0;                                       // 0 = abajo
    wire pulso_izq, pulso_der, pulso_disparo, pulso_color;
    wire [3:0] niveles;
    always #5 reloj = ~reloj;

    control_entradas #(.ANCHO(4)) dut (
        .reloj(reloj), .reinicio(reinicio),
        .boton_izq(boton_izq), .boton_der(boton_der), .boton_disparo(boton_disparo),
        .interruptor_color(interruptor_color),
        .pulso_izq(pulso_izq), .pulso_der(pulso_der),
        .pulso_disparo(pulso_disparo), .pulso_color(pulso_color),
        .niveles(niveles)
    );

    integer errores = 0, n_izq = 0, n_der = 0, n_disp = 0, n_color = 0;
    always @(posedge reloj) begin
        if (pulso_izq)  n_izq = n_izq + 1;
        if (pulso_der) n_der = n_der + 1;
        if (pulso_disparo) n_disp = n_disp + 1;
        if (pulso_color) n_color = n_color + 1;
    end

    task esperar_ciclos(input integer n);
    begin repeat (n) @(negedge reloj); end
    endtask

    task revisar(input integer l, input integer r, input integer s, input integer c, input [8*56-1:0] mensaje);
    begin
        if (n_izq == l && n_der == r && n_disp == s && n_color == c) $display("[PASS] %0s", mensaje);
        else begin
            errores = errores + 1;
            $display("[FAIL] %0s (izq=%0d der=%0d disp=%0d color=%0d, esperado %0d %0d %0d %0d)",
                     mensaje, n_izq, n_der, n_disp, n_color, l, r, s, c);
        end
    end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("control_entradas_tb.vcd");
            $dumpvars(0, control_entradas_tb);
        end
        esperar_ciclos(3);  reinicio = 1'b0;  esperar_ciclos(5);
        revisar(0, 0, 0, 0, "0. reposo: ningun pulso");

        boton_izq = 1'b0;  esperar_ciclos(60);
        revisar(1, 0, 0, 0, "1. izquierda mantenida: 1 solo pulso");
        if (niveles === 4'b0001) $display("[PASS] 1b. LED de izquierda encendido");
        else begin errores = errores + 1; $display("[FAIL] 1b. niveles=%b, esperado 0001", niveles); end
        boton_izq = 1'b1;  esperar_ciclos(30);
        boton_izq = 1'b0;  esperar_ciclos(30);
        revisar(2, 0, 0, 0, "2. segunda pulsacion: 2 pulsos");
        boton_izq = 1'b1;  esperar_ciclos(30);

        boton_der = 1'b0; esperar_ciclos(30);
        revisar(2, 1, 0, 0, "3. derecha: 1 pulso");
        boton_izq = 1'b0;  esperar_ciclos(30);
        revisar(2, 1, 0, 0, "4. izquierda con derecha presionada: cancelado");
        boton_izq = 1'b1;  boton_der = 1'b1;  esperar_ciclos(30);

        boton_disparo = 1'b0; esperar_ciclos(60);
        revisar(2, 1, 1, 0, "5. disparo: genera su pulso (aun sin uso)");
        boton_disparo = 1'b1; esperar_ciclos(30);

        // switch de color
        interruptor_color = 1'b1;  esperar_ciclos(60);
        revisar(2, 1, 1, 1, "6. switch sube: 1 cambio de color");
        if (niveles === 4'b1000) $display("[PASS] 6b. LED del switch encendido");
        else begin errores = errores + 1; $display("[FAIL] 6b. niveles=%b, esperado 1000", niveles); end
        esperar_ciclos(100);
        revisar(2, 1, 1, 1, "7. switch arriba: sin cambios extra");
        interruptor_color = 1'b0;  esperar_ciclos(40);
        revisar(2, 1, 1, 1, "8. switch baja: no cambia el color");
        interruptor_color = 1'b1;  esperar_ciclos(40);
        revisar(2, 1, 1, 2, "9. switch sube otra vez: 2 cambios");
        interruptor_color = 1'b0;  esperar_ciclos(40);

        // switch con rebotes al subir
        interruptor_color = 1'b1;  esperar_ciclos(2);
        interruptor_color = 1'b0;  esperar_ciclos(2);
        interruptor_color = 1'b1;  esperar_ciclos(3);
        interruptor_color = 1'b0;  esperar_ciclos(1);
        interruptor_color = 1'b1;  esperar_ciclos(40);
        revisar(2, 1, 1, 3, "10. switch con rebotes: 1 solo cambio");

        // reinicio: no deben salir pulsos
        reinicio = 1'b1;
        boton_izq = 1'b0;  esperar_ciclos(30);
        revisar(2, 1, 1, 3, "11. durante reinicio: ningun pulso");
        reinicio = 1'b0;

        if (errores == 0) $display("RESULTADO FINAL control_entradas_tb: PASS");
        else             $display("RESULTADO FINAL control_entradas_tb: FAIL (%0d errores)", errores);
        $finish;
    end
endmodule
