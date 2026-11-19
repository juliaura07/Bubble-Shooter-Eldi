`timescale 1ns/1ps
// Sincronizador (2 FF) + antirrebote por contador para UN boton.
// con_ruido: 1 = presionado. limpia cambia solo si con_ruido se mantiene 2^ANCHO ciclos.
module antirrebote #(
    parameter ANCHO = 20                       // 2^20 ciclos = ~10.5 ms a 100 MHz
)(
    input  wire reloj,
    input  wire reinicio,
    input  wire con_ruido,
    output reg  limpia
);
    reg          d1, d2;                   // sincronizador
    reg  [ANCHO-1:0] cuenta;

    wire         distinto     = (d2 != limpia);                   // comparador "distinto"
    wire         lleno     = &cuenta;                            // comparador "todos unos"
    wire [ANCHO-1:0] cuenta_sig = distinto ? cuenta + 1'b1 : {ANCHO{1'b0}};   // MUX: cuenta o limpia
    wire         hab_limpia = distinto & lleno;                     // enable de limpia

    always @(posedge reloj) begin
        if (reinicio) begin
            d1    <= 1'b0;
            d2    <= 1'b0;
            cuenta   <= {ANCHO{1'b0}};
            limpia <= 1'b0;
        end else begin
            d1  <= con_ruido;
            d2  <= d1;
            cuenta <= cuenta_sig;
            if (hab_limpia) limpia <= d2;
        end
    end
endmodule
