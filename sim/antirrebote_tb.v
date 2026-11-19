`timescale 1ns/1ps
// Prueba el antirrebote con ANCHO=4 (16 ciclos en vez de ~10 ms para simular rapido).
// La salida tarda ~18 ciclos en aceptar un cambio estable (2 del sincronizador + 16 del contador).
module antirrebote_tb;
    reg  reloj = 1'b0, reinicio = 1'b1, con_ruido = 1'b0;
    wire limpia;
    always #5 reloj = ~reloj;

    antirrebote #(.ANCHO(4)) dut (.reloj(reloj), .reinicio(reinicio), .con_ruido(con_ruido), .limpia(limpia));

    integer errores = 0;

    task mantener(input v, input integer n);
    begin
        con_ruido = v;
        repeat (n) @(negedge reloj);
    end
    endtask

    task revisar(input e, input [8*56-1:0] mensaje);
    begin
        if (limpia === e) $display("[PASS] %0s", mensaje);
        else begin
            errores = errores + 1;
            $display("[FAIL] %0s (limpia=%b, esperado=%b)", mensaje, limpia, e);
        end
    end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("sim/antirrebote_tb.vcd");
            $dumpvars(0, antirrebote_tb);
        end
        repeat (3) @(negedge reloj);
        reinicio = 1'b0;

        // 1. reposo
        mantener(0, 10);
        revisar(0, "1. reposo: limpia = 0");

        // 2. glitch corto (5 ciclos) se ignora
        mantener(1, 5);  mantener(0, 25);
        revisar(0, "2. glitch de 5 ciclos ignorado");

        // 3. pulsacion con rebotes al presionar
        mantener(1, 3);  mantener(0, 3);  mantener(1, 2);  mantener(0, 4);  mantener(1, 3);
        mantener(1, 10);
        revisar(0, "3a. rebotes: aun no acepta (solo 13 ciclos estables)");
        mantener(1, 20);
        revisar(1, "3b. ya estable: acepta la pulsacion");

        // 4. rebotes al soltar
        mantener(0, 2);  mantener(1, 3);  mantener(0, 2);  mantener(1, 2);  mantener(0, 10);
        revisar(1, "4a. rebote al soltar: sigue en 1");
        mantener(0, 20);
        revisar(0, "4b. suelta estable: acepta");

        // 5. reinicio en medio de una pulsacion
        mantener(1, 30);
        revisar(1, "5a. presionado estable: limpia = 1");
        reinicio = 1'b1;
        mantener(1, 3);
        revisar(0, "5b. reinicio limpia la salida");
        reinicio = 1'b0;

        if (errores == 0) $display("RESULTADO FINAL antirrebote_tb: PASS");
        else             $display("RESULTADO FINAL antirrebote_tb: FAIL (%0d errores)", errores);
        $finish;
    end
endmodule
