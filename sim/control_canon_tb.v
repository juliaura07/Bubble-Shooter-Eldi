`timescale 1ns/1ps
// Prueba el canon: arranca en 4, se mueve 1 columna por pulso y satura en 0 y 9.
module control_canon_tb;
    reg  reloj = 1'b0, reinicio = 1'b1, pulso_izq = 1'b0, pulso_der = 1'b0;
    wire [3:0] columna;
    always #5 reloj = ~reloj;

    control_canon dut (.reloj(reloj), .reinicio(reinicio), .pulso_izq(pulso_izq),
                     .pulso_der(pulso_der), .columna(columna));

    integer errores = 0, i;

    task pulso_derecha; begin pulso_der = 1'b1; @(negedge reloj); pulso_der = 1'b0; @(negedge reloj); end endtask
    task pulso_izquierda;  begin pulso_izq  = 1'b1; @(negedge reloj); pulso_izq  = 1'b0; @(negedge reloj); end endtask

    task revisar(input [3:0] e, input [8*48-1:0] mensaje);
    begin
        if (columna === e) $display("[PASS] %0s (columna=%0d)", mensaje, columna);
        else begin
            errores = errores + 1;
            $display("[FAIL] %0s (columna=%0d, esperado %0d)", mensaje, columna, e);
        end
    end
    endtask

    initial begin
        repeat (3) @(negedge reloj);
        revisar(4, "1. durante reinicio: columna inicial 4");
        reinicio = 1'b0;
        repeat (5) @(negedge reloj);
        revisar(4, "2. sin pulsos no se mueve");
        pulso_derecha; pulso_derecha; pulso_derecha;
        revisar(7, "3. tres pulsos a la derecha");
        for (i = 0; i < 5; i = i + 1) pulso_derecha;
        revisar(9, "4. satura en la columna 9 (borde derecho)");
        for (i = 0; i < 12; i = i + 1) pulso_izquierda;
        revisar(0, "5. satura en la columna 0 (borde izquierdo)");
        pulso_derecha;
        revisar(1, "6. desde 0 vuelve a moverse");
        reinicio = 1'b1; @(negedge reloj); reinicio = 1'b0; @(negedge reloj);
        revisar(4, "7. reinicio vuelve a la columna 4");

        if (errores == 0) $display("RESULTADO FINAL control_canon_tb: PASS");
        else             $display("RESULTADO FINAL control_canon_tb: FAIL (%0d errores)", errores);
        $finish;
    end
endmodule
