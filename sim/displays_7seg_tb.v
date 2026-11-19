`timescale 1ns/1ps
// Prueba displays_7seg con ANCHO = 1 (cambia de digito cada 2 ciclos).
// Muestra nivel 2 y 3450 puntos: [L][2][ ][ ][3][4][5][0].
module displays_7seg_tb;
    reg  reloj = 1'b0, reinicio = 1'b1;
    always #5 reloj = ~reloj;

    wire [6:0] seg;
    wire       dp;
    wire [7:0] an;

    displays_7seg #(.ANCHO(1)) dut (.reloj(reloj), .reinicio(reinicio),
        .nivel(2'd1), .miles(4'd3), .centenas(4'd4), .decenas(4'd5),
        .seg(seg), .dp(dp), .an(an));

    // segmentos esperados {g..a} (1 = encendido) para cada anodo 0..7
    reg [6:0] esperado [0:7];
    reg [7:0] visto = 8'h00;
    integer errores = 0, d, k;

    initial begin
        esperado[0] = 7'h3F;   // 0
        esperado[1] = 7'h6D;   // 5
        esperado[2] = 7'h66;   // 4
        esperado[3] = 7'h4F;   // 3
        esperado[4] = 7'h00;   // apagado
        esperado[5] = 7'h00;   // apagado
        esperado[6] = 7'h5B;   // 2 (nivel)
        esperado[7] = 7'h38;   // L

        repeat (2) @(negedge reloj);
        reinicio = 1'b0;
        for (k = 0; k < 40; k = k + 1) begin
            @(negedge reloj);
            d = -1;
            case (an)
                8'b1111_1110: d = 0;  8'b1111_1101: d = 1;  8'b1111_1011: d = 2;  8'b1111_0111: d = 3;
                8'b1110_1111: d = 4;  8'b1101_1111: d = 5;  8'b1011_1111: d = 6;  8'b0111_1111: d = 7;
                default: d = -1;
            endcase
            if (d < 0) begin
                errores = errores + 1; $display("[FAIL] anodos = %b: debe haber exactamente uno en 0", an);
            end else begin
                visto[d] = 1'b1;
                if (~seg !== esperado[d]) begin
                    errores = errores + 1;
                    $display("[FAIL] digito %0d: segmentos %b, esperado %b", d, ~seg, esperado[d]);
                end
            end
        end
        if (visto == 8'hFF) $display("[PASS] se recorrieron los 8 digitos, uno a la vez");
        else begin errores = errores + 1; $display("[FAIL] digitos recorridos: %b", visto); end
        if (dp === 1'b1) $display("[PASS] punto decimal apagado");
        else begin errores = errores + 1; $display("[FAIL] dp = %b", dp); end
        if (errores == 0) $display("[PASS] cada digito muestra L 2 _ _ 3 4 5 0");

        if (errores == 0) $display("RESULTADO FINAL displays_7seg_tb: PASS");
        else              $display("RESULTADO FINAL displays_7seg_tb: FAIL (%0d errores)", errores);
        $finish;
    end
endmodule
