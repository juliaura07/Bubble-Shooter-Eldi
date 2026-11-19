`timescale 1ns/1ps
// Diseno completo: VGA + control + tablero en registros + canon + disparo con FSM
// (agrupar, o eliminar la cadena vertical del mismo color), 3 niveles, PERDISTE y puntaje.
// SW0 tambien cambia el color de la burbuja del canon (modo de prueba).
module juego #(
    parameter ANCHO_ANTIRREBOTE = 20                   // 4 en simulacion
)(
    input  wire       reloj,                 // 100 MHz
    input  wire       reinicio,               // activo en alto
    input  wire       boton_izq,            // activos en bajo
    input  wire       boton_der,
    input  wire       boton_disparo,
    input  wire       interruptor_color,            // activo en alto
    output wire       sinc_h,
    output wire       sinc_v,
    output wire [3:0] vga_rojo,
    output wire [3:0] vga_verde,
    output wire [3:0] vga_azul,
    output wire [9:0] leds,
    output wire [6:0] seg,                // displays de 7 segmentos
    output wire       dp,
    output wire [7:0] an
);
    wire         hab_pixel, video_activo, pulso_cuadro;
    wire [9:0]   x, y;
    wire         pulso_izq, pulso_der, pulso_disparo, pulso_color;
    wire [3:0]   niveles;
    wire [3:0]   columna_canon, indice_sec;
    wire [1:0]   color_siguiente, dato_celda;
    wire [7:0]   dir_tablero;
    wire [511:0] nivel_inicial;
    wire [9:0]   ocupada;
    wire         lanzar, bola_activa;
    wire [3:0]   col_bola;
    wire [9:0]   y_bola;
    wire [1:0]   color_bola;
    wire         tablero_hab_escr;
    wire [7:0]   tablero_dir_escr;
    wire [1:0]   tablero_dato_escr;
    wire [7:0]   dir_arriba_bola;
    wire [1:0]   color_arriba;
    wire         elimina, pierde, tablero_vacio;
    wire [1:0]   nivel, nivel_a_cargar;
    wire         cargar_nivel, perdido;
    wire [3:0]   decenas, centenas, miles;
    // el tablero y la secuencia de colores se recargan al reiniciar o al pasar de nivel
    wire         reinicio_nivel = reinicio | cargar_nivel;
    // con PERDISTE en pantalla ya no se puede disparar
    wire         disparo_permitido = pulso_disparo & ~perdido;

    divisor_reloj u_divisor (.reloj(reloj), .reinicio(reinicio), .hab_pixel(hab_pixel));

    sincronia_vga u_vga (
        .reloj(reloj), .reinicio(reinicio), .hab_pixel(hab_pixel),
        .sinc_h(sinc_h), .sinc_v(sinc_v), .video_activo(video_activo),
        .x(x), .y(y), .pulso_cuadro(pulso_cuadro)
    );

    control_entradas #(.ANCHO(ANCHO_ANTIRREBOTE)) u_entradas (
        .reloj(reloj), .reinicio(reinicio),
        .boton_izq(boton_izq), .boton_der(boton_der), .boton_disparo(boton_disparo),
        .interruptor_color(interruptor_color),
        .pulso_izq(pulso_izq), .pulso_der(pulso_der),
        .pulso_disparo(pulso_disparo), .pulso_color(pulso_color),
        .niveles(niveles)
    );

    control_canon u_canon (
        .reloj(reloj), .reinicio(reinicio),
        .pulso_izq(pulso_izq), .pulso_der(pulso_der), .columna(columna_canon)
    );

    // la secuencia avanza al disparar o al subir el switch
    siguiente_burbuja u_siguiente (
        .reloj(reloj), .reinicio(reinicio_nivel), .pulso_disparo(lanzar | pulso_color),
        .indice(indice_sec), .color(color_siguiente)
    );

    // nivel inicial (ROM) y tablero de juego (registros)
    rom_nivel u_rom (.nivel(nivel_a_cargar), .todas_celdas(nivel_inicial));

    tablero u_tablero (
        .reloj(reloj), .reinicio(reinicio_nivel), .contenido_inicial(nivel_inicial),
        .dir_lect(dir_tablero), .dato_lect(dato_celda),
        .dir_arriba(dir_arriba_bola), .dato_arriba(color_arriba),
        .col_consulta(col_bola), .ocupada(ocupada),
        .hab_escr(tablero_hab_escr), .dir_escr(tablero_dir_escr), .dato_escr(tablero_dato_escr),
        .vacio(tablero_vacio)
    );

    control_disparo u_bola (
        .reloj(reloj), .reinicio(reinicio), .pulso_cuadro(pulso_cuadro), .pulso_disparo(disparo_permitido),
        .columna_canon(columna_canon), .color_siguiente(color_siguiente), .ocupada(ocupada),
        .color_arriba(color_arriba),
        .activa(bola_activa), .col_bola(col_bola), .y_bola(y_bola), .color_bola(color_bola),
        .lanzar(lanzar), .dir_arriba_bola(dir_arriba_bola),
        .hab_escr(tablero_hab_escr), .dir_escr(tablero_dir_escr), .dato_escr(tablero_dato_escr), .elimina(elimina),
        .pierde(pierde)
    );

    control_juego u_control_juego (
        .reloj(reloj), .reinicio(reinicio),
        .tablero_vacio(tablero_vacio), .bola_activa(bola_activa),
        .pierde(pierde), .elimina(elimina),
        .nivel(nivel), .nivel_a_cargar(nivel_a_cargar), .cargar_nivel(cargar_nivel),
        .perdido(perdido), .decenas(decenas), .centenas(centenas), .miles(miles)
    );

    displays_7seg #(.ANCHO(17)) u_displays (
        .reloj(reloj), .reinicio(reinicio),
        .nivel(nivel), .miles(miles), .centenas(centenas), .decenas(decenas),
        .seg(seg), .dp(dp), .an(an)
    );

    generador_pixel u_pixel (
        .video_activo(video_activo), .x(x), .y(y),
        .columna_canon(columna_canon), .color_siguiente(color_siguiente),
        .bola_activa(bola_activa), .col_bola(col_bola), .y_bola(y_bola), .color_bola(color_bola),
        .perdido(perdido),
        .dir_tablero(dir_tablero), .dato_celda(dato_celda),
        .vga_rojo(vga_rojo), .vga_verde(vga_verde), .vga_azul(vga_azul)
    );

    // LD0-LD3: columna | LD4 izq, LD5 der, LD6 disparo, LD7 switch | LD8-LD9: color del canon
    assign leds = {color_siguiente, niveles, columna_canon};
endmodule
