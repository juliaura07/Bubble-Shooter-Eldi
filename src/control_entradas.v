`timescale 1ns/1ps
// Control: 3 pulsadores + 1 switch -> pulsos de 1 ciclo y niveles limpios para los LEDs.
// Si izquierda y derecha estan presionadas a la vez, no se mueve.
module control_entradas #(
    parameter ANCHO = 20
)(
    input  wire       reloj,
    input  wire       reinicio,
    input  wire       boton_izq,            // pulsadores activos en bajo (0 = presionado)
    input  wire       boton_der,
    input  wire       boton_disparo,
    input  wire       interruptor_color,            // switch activo en alto (arriba = 1)
    output wire       pulso_izq,
    output wire       pulso_der,
    output wire       pulso_disparo,         // reservado para el avance 2
    output wire       pulso_color,         // 1 ciclo cada vez que el switch sube
    output wire [3:0] niveles               // {switch, disparo, derecha, izquierda} limpios
);
    wire nivel_i, flanco_i, nivel_d, flanco_d, nivel_disp, flanco_disp, nivel_col, flanco_col;

    canal_boton #(.ANCHO(ANCHO)) u_izq (.reloj(reloj), .reinicio(reinicio), .boton_n(boton_izq),  .nivel(nivel_i), .flanco(flanco_i));
    canal_boton #(.ANCHO(ANCHO)) u_der (.reloj(reloj), .reinicio(reinicio), .boton_n(boton_der), .nivel(nivel_d), .flanco(flanco_d));
    canal_boton #(.ANCHO(ANCHO)) u_disp (.reloj(reloj), .reinicio(reinicio), .boton_n(boton_disparo), .nivel(nivel_disp), .flanco(flanco_disp));
    // el switch es activo en alto: se invierte para usar el mismo canal
    canal_boton #(.ANCHO(ANCHO)) u_col (.reloj(reloj), .reinicio(reinicio), .boton_n(~interruptor_color), .nivel(nivel_col), .flanco(flanco_col));

    assign pulso_izq  = flanco_i & ~nivel_d;    // se cancela si derecha esta presionada
    assign pulso_der = flanco_d & ~nivel_i;
    assign pulso_disparo = flanco_disp;
    assign pulso_color = flanco_col;               // flanco de subida del switch
    assign niveles      = {nivel_col, nivel_disp, nivel_d, nivel_i};
endmodule
