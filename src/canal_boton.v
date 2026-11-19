`timescale 1ns/1ps
// Un canal de boton: antirrebote + detector de flanco de subida.
module canal_boton #(
    parameter ANCHO = 20
)(
    input  wire reloj,
    input  wire reinicio,
    input  wire boton_n,                     // pulsador activo en bajo (0 = presionado)
    output wire nivel,                     // 1 mientras esta presionado (limpio)
    output wire flanco                       // pulso de 1 ciclo al presionar
);
    reg anterior;

    antirrebote #(.ANCHO(ANCHO)) u_antirrebote (.reloj(reloj), .reinicio(reinicio), .con_ruido(~boton_n), .limpia(nivel));

    always @(posedge reloj) begin
        if (reinicio) anterior <= 1'b0;
        else       anterior <= nivel;
    end

    assign flanco = nivel & ~anterior;           // AND con entrada negada
endmodule
