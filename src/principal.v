`timescale 1ns/1ps
// Modulo superior para la Nexys A7 / Nexys 4 DDR.
// Adapta los botones y el reinicio de la placa al diseno juego.
//   BOTON_ACTIVO_BAJO = 0 : botones de la placa (BTNL, BTNR, BTNC), activos en alto
//   BOTON_ACTIVO_BAJO = 1 : pulsadores externos en el Pmod JA, activos en bajo
module principal #(
    parameter BOTON_ACTIVO_BAJO = 1,          // 1 = pulsadores del Pmod JA (reinicio_encendido defecto)
    parameter ANCHO_ANTIRREBOTE          = 20          // antirrebote: 2^20 ciclos = ~10.5 ms
)(
    input  wire       CLK100MHZ,           // reloj de 100 MHz de la placa
    input  wire       CPU_RESETN,          // boton rojo CPU RESET (activo en bajo)
    input  wire       boton_izq,
    input  wire       boton_der,
    input  wire       boton_disparo,
    input  wire       SW0,                 // switch: cambia el color al subir
    output wire       VGA_HS,
    output wire       VGA_VS,
    output wire [3:0] VGA_R,
    output wire [3:0] VGA_G,
    output wire [3:0] VGA_B,
    output wire [9:0] LED,                 // ver asignacion en juego
    output wire [6:0] SEG,                 // segmentos {CG..CA} de los displays
    output wire       DP,
    output wire [7:0] AN                   // anodos de los 8 digitos
);
    // Reset de encendido: registro de desplazamiento de 4 bits que arranca en 1111
    // al programar la FPGA y se va llenando de ceros. Mantiene el reinicio activo
    // los primeros 4 ciclos para que el tablero cargue el nivel solo.
    reg [3:0] reinicio_encendido = 4'b1111;
    always @(posedge CLK100MHZ) reinicio_encendido <= {reinicio_encendido[2:0], 1'b0};

    // reinicio del diseno (activo en alto): al encender o con el boton CPU RESET
    wire reinicio = reinicio_encendido[3] | ~CPU_RESETN;

    // juego espera los botones activos en bajo (0 = presionado)
    wire izq_n  = (BOTON_ACTIVO_BAJO != 0) ? boton_izq  : ~boton_izq;
    wire der_n = (BOTON_ACTIVO_BAJO != 0) ? boton_der : ~boton_der;
    wire disp_n = (BOTON_ACTIVO_BAJO != 0) ? boton_disparo : ~boton_disparo;

    juego #(.ANCHO_ANTIRREBOTE(ANCHO_ANTIRREBOTE)) u_juego (
        .reloj(CLK100MHZ), .reinicio(reinicio),
        .boton_izq(izq_n), .boton_der(der_n), .boton_disparo(disp_n),
        .interruptor_color(SW0),
        .sinc_h(VGA_HS), .sinc_v(VGA_VS),
        .vga_rojo(VGA_R), .vga_verde(VGA_G), .vga_azul(VGA_B),
        .leds(LED),
        .seg(SEG), .dp(DP), .an(AN)
    );
endmodule
