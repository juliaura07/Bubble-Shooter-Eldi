`timescale 1ns/1ps
// Generador de pixel (100% combinacional, solo assign).
// Tablero 10x10 de celdas de 32 px en x = 160..479, y = 32..351.
// Canon en la columna columna_canon, centro y = 432, con su base debajo.
module generador_pixel (
    input  wire       video_activo,
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [3:0] columna_canon,          // columna del canon (0..9)
    input  wire [1:0] color_siguiente,          // color de la burbuja cargada
    input  wire       bola_activa,         // hay una bola volando
    input  wire [3:0] col_bola,            // su columna
    input  wire [9:0] y_bola,              // su altura (centro)
    input  wire [1:0] color_bola,          // su color
    input  wire       perdido,             // muestra el texto PERDISTE
    output wire [7:0] dir_tablero,            // direccion hacia la ROM del nivel
    input  wire [1:0] dato_celda,                // dato que devuelve la ROM
    output wire [3:0] vga_rojo,
    output wire [3:0] vga_verde,
    output wire [3:0] vga_azul
);
    // ---- celda de pantalla (32x32): bits altos de x e y ----
    wire [4:0] col_pant = x[9:5];                // columna de pantalla 0..19
    wire [4:0] fila_pant = y[9:5];                // fila de pantalla 0..14

    // ---- dentro del tablero: columnas 5..14 y filas 1..10 (comparadores) ----
    wire en_tablero = (col_pant >= 5'd5) && (col_pant <= 5'd14) && (fila_pant >= 5'd1) && (fila_pant <= 5'd10);

    // ---- direccion de la ROM: restadores + concatenacion {fila, columna} ----
    wire [4:0] col_tab = col_pant - 5'd5;
    wire [4:0] fila_tab = fila_pant - 5'd1;
    assign dir_tablero = {fila_tab[3:0], col_tab[3:0]};

    // ---- burbuja del tablero: circulo centrado en la celda actual ----
    wire [9:0] centro_x_celda = {col_pant, 5'd16};
    wire [9:0] centro_y_celda = {fila_pant, 5'd16};
    wire en_celda;
    dentro_circulo #(.R(15)) u_celda (.px(x), .py(y), .cx(centro_x_celda), .cy(centro_y_celda), .dentro(en_celda));
    wire en_burbuja_tablero = en_tablero && en_celda && (dato_celda != 2'b00);

    // ---- burbuja del canon ----
    wire [4:0] col_pant_canon = {1'b0, columna_canon} + 5'd5;    // columna de pantalla del canon
    wire [9:0] centro_x_canon  = {col_pant_canon, 5'd16};                 // centro x del canon
    wire [9:0] centro_y_canon  = 10'd432;                      // centro y del canon
    wire en_canon;
    dentro_circulo #(.R(15)) u_canon (.px(x), .py(y), .cx(centro_x_canon), .cy(centro_y_canon), .dentro(en_canon));

    // ---- bola disparada ----
    wire [4:0] col_pant_bola = {1'b0, col_bola} + 5'd5;      // columna de pantalla de la bola
    wire [9:0] centro_x_bola = {col_pant_bola, 5'd16};                 // centro x de la bola
    wire en_bola_bruto;
    dentro_circulo #(.R(15)) u_bola (.px(x), .py(y), .cx(centro_x_bola), .cy(y_bola), .dentro(en_bola_bruto));
    wire en_bola = bola_activa && en_bola_bruto;

    // ---- base del canon (rectangulo 25x10) y paredes del tablero ----
    wire en_base = (x + 10'd12 >= centro_x_canon) && (x <= centro_x_canon + 10'd12) && (y >= 10'd452) && (y < 10'd462);
    wire en_pared = (y >= 10'd32) && (y < 10'd472) &&
                   (((x >= 10'd154) && (x < 10'd160)) || ((x >= 10'd480) && (x < 10'd486)));

    // ---- texto PERDISTE: 8 letras en la fila de pantalla 6, columnas 6..13 ----
    // ROM de 512 bits = 8 letras x 8 filas x 8 columnas; cada bit se ve como un
    // cuadro de 4x4 pixeles, asi que cada letra ocupa exactamente una celda de 32x32.
    // Bit de la letra p, fila f, columna c: TEXTO[{p, f, c}] = TEXTO[p*64 + f*8 + c].
    localparam [511:0] TEXTO = 512'h007f03033f03037f001818181818187f003e63603e03633e007e18181818187e001f33636363331f0063331b3f63633f007f03033f03037f000303033f63633f;
    wire       en_banda   = perdido && (fila_pant >= 5'd5) && (fila_pant <= 5'd7) &&
                            (col_pant >= 5'd5) && (col_pant <= 5'd14);      // franja negra detras
    wire       en_renglon = perdido && (fila_pant == 5'd6) &&
                            (col_pant >= 5'd6) && (col_pant <= 5'd13);
    wire [4:0] letra      = col_pant - 5'd6;                                 // 0..7: P E R D I S T E
    wire [8:0] dir_texto  = {letra[2:0], y[4:2], x[4:2]};                    // {letra, fila, columna}
    wire       en_letra   = en_renglon && TEXTO[dir_texto];

    // ---- codigo de color (cadena de MUX con prioridad) ----
    //   prioridad: letra > franja > bola disparada > canon > tablero > gris > fondo
    //   0 fondo, 1 rojo, 2 verde, 3 azul, 4 gris, 5 blanco, 6 negro
    wire [2:0] codigo = en_letra             ? 3'd5 :
                      en_banda             ? 3'd6 :
                      en_bola             ? {1'b0, color_bola} :
                      en_canon           ? {1'b0, color_siguiente} :
                      en_burbuja_tablero            ? {1'b0, dato_celda}       :
                      (en_base || en_pared) ? 3'd4               :
                                             3'd0;

    // ---- paleta: LUT de 8 x 12 bits (vector constante, color 0 en los bits bajos) ----
    localparam [95:0] PALETA = {12'h000, 12'h000, 12'hFFF, 12'h888,
                                 12'h00F, 12'h0F0, 12'hF00, 12'h004};
    wire [6:0]  pos_paleta = {4'b0000, codigo} * 7'd12;     // posicion = codigo*12
    wire [11:0] rgb     = PALETA[pos_paleta +: 12];

    // ---- MUX final: negro fuera de la zona visible ----
    assign {vga_rojo, vga_verde, vga_azul} = video_activo ? rgb : 12'h000;
endmodule
