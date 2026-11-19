`timescale 1ns/1ps
// Divisor entre 4: 100 MHz -> hab_pixel = 1 un ciclo de cada 4 (25 MHz)
module divisor_reloj (
    input  wire reloj,
    input  wire reinicio,
    output wire hab_pixel
);
    reg  [1:0] cuenta;
    wire [1:0] cuenta_sig = cuenta + 2'd1;      // sumador +1 (se desborda solo: 3 -> 0)

    always @(posedge reloj) begin
        if (reinicio) cuenta <= 2'd0;
        else       cuenta <= cuenta_sig;
    end

    assign hab_pixel = (cuenta == 2'd3);         // comparador = 3
endmodule
