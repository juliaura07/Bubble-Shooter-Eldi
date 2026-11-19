// PASO 6: canon, disparo y explosion en cadena vertical del mismo color (FSM).
// Pegar TODO en vga-playground.com reemplazando el codigo de ejemplo.
// Botones: ui_in[0] izquierda, ui_in[1] derecha, ui_in[2] disparo, ui_in[3] cambiar color.
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

// Control: 3 pulsadores + 1 switch -> pulsos de 1 ciclo y niveles limpios para los LEDs.
// Si izquierda y derecha estan presionadas a la vez, no se mueve.
module input_ctrl #(
    parameter W = 20
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       btn_left,            // pulsadores activos en bajo (0 = presionado)
    input  wire       btn_right,
    input  wire       btn_shoot,
    input  wire       sw_color,            // switch activo en alto (arriba = 1)
    output wire       left_pulse,
    output wire       right_pulse,
    output wire       shoot_pulse,         // reservado para el avance 2
    output wire       color_pulse,         // 1 ciclo cada vez que el switch sube
    output wire [3:0] levels               // {switch, disparo, derecha, izquierda} limpios
);
    wire l_level, l_rise, r_level, r_rise, s_level, s_rise, c_level, c_rise;

    btn_channel #(.W(W)) u_l (.clk(clk), .reset(reset), .btn_n(btn_left),  .level(l_level), .rise(l_rise));
    btn_channel #(.W(W)) u_r (.clk(clk), .reset(reset), .btn_n(btn_right), .level(r_level), .rise(r_rise));
    btn_channel #(.W(W)) u_s (.clk(clk), .reset(reset), .btn_n(btn_shoot), .level(s_level), .rise(s_rise));
    // el switch es activo en alto: se invierte para usar el mismo canal
    btn_channel #(.W(W)) u_c (.clk(clk), .reset(reset), .btn_n(~sw_color), .level(c_level), .rise(c_rise));

    assign left_pulse  = l_rise & ~r_level;    // se cancela si derecha esta presionada
    assign right_pulse = r_rise & ~l_level;
    assign shoot_pulse = s_rise;
    assign color_pulse = c_rise;               // flanco de subida del switch
    assign levels      = {c_level, s_level, r_level, l_level};
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
    output wire [1:0] cell_data,
    output wire [511:0] all_cells          // nivel completo (carga inicial del tablero)
);
    localparam [511:0] LEVEL = 512'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050500003d57c000af5fa0006bfe90005afa5;

    assign cell_data = LEVEL[{addr, 1'b0} +: 2];   // posicion addr*2 (desplazamiento, sin multiplicador)
    assign all_cells = LEVEL;
endmodule

// Tablero de juego en registros: 10x10 celdas de 2 bits.
// Direccion de una celda = {fila[3:0], columna[3:0]} (se reservan 16x16 posiciones; se usan 10x10).
// Cada celda es un registro propio de 2 bits con:
//   comparador (waddr = su direccion) + AND con we  -> enable de escritura
//   MUX de reset que carga el nivel inicial (init)
// - Lectura 1 (raddr): para dibujar la pantalla.
// - Lectura 2 (occ): ocupacion de las 10 filas de la columna qcol, para el disparo.
// - Lectura 3 (qaddr): color de la casilla de arriba, para comparar al chocar.
module board (
    input  wire         clk,
    input  wire         reset,
    input  wire [511:0] init,              // nivel inicial (todas las celdas)
    input  wire [7:0]   raddr,             // lectura para el dibujo
    output wire [1:0]   rdata,
    input  wire [7:0]   qaddr,             // lectura del color de una casilla (la de arriba)
    output wire [1:0]   qdata,
    input  wire [3:0]   qcol,              // columna que se consulta
    output wire [9:0]   occ,               // occ[f] = 1 si la fila f de qcol tiene burbuja
    input  wire         we,                // escritura
    input  wire [7:0]   waddr,
    input  wire [1:0]   wdata
);
    wire [511:0] cells;                    // todas las celdas juntas (solo cables)

    genvar f, c;
    generate
        for (f = 0; f < 16; f = f + 1) begin : g_fila
            for (c = 0; c < 16; c = c + 1) begin : g_col
                localparam [7:0] ADDR = f * 16 + c;
                if (f < 10 && c < 10) begin : g_celda
                    reg  [1:0] valor;
                    wire       wen = we && (waddr == ADDR);       // comparador + AND
                    always @(posedge clk) begin
                        if (reset)    valor <= init[ADDR * 2 +: 2];
                        else if (wen) valor <= wdata;
                    end
                    assign cells[ADDR * 2 +: 2] = valor;
                end else begin : g_vacia
                    assign cells[ADDR * 2 +: 2] = 2'b00;          // posicion fuera del tablero
                end
            end
        end
    endgenerate

    // lectura para el dibujo (MUX con la direccion como selector)
    assign rdata = cells[{raddr, 1'b0} +: 2];

    // lectura del color de la casilla de arriba (para comparar)
    assign qdata = cells[{qaddr, 1'b0} +: 2];

    // ocupacion de la columna qcol: 10 lecturas en paralelo + OR de sus 2 bits
    assign occ[0] = |cells[{4'd0, qcol, 1'b0} +: 2];
    assign occ[1] = |cells[{4'd1, qcol, 1'b0} +: 2];
    assign occ[2] = |cells[{4'd2, qcol, 1'b0} +: 2];
    assign occ[3] = |cells[{4'd3, qcol, 1'b0} +: 2];
    assign occ[4] = |cells[{4'd4, qcol, 1'b0} +: 2];
    assign occ[5] = |cells[{4'd5, qcol, 1'b0} +: 2];
    assign occ[6] = |cells[{4'd6, qcol, 1'b0} +: 2];
    assign occ[7] = |cells[{4'd7, qcol, 1'b0} +: 2];
    assign occ[8] = |cells[{4'd8, qcol, 1'b0} +: 2];
    assign occ[9] = |cells[{4'd9, qcol, 1'b0} +: 2];
endmodule

// Burbuja disparada con maquina de estados (Moore):
//   ESPERAR   -> espera el disparo
//   DISPARAR  -> sube STEP pixeles por cuadro hasta su fila de llegada
//   VERIFICAR -> compara el color de la bola con la casilla que se esta revisando
//   ELIMINAR  -> mismo color: borra esa casilla y sube a revisar la siguiente
//   AGRUPAR   -> ninguna exploto: la bola se guarda en su casilla
// Cadena vertical: se eliminan todas las burbujas seguidas del mismo color hacia arriba.
module shot_ctrl #(
    parameter [9:0] START_Y = 10'd432,     // altura del canon (centro)
    parameter [9:0] STEP    = 10'd8        // pixeles por cuadro
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       frame_tick,          // 1 pulso por cuadro
    input  wire       shoot_pulse,         // 1 pulso por pulsacion
    input  wire [3:0] cannon_col,
    input  wire [1:0] next_color,
    input  wire [9:0] occ,                 // ocupacion de la columna de la bola (filas 0..9)
    input  wire [1:0] above_color,         // color de la casilla que se revisa (leido del tablero)
    output wire       active,              // hay una bola en juego (para dibujarla)
    output reg  [3:0] scol,                // columna de la bola
    output reg  [9:0] sy,                  // altura de la bola (centro, en pixeles)
    output reg  [1:0] scolor,              // color de la bola
    output wire       launch,              // 1 ciclo al disparar (avanza la secuencia)
    output wire [7:0] above_addr,          // direccion de la casilla que se revisa
    output wire       we,                  // escritura en el tablero
    output wire [7:0] waddr,
    output wire [1:0] wdata,
    output wire       pop                  // 1 ciclo por cada burbuja eliminada (para el puntaje)
);
    // ---- codificacion de estados ----
    localparam [2:0] ESPERAR   = 3'd0,
                     DISPARAR  = 3'd1,
                     VERIFICAR = 3'd2,
                     ELIMINAR  = 3'd3,
                     AGRUPAR   = 3'd4;
    reg [2:0] state;

    // ---- registros de la cadena ----
    reg [3:0] fila_llegada;                // donde quedo la bola
    reg [3:0] fila_rev;                    // fila que se esta revisando
    reg       hay_arriba;                  // queda una fila por revisar
    reg       exploto;                     // ya se elimino al menos una

    // ---- decodificador de estado (comparadores) ----
    wire st_esperar   = (state == ESPERAR);
    wire st_disparar  = (state == DISPARAR);
    wire st_verificar = (state == VERIFICAR);
    wire st_eliminar  = (state == ELIMINAR);
    wire st_agrupar   = (state == AGRUPAR);

    // ---- fila de llegada: debajo de la ocupada mas baja (MUX en cadena con prioridad) ----
    wire [3:0] target_row = occ[9] ? 4'd10 :
                            occ[8] ? 4'd9  :
                            occ[7] ? 4'd8  :
                            occ[6] ? 4'd7  :
                            occ[5] ? 4'd6  :
                            occ[4] ? 4'd5  :
                            occ[3] ? 4'd4  :
                            occ[2] ? 4'd3  :
                            occ[1] ? 4'd2  :
                            occ[0] ? 4'd1  :
                                     4'd0;
    wire [4:0] trow_screen = {1'b0, target_row} + 5'd1;
    wire [9:0] target_y    = {trow_screen, 5'd16};

    // ---- condiciones ----
    assign launch  = shoot_pulse & st_esperar;
    wire move      = st_disparar & frame_tick;
    wire reach     = (sy <= target_y + STEP);
    wire land      = move & reach;                           // llego
    wire same      = hay_arriba & (above_color == scolor);   // mismo color en la fila revisada
    wire valid_row = (fila_llegada < 4'd10);                 // columna no llena

    // ---- logica de siguiente estado ----
    wire [2:0] state_next = launch       ? DISPARAR  :
                            land         ? VERIFICAR :
                            st_verificar ? (same ? ELIMINAR : (exploto ? ESPERAR : AGRUPAR)) :
                            st_eliminar  ? VERIFICAR :
                            st_agrupar   ? ESPERAR   :
                                           state;

    // ---- salidas (dependen solo del estado: Moore) ----
    assign active     = ~st_esperar;
    assign pop        = st_eliminar;
    assign above_addr = {fila_rev, scol};
    assign we         = st_eliminar | (st_agrupar & valid_row);
    assign waddr      = st_eliminar ? {fila_rev, scol} : {fila_llegada, scol};
    assign wdata      = st_eliminar ? 2'b00 : scolor;

    // ---- siguiente valor de los registros de la bola ----
    wire [9:0] sy_step     = reach ? target_y : sy - STEP;
    wire [9:0] sy_next     = launch ? START_Y : (move ? sy_step : sy);
    wire [3:0] scol_next   = launch ? cannon_col : scol;
    wire [1:0] scolor_next = launch ? next_color : scolor;

    // ---- siguiente valor de los registros de la cadena ----
    // al llegar: se revisa la fila de arriba de la bola
    // al eliminar: se sube una fila; si era la fila 0 (techo) ya no queda nada arriba
    wire [3:0] llegada_next = land ? target_row : fila_llegada;
    wire [3:0] rev_next     = land ? target_row - 4'd1 :
                              st_eliminar ? fila_rev - 4'd1 : fila_rev;
    wire       arriba_next  = land ? (target_row != 4'd0) :
                              st_eliminar ? (fila_rev != 4'd0) : hay_arriba;
    wire       exploto_next = land ? 1'b0 : (st_eliminar ? 1'b1 : exploto);

    always @(posedge clk) begin
        if (reset) begin
            state        <= ESPERAR;
            scol         <= 4'd0;
            sy           <= START_Y;
            scolor       <= 2'b00;
            fila_llegada <= 4'd0;
            fila_rev     <= 4'd0;
            hay_arriba   <= 1'b0;
            exploto      <= 1'b0;
        end else begin
            state        <= state_next;
            scol         <= scol_next;
            sy           <= sy_next;
            scolor       <= scolor_next;
            fila_llegada <= llegada_next;
            fila_rev     <= rev_next;
            hay_arriba   <= arriba_next;
            exploto      <= exploto_next;
        end
    end
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
    input  wire       shot_active,         // hay una bola volando
    input  wire [3:0] shot_col,            // su columna
    input  wire [9:0] shot_y,              // su altura (centro)
    input  wire [1:0] shot_color,          // su color
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

    // ---- bola disparada ----
    wire [4:0] ssc = {1'b0, shot_col} + 5'd5;      // columna de pantalla de la bola
    wire [9:0] sxc = {ssc, 5'd16};                 // centro x de la bola
    wire hit_shot_raw;
    circle_hit #(.R(15)) u_shot (.px(x), .py(y), .cx(sxc), .cy(shot_y), .hit(hit_shot_raw));
    wire hit_shot = shot_active && hit_shot_raw;

    // ---- base del canon (rectangulo 25x10) y paredes del tablero ----
    wire in_base = (x + 10'd12 >= kx) && (x <= kx + 10'd12) && (y >= 10'd452) && (y < 10'd462);
    wire in_wall = (y >= 10'd32) && (y < 10'd472) &&
                   (((x >= 10'd154) && (x < 10'd160)) || ((x >= 10'd480) && (x < 10'd486)));

    // ---- codigo de color (cadena de MUX con prioridad) ----
    //   prioridad: bola disparada > canon > tablero > gris > fondo
    //   0 fondo, 1 rojo, 2 verde, 3 azul, 4 gris
    wire [2:0] code = hit_shot             ? {1'b0, shot_color} :
                      hit_cannon           ? {1'b0, next_color} :
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


module tt_um_vga_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,                 // 25 MHz en el simulador
    input  wire       rst_n
);
    wire         reset = ~rst_n;
    wire         hsync, vsync, video_on, frame_tick;
    wire [9:0]   x, y;
    wire         left_pulse, right_pulse, shoot_pulse, color_pulse;
    wire [3:0]   levels, cannon_col, seq_idx;
    wire [1:0]   next_color, cell_data;
    wire [7:0]   rom_addr;
    wire [511:0] level_init;
    wire [9:0]   occ;
    wire         launch, shot_active, pop;
    wire [3:0]   shot_col;
    wire [9:0]   shot_y;
    wire [1:0]   shot_color;
    wire         board_we;
    wire [7:0]   board_waddr, above_addr;
    wire [1:0]   board_wdata, above_color;
    wire [3:0]   vga_r, vga_g, vga_b;

    vga_sync u_vga (
        .clk(clk), .reset(reset), .pix_en(1'b1),
        .hsync(hsync), .vsync(vsync), .video_on(video_on),
        .x(x), .y(y), .frame_tick(frame_tick)
    );

    // botones del simulador: activos en alto -> se invierten para input_ctrl
    input_ctrl #(.W(16)) u_in (
        .clk(clk), .reset(reset),
        .btn_left(~ui_in[0]), .btn_right(~ui_in[1]), .btn_shoot(~ui_in[2]),
        .sw_color(ui_in[3]),
        .left_pulse(left_pulse), .right_pulse(right_pulse),
        .shoot_pulse(shoot_pulse), .color_pulse(color_pulse),
        .levels(levels)
    );

    cannon_ctrl u_can (
        .clk(clk), .reset(reset),
        .left_pulse(left_pulse), .right_pulse(right_pulse), .col(cannon_col)
    );

    next_bubble u_next (
        .clk(clk), .reset(reset), .shoot_pulse(launch | color_pulse),
        .idx(seq_idx), .color(next_color)
    );

    level_rom u_rom (.addr(8'd0), .cell_data(), .all_cells(level_init));

    board u_board (
        .clk(clk), .reset(reset), .init(level_init),
        .raddr(rom_addr), .rdata(cell_data),
        .qaddr(above_addr), .qdata(above_color),
        .qcol(shot_col), .occ(occ),
        .we(board_we), .waddr(board_waddr), .wdata(board_wdata)
    );

    shot_ctrl u_shot (
        .clk(clk), .reset(reset), .frame_tick(frame_tick), .shoot_pulse(shoot_pulse),
        .cannon_col(cannon_col), .next_color(next_color), .occ(occ),
        .above_color(above_color),
        .active(shot_active), .scol(shot_col), .sy(shot_y), .scolor(shot_color),
        .launch(launch), .above_addr(above_addr),
        .we(board_we), .waddr(board_waddr), .wdata(board_wdata), .pop(pop)
    );

    pixel_gen u_pix (
        .video_on(video_on), .x(x), .y(y),
        .cannon_col(cannon_col), .next_color(next_color),
        .shot_active(shot_active), .shot_col(shot_col), .shot_y(shot_y), .shot_color(shot_color),
        .rom_addr(rom_addr), .cell_data(cell_data),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );

    assign uo_out  = {hsync, vga_b[2], vga_g[2], vga_r[2], vsync, vga_b[3], vga_g[3], vga_r[3]};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire _unused = &{ena, uio_in, ui_in[7:4], levels, seq_idx, pop,
                     vga_r[1:0], vga_g[1:0], vga_b[1:0], 1'b0};
endmodule
