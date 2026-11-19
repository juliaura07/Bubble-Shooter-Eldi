`timescale 1ns/1ps
// Prueba la secuencia de burbujas: cada disparo avanza 1 y despues de 16 vuelve al inicio.
module siguiente_burbuja_tb;
    reg  reloj = 1'b0, reinicio = 1'b1, pulso_disparo = 1'b0;
    wire [3:0] indice;
    wire [1:0] color;
    always #5 reloj = ~reloj;

    siguiente_burbuja dut (.reloj(reloj), .reinicio(reinicio), .pulso_disparo(pulso_disparo), .indice(indice), .color(color));

    // secuencia esperada (entrada 0 a 15): R V R A R R V V A A R V A R V A
    reg [1:0] esperado [0:15];
    integer errores = 0, i;

    initial begin
        esperado[0]=2'b01; esperado[1]=2'b10; esperado[2]=2'b01;  esperado[3]=2'b11;
        esperado[4]=2'b01; esperado[5]=2'b01; esperado[6]=2'b10;  esperado[7]=2'b10;
        esperado[8]=2'b11; esperado[9]=2'b11; esperado[10]=2'b01; esperado[11]=2'b10;
        esperado[12]=2'b11; esperado[13]=2'b01; esperado[14]=2'b10; esperado[15]=2'b11;

        repeat (3) @(negedge reloj);
        reinicio = 1'b0;
        @(negedge reloj);
        for (i = 0; i < 17; i = i + 1) begin
            if (indice !== i[3:0] || color !== esperado[i % 16]) begin
                errores = errores + 1;
                $display("[FAIL] disparo %0d: indice=%0d color=%b, esperado indice=%0d color=%b",
                         i, indice, color, i % 16, esperado[i % 16]);
            end else
                $display("[PASS] disparo %0d: indice=%0d color=%b", i, indice, color);
            pulso_disparo = 1'b1; @(negedge reloj); pulso_disparo = 1'b0;
            repeat (3) @(negedge reloj);
        end

        if (errores == 0) $display("RESULTADO FINAL siguiente_burbuja_tb: PASS");
        else             $display("RESULTADO FINAL siguiente_burbuja_tb: FAIL (%0d errores)", errores);
        $finish;
    end
endmodule
