
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
    wire       reset = ~rst_n;
    wire       hsync, vsync, video_on, frame_tick;
    wire [9:0] x, y;

    // Contadores VGA: dicen en que pixel (x, y) va el barrido
    vga_sync u_vga (
        .clk(clk), .reset(reset), .pix_en(1'b1),
        .hsync(hsync), .vsync(vsync), .video_on(video_on),
        .x(x), .y(y), .frame_tick(frame_tick)
    );

    // PASO 2: el MISMO circulo, pero el centro sale de la celda del pixel.
    // Celdas de 32x32: x[9:5] y y[9:5] dicen en que celda estoy.
    wire [4:0] sc = x[9:5];
    wire [4:0] sr = y[9:5];

    // Solo dibujamos en el tablero: columnas 5..14 y filas 1..10 (10x10 celdas)
    wire in_board = (sc >= 5'd5) && (sc <= 5'd14) && (sr >= 5'd1) && (sr <= 5'd10);

    wire dentro;
    circle_hit #(.R(15)) u_celda (
        .px(x), .py(y), .cx({sc, 5'd16}), .cy({sr, 5'd16}), .hit(dentro)
    );
    wire burbuja = in_board && dentro;

    wire [3:0] vga_r = (video_on &&  burbuja) ? 4'hF : 4'h0;
    wire [3:0] vga_g = 4'h0;
    wire [3:0] vga_b = (video_on && !burbuja) ? 4'h4 : 4'h0;

    assign uo_out  = {hsync, vga_b[2], vga_g[2], vga_r[2], vsync, vga_b[3], vga_g[3], vga_r[3]};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    wire _unused = &{ena, uio_in, ui_in, frame_tick, vga_r[1:0], vga_g[1:0], vga_b[1:0], 1'b0};
endmodule
