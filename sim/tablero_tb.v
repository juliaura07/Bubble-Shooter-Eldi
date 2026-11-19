`timescale 1ns/1ps
// Prueba el tablero en registros: carga del nivel, lectura, ocupacion de columna, escritura y reinicio.
module tablero_tb;
    reg  reloj = 1'b0, reinicio = 1'b1;
    always #5 reloj = ~reloj;

    wire [511:0] nivel_inicial;
    reg  [7:0]   dir_lect = 8'd0;
    wire [1:0]   dato_lect;
    reg  [7:0]   dir_arriba = 8'd0;
    wire [1:0]   dato_arriba;
    reg  [3:0]   col_consulta = 4'd0;
    wire [9:0]   ocupada;
    reg          hab_escr = 1'b0;
    reg  [7:0]   dir_escr = 8'd0;
    reg  [1:0]   dato_escr = 2'b00;
    integer errores = 0;

    rom_nivel u_rom (.nivel(2'd2), .todas_celdas(nivel_inicial));   // nivel 3 (el original)
    wire         vacio;
    tablero dut (.reloj(reloj), .reinicio(reinicio), .contenido_inicial(nivel_inicial),
               .dir_lect(dir_lect), .dato_lect(dato_lect), .dir_arriba(dir_arriba), .dato_arriba(dato_arriba),
               .col_consulta(col_consulta), .ocupada(ocupada),
               .hab_escr(hab_escr), .dir_escr(dir_escr), .dato_escr(dato_escr),
               .vacio(vacio));

    task revisar_celda(input [3:0] f, input [3:0] c, input [1:0] e, input [8*40-1:0] mensaje);
    begin
        dir_lect = {f, c}; #1;
        if (dato_lect === e) $display("[PASS] %0s: celda (%0d,%0d) = %b", mensaje, f, c, dato_lect);
        else begin errores = errores + 1; $display("[FAIL] %0s: celda (%0d,%0d) = %b, esperado %b", mensaje, f, c, dato_lect, e); end
    end
    endtask

    task revisar_ocupacion(input [3:0] c, input [9:0] e, input [8*40-1:0] mensaje);
    begin
        col_consulta = c; #1;
        if (ocupada === e) $display("[PASS] %0s: columna %0d ocupada = %b", mensaje, c, ocupada);
        else begin errores = errores + 1; $display("[FAIL] %0s: columna %0d ocupada = %b, esperado %b", mensaje, c, ocupada, e); end
    end
    endtask

    initial begin
        repeat (2) @(negedge reloj);
        reinicio = 1'b0;
        @(negedge reloj);
        // nivel 1: fila 0 = R R V V A A V V R R
        revisar_celda(0, 0, 2'b01, "1. carga inicial");
        revisar_celda(0, 2, 2'b10, "2. carga inicial");
        revisar_celda(0, 4, 2'b11, "3. carga inicial");
        revisar_celda(3, 0, 2'b00, "4. celda vacia");
        revisar_ocupacion(0, 10'b0000000111, "5. ocupacion");
        revisar_ocupacion(2, 10'b0000011111, "6. ocupacion");
        revisar_ocupacion(4, 10'b0000001111, "7. ocupacion");
        dir_arriba = {4'd0, 4'd4}; #1;
        if (dato_arriba === 2'b11) $display("[PASS] 7b. tercer puerto: celda (0,4) = 11");
        else begin errores = errores + 1; $display("[FAIL] 7b. tercer puerto: celda (0,4) = %b, esperado 11", dato_arriba); end
        // escritura
        dir_escr = {4'd3, 4'd0}; dato_escr = 2'b11; hab_escr = 1'b1;
        @(negedge reloj); hab_escr = 1'b0;
        revisar_celda(3, 0, 2'b11, "8. despues de escribir");
        revisar_ocupacion(0, 10'b0000001111, "9. ocupacion actualizada");
        revisar_celda(3, 1, 2'b11, "10. la vecina no cambia (A)");
        // reinicio recarga el nivel
        reinicio = 1'b1; @(negedge reloj); reinicio = 1'b0; @(negedge reloj);
        revisar_celda(3, 0, 2'b00, "11. reinicio recarga el nivel");

        if (vacio === 1'b0) $display("[PASS] 12. con burbujas: vacio = 0");
        else begin errores = errores + 1; $display("[FAIL] 12. vacio = %b, esperado 0", vacio); end

        if (errores == 0) $display("RESULTADO FINAL tablero_tb: PASS");
        else             $display("RESULTADO FINAL tablero_tb: FAIL (%0d errores)", errores);
        $finish;
    end
endmodule
