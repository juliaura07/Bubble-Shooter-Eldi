`timescale 1ns/1ps
// Sincronia VGA 640x480 @ ~60 Hz. Contadores cont_h (columna x) y cont_v (fila y).
module sincronia_vga (
    input  wire       reloj,
    input  wire       reinicio,
    input  wire       hab_pixel,              // permiso: avanzar un pixel
    output wire       sinc_h,               // activo en bajo
    output wire       sinc_v,               // activo en bajo
    output wire       video_activo,            // 1 en la zona visible
    output wire [9:0] x,
    output wire [9:0] y,
    output wire       pulso_cuadro           // 1 ciclo por cuadro
);
    reg  [9:0] cont_h, cont_v;

    // comparadores de fin de cuenta
    wire fin_h = (cont_h == 10'd799);
    wire fin_v = (cont_v == 10'd524);

    // MUX 2:1 + sumador: si es el final carga 0, si no carga +1
    wire [9:0] cont_h_sig = fin_h ? 10'd0 : cont_h + 10'd1;
    wire [9:0] cont_v_sig = fin_v ? 10'd0 : cont_v + 10'd1;

    // enables
    wire hab_h = hab_pixel;
    wire hab_v = hab_pixel & fin_h;            // AND: una vez por linea

    always @(posedge reloj) begin
        if (reinicio) begin
            cont_h <= 10'd0;
            cont_v <= 10'd0;
        end else begin
            if (hab_h) cont_h <= cont_h_sig;
            if (hab_v) cont_v <= cont_v_sig;
        end
    end

    // decodificadores de salida
    assign sinc_h      = ~((cont_h >= 10'd656) && (cont_h < 10'd752));
    assign sinc_v      = ~((cont_v >= 10'd490) && (cont_v < 10'd492));
    assign video_activo   =  (cont_h <  10'd640)  && (cont_v < 10'd480);
    assign pulso_cuadro = hab_pixel && (cont_h == 10'd0) && (cont_v == 10'd480);
    assign x = cont_h;
    assign y = cont_v;
endmodule
