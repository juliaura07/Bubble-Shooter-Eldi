// pantalla final (canon por columnas + botones + burbuja cargada)
`default_nettype none

// Sincronia VGA 640x480 @ ~60 Hz. Contadores hcnt (columna x) y vcnt (fila y).
module vga_sync (
    input  wire       clk,
    input  wire       reset,
    input  wire       pix_en,              // permiso: avanzar un pixel
    output wire       hsync,               // activo en bajo
    output wire       vsync,               // activo en bajo
    output wire       video_on,            // 1 en la zona visible
    output wire [9:0] x,
    output wire [9:0] y,
    output wire       frame_tick           // 1 ciclo por cuadro
);
    reg  [9:0] hcnt, vcnt;

    // comparadores de fin de cuenta
    wire h_end = (hcnt == 10'd799);
    wire v_end = (vcnt == 10'd524);

    // MUX 2:1 + sumador: si es el final carga 0, si no carga +1
    wire [9:0] hcnt_next = h_end ? 10'd0 : hcnt + 10'd1;
    wire [9:0] vcnt_next = v_end ? 10'd0 : vcnt + 10'd1;

    // enables
    wire h_en = pix_en;
    wire v_en = pix_en & h_end;            // AND: una vez por linea

    always @(posedge clk) begin
        if (reset) begin
            hcnt <= 10'd0;
            vcnt <= 10'd0;
        end else begin
            if (h_en) hcnt <= hcnt_next;
            if (v_en) vcnt <= vcnt_next;
        end
    end

    // decodificadores de salida
    assign hsync      = ~((hcnt >= 10'd656) && (hcnt < 10'd752));
    assign vsync      = ~((vcnt >= 10'd490) && (vcnt < 10'd492));
    assign video_on   =  (hcnt <  10'd640)  && (vcnt < 10'd480);
    assign frame_tick = pix_en && (hcnt == 10'd0) && (vcnt == 10'd480);
    assign x = hcnt;
    assign y = vcnt;
endmodule

// Sincronizador (2 FF) + antirrebote por contador para UN boton.
// noisy: 1 = presionado. clean cambia solo si noisy se mantiene 2^W ciclos.
module debounce #(
    parameter W = 20                       // 2^20 ciclos = ~10.5 ms a 100 MHz
)(
    input  wire clk,
    input  wire reset,
    input  wire noisy,
    output reg  clean
);
    reg          d1, d2;                   // sincronizador
    reg  [W-1:0] cnt;

    wire         diff     = (d2 != clean);                   // comparador "distinto"
    wire         full     = &cnt;                            // comparador "todos unos"
    wire [W-1:0] cnt_next = diff ? cnt + 1'b1 : {W{1'b0}};   // MUX: cuenta o limpia
    wire         clean_en = diff & full;                     // enable de clean

    always @(posedge clk) begin
        if (reset) begin
            d1    <= 1'b0;
            d2    <= 1'b0;
            cnt   <= {W{1'b0}};
            clean <= 1'b0;
        end else begin
            d1  <= noisy;
            d2  <= d1;
            cnt <= cnt_next;
            if (clean_en) clean <= d2;
        end
    end
endmodule

// Un canal de boton: antirrebote + detector de flanco de subida.
module btn_channel #(
    parameter W = 20
)(
    input  wire clk,
    input  wire reset,
    input  wire btn_n,                     // pulsador activo en bajo (0 = presionado)
    output wire level,                     // 1 mientras esta presionado (limpio)
    output wire rise                       // pulso de 1 ciclo al presionar
);
    reg prev;

    debounce #(.W(W)) u_deb (.clk(clk), .reset(reset), .noisy(~btn_n), .clean(level));

    always @(posedge clk) begin
        if (reset) prev <= 1'b0;
        else       prev <= level;
    end

    assign rise = level & ~prev;           // AND con entrada negada
endmodule

// Control propio: 3 pulsadores -> 3 pulsos (1 ciclo por pulsacion).
// Si izquierda y derecha estan presionadas a la vez, no se mueve.
module input_ctrl #(
    parameter W = 20
)(
    input  wire clk,
    input  wire reset,
    input  wire btn_left,                  // activo en bajo
    input  wire btn_right,
    input  wire btn_shoot,
    output wire left_pulse,
    output wire right_pulse,
    output wire shoot_pulse
);
    wire l_level, l_rise, r_level, r_rise, s_level, s_rise;

    btn_channel #(.W(W)) u_l (.clk(clk), .reset(reset), .btn_n(btn_left),  .level(l_level), .rise(l_rise));
    btn_channel #(.W(W)) u_r (.clk(clk), .reset(reset), .btn_n(btn_right), .level(r_level), .rise(r_rise));
    btn_channel #(.W(W)) u_s (.clk(clk), .reset(reset), .btn_n(btn_shoot), .level(s_level), .rise(s_rise));

    assign left_pulse  = l_rise & ~r_level;    // se cancela si derecha esta presionada
    assign right_pulse = r_rise & ~l_level;
    assign shoot_pulse = s_rise;
endmodule

// Columna del canon: contador up/down de 4 bits con saturacion (0 .. NCOLS-1).
// Se mueve 1 columna por pulsacion.
module cannon_ctrl #(
    parameter [3:0] NCOLS = 4'd10,
    parameter [3:0] INIT  = 4'd4
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       left_pulse,
    input  wire       right_pulse,
    output reg  [3:0] col
);
    wire at_left  = (col == 4'd0);                 // comparador = 0
    wire at_right = (col == NCOLS - 4'd1);         // comparador = 9
    wire mv_left  = left_pulse  & ~at_left;
    wire mv_right = right_pulse & ~at_right;

    // MUX 3:1 con prioridad: col-1 / col+1 / col
    wire [3:0] col_next = mv_left  ? col - 4'd1 :
                          mv_right ? col + 4'd1 :
                                     col;

    always @(posedge clk) begin
        if (reset) col <= INIT;
        else       col <= col_next;
    end
endmodule

// Burbuja que tiene cargada el canon: contador de 4 bits que avanza en cada disparo
// y una LUT (vector constante) con la secuencia de 16 colores del nivel.
// Colores: 01 = rojo, 10 = verde, 11 = azul. La entrada 0 son los bits [1:0].
module next_bubble (
    input  wire       clk,
    input  wire       reset,
    input  wire       shoot_pulse,
    output reg  [3:0] idx,
    output wire [1:0] color
);
    // secuencia (de la entrada 15 a la 0):
    //   15:A 14:V 13:R 12:A 11:V 10:R 9:A 8:A 7:V 6:V 5:R 4:R 3:A 2:R 1:V 0:R
    localparam [31:0] SEQ = {2'b11, 2'b10, 2'b01, 2'b11, 2'b10, 2'b01, 2'b11, 2'b11,
                             2'b10, 2'b10, 2'b01, 2'b01, 2'b11, 2'b01, 2'b10, 2'b01};

    wire [3:0] idx_next = shoot_pulse ? idx + 4'd1 : idx;   // MUX + sumador

    always @(posedge clk) begin
        if (reset) idx <= 4'd0;
        else       idx <= idx_next;
    end

    assign color = SEQ[{idx, 1'b0} +: 2];  // LUT: toma 2 bits en la posicion idx*2
endmodule

// hit = 1 si (px-cx)^2 + (py-cy)^2 <= R^2
module circle_hit #(
    parameter integer R = 15
)(
    input  wire [9:0] px,
    input  wire [9:0] py,
    input  wire [9:0] cx,
    input  wire [9:0] cy,
    output wire       hit
);
    localparam signed [10:0] RS = R;
    localparam signed [14:0] R2 = R * R;

    // restadores con signo
    wire signed [10:0] dx = $signed({1'b0, px}) - $signed({1'b0, cx});
    wire signed [10:0] dy = $signed({1'b0, py}) - $signed({1'b0, cy});

    // caja: solo dentro de ella |dx|,|dy| <= R (y alcanzan 7 bits)
    wire in_box = (dx >= -RS) && (dx <= RS) && (dy >= -RS) && (dy <= RS);

    wire signed [14:0] dxe = $signed(dx[6:0]);   // extension de signo a 15 bits
    wire signed [14:0] dye = $signed(dy[6:0]);

    // multiplicadores (cuadrados) + sumador + comparador
    wire signed [14:0] dx2 = dxe * dxe;
    wire signed [14:0] dy2 = dye * dye;
    wire signed [14:0] d2  = dx2 + dy2;

    assign hit = in_box && (d2 <= R2);
endmodule

// ROM del nivel implementada como LUT: vector constante de 256 celdas x 2 bits.
// Generado por scripts/level2verilog.py a partir de levels/nivel1.txt
//   . = 00 vacio   R = 01 rojo   V = 10 verde   A = 11 azul
    //   R R V V A A V V R R
    //   R V V A A A A V V R
    //   V V A A R R A A V V
    //   . A A R R R R A A .
    //   . . R R . . R R . .
    //   . . . . . . . . . .
    //   . . . . . . . . . .
    //   . . . . . . . . . .
    //   . . . . . . . . . .
    //   . . . . . . . . . .
module level_rom (
    input  wire [7:0] addr,                // {fila[3:0], columna[3:0]}
    output wire [1:0] cell_data
);
    localparam [511:0] LEVEL = 512'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050500003d57c000af5fa0006bfe90005afa5;

    assign cell_data = LEVEL[{addr, 1'b0} +: 2];   // posicion addr*2 (desplazamiento, sin multiplicador)
endmodule

// Generador de pixel (100% combinacional, solo assign).
// Tablero 10x10 de celdas de 32 px en x = 160..479, y = 32..351.
// Canon en la columna cannon_col, centro y = 432, con su base debajo.
module pixel_gen (
    input  wire       video_on,
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [3:0] cannon_col,          // columna del canon (0..9)
    input  wire [1:0] next_color,          // color de la burbuja cargada
    output wire [7:0] rom_addr,            // direccion hacia la ROM del nivel
    input  wire [1:0] cell_data,                // dato que devuelve la ROM
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b
);
    // ---- celda de pantalla (32x32): bits altos de x e y ----
    wire [4:0] sc = x[9:5];                // columna de pantalla 0..19
    wire [4:0] sr = y[9:5];                // fila de pantalla 0..14

    // ---- dentro del tablero: columnas 5..14 y filas 1..10 (comparadores) ----
    wire in_board = (sc >= 5'd5) && (sc <= 5'd14) && (sr >= 5'd1) && (sr <= 5'd10);

    // ---- direccion de la ROM: restadores + concatenacion {fila, columna} ----
    wire [4:0] col5 = sc - 5'd5;
    wire [4:0] row5 = sr - 5'd1;
    assign rom_addr = {row5[3:0], col5[3:0]};

    // ---- burbuja del tablero: circulo centrado en la celda actual ----
    wire [9:0] ccx = {sc, 5'd16};
    wire [9:0] ccy = {sr, 5'd16};
    wire hit_cell;
    circle_hit #(.R(15)) u_cell (.px(x), .py(y), .cx(ccx), .cy(ccy), .hit(hit_cell));
    wire hit_board = in_board && hit_cell && (cell_data != 2'b00);

    // ---- burbuja del canon ----
    wire [4:0] csc = {1'b0, cannon_col} + 5'd5;    // columna de pantalla del canon
    wire [9:0] kx  = {csc, 5'd16};                 // centro x del canon
    wire [9:0] ky  = 10'd432;                      // centro y del canon
    wire hit_cannon;
    circle_hit #(.R(15)) u_can (.px(x), .py(y), .cx(kx), .cy(ky), .hit(hit_cannon));

    // ---- base del canon (rectangulo 25x10) y paredes del tablero ----
    wire in_base = (x + 10'd12 >= kx) && (x <= kx + 10'd12) && (y >= 10'd452) && (y < 10'd462);
    wire in_wall = (y >= 10'd32) && (y < 10'd472) &&
                   (((x >= 10'd154) && (x < 10'd160)) || ((x >= 10'd480) && (x < 10'd486)));

    // ---- codigo de color (cadena de MUX con prioridad) ----
    //   0 fondo, 1 rojo, 2 verde, 3 azul, 4 gris
    wire [2:0] code = hit_cannon           ? {1'b0, next_color} :
                      hit_board            ? {1'b0, cell_data}       :
                      (in_base || in_wall) ? 3'd4               :
                                             3'd0;

    // ---- paleta: LUT de 8 x 12 bits (vector constante, color 0 en los bits bajos) ----
    localparam [95:0] PALETTE = {12'h000, 12'h000, 12'h000, 12'h888,
                                 12'h00F, 12'h0F0, 12'hF00, 12'h004};
    wire [6:0]  pal_pos = {4'b0000, code} * 7'd12;     // posicion = code*12
    wire [11:0] rgb     = PALETTE[pal_pos +: 12];

    // ---- MUX final: negro fuera de la zona visible ----
    assign {vga_r, vga_g, vga_b} = video_on ? rgb : 12'h000;
endmodule


// =====================================================================
// Envoltorio para vga-playground.com (formato Tiny Tapeout).
// El reloj del simulador ya es de 25 MHz -> pix_en = 1 siempre.
// Botones (ui_in, arriba de la pantalla):
//   ui_in[0] = izquierda   ui_in[1] = derecha   ui_in[2] = disparo
// =====================================================================
module tt_um_vga_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire       reset = ~rst_n;
    wire       hsync, vsync, video_on, frame_tick;
    wire [9:0] x, y;
    wire       left_pulse, right_pulse, shoot_pulse;
    wire [3:0] cannon_col, seq_idx;
    wire [1:0] next_color, cell_data;
    wire [7:0] rom_addr;
    wire [3:0] vga_r, vga_g, vga_b;

    vga_sync u_vga (
        .clk(clk), .reset(reset), .pix_en(1'b1),
        .hsync(hsync), .vsync(vsync), .video_on(video_on),
        .x(x), .y(y), .frame_tick(frame_tick)
    );

    // los botones del simulador son activo en alto: se invierten para input_ctrl
    input_ctrl #(.W(4)) u_in (
        .clk(clk), .reset(reset),
        .btn_left(~ui_in[0]), .btn_right(~ui_in[1]), .btn_shoot(~ui_in[2]),
        .left_pulse(left_pulse), .right_pulse(right_pulse), .shoot_pulse(shoot_pulse)
    );

    cannon_ctrl u_can (
        .clk(clk), .reset(reset),
        .left_pulse(left_pulse), .right_pulse(right_pulse), .col(cannon_col)
    );

    next_bubble u_next (
        .clk(clk), .reset(reset), .shoot_pulse(shoot_pulse),
        .idx(seq_idx), .color(next_color)
    );

    level_rom u_rom (.addr(rom_addr), .cell_data(cell_data));

    pixel_gen u_pix (
        .video_on(video_on), .x(x), .y(y),
        .cannon_col(cannon_col), .next_color(next_color),
        .rom_addr(rom_addr), .cell_data(cell_data),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );

    // Tiny VGA: 2 bits por color -> se usan los 2 bits altos de cada canal
    assign uo_out  = {hsync, vga_b[2], vga_g[2], vga_r[2], vsync, vga_b[3], vga_g[3], vga_r[3]};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire _unused = &{ena, uio_in, ui_in[7:3], frame_tick, seq_idx, 1'b0};
endmodule
