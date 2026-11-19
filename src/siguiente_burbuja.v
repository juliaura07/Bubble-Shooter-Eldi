`timescale 1ns/1ps
// Burbuja que tiene cargada el canon: contador de 4 bits que avanza en cada disparo
// y una LUT (vector constante) con la secuencia de 16 colores del nivel.
// Colores: 01 = rojo, 10 = verde, 11 = azul. La entrada 0 son los bits [1:0].
module siguiente_burbuja (
    input  wire       reloj,
    input  wire       reinicio,
    input  wire       pulso_disparo,
    output reg  [3:0] indice,
    output wire [1:0] color
);
    // secuencia (de la entrada 15 a la 0):
    //   15:A 14:V 13:R 12:A 11:V 10:R 9:A 8:A 7:V 6:V 5:R 4:R 3:A 2:R 1:V 0:R
    localparam [31:0] SECUENCIA = {2'b11, 2'b10, 2'b01, 2'b11, 2'b10, 2'b01, 2'b11, 2'b11,
                             2'b10, 2'b10, 2'b01, 2'b01, 2'b11, 2'b01, 2'b10, 2'b01};

    wire [3:0] indice_sig = pulso_disparo ? indice + 4'd1 : indice;   // MUX + sumador

    always @(posedge reloj) begin
        if (reinicio) indice <= 4'd0;
        else       indice <= indice_sig;
    end

    assign color = SECUENCIA[{indice, 1'b0} +: 2];  // LUT: toma 2 bits en la posicion indice*2
endmodule
