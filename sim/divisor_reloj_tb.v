`timescale 1ns/1ps
// Verifica que hab_pixel aparezca exactamente cada 4 ciclos y que reinicio lo apague.
module divisor_reloj_tb;
    reg  reloj   = 1'b0;
    reg  reinicio = 1'b1;
    wire hab_pixel;

    always #5 reloj = ~reloj;                  // 100 MHz

    divisor_reloj dut (.reloj(reloj), .reinicio(reinicio), .hab_pixel(hab_pixel));

    integer errores = 0;
    integer ciclo    = 0;
    integer ultimo   = -1;
    integer pulsos = 0;

    always @(posedge reloj) begin
        ciclo = ciclo + 1;
        if (reinicio) begin
            ultimo = -1;
            if (hab_pixel !== 1'b0) begin
                errores = errores + 1;
                $display("[FAIL] hab_pixel debe ser 0 durante reinicio");
            end
        end else if (hab_pixel) begin
            pulsos = pulsos + 1;
            if (ultimo >= 0 && (ciclo - ultimo) != 4) begin
                errores = errores + 1;
                $display("[FAIL] periodo de hab_pixel = %0d ciclos (esperado 4)", ciclo - ultimo);
            end
            ultimo = ciclo;
        end
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("sim/divisor_reloj_tb.vcd");
            $dumpvars(0, divisor_reloj_tb);
        end
        repeat (3) @(negedge reloj);
        reinicio = 1'b0;
        repeat (100) @(negedge reloj);
        if (pulsos >= 20) $display("[PASS] hab_pixel cada 4 ciclos (%0d pulsos observados)", pulsos);
        else begin
            errores = errores + 1;
            $display("[FAIL] muy pocos pulsos: %0d", pulsos);
        end

        // caso especial: reinicio a mitad de la cuenta
        @(negedge reloj); reinicio = 1'b1;
        repeat (3) @(negedge reloj);
        reinicio = 1'b0;
        repeat (40) @(negedge reloj);

        if (errores == 0) $display("RESULTADO FINAL divisor_reloj_tb: PASS");
        else             $display("RESULTADO FINAL divisor_reloj_tb: FAIL (%0d errores)", errores);
        $finish;
    end
endmodule
