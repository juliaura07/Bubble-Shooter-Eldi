`timescale 1ns/1ps
// Verifica la sincronia VGA contra los numeros del estandar 640x480@60:
//   linea = 800 pixeles, cuadro = 525 lineas, video_activo = 307200 pixeles,
//   sinc_h bajo = 96 pixeles por linea, sinc_v bajo = 2 lineas, pulso_cuadro = 1 por cuadro.
module sincronia_vga_tb;
    reg  reloj   = 1'b0;
    reg  reinicio = 1'b1;
    always #5 reloj = ~reloj;                  // 100 MHz

    wire       hab_pixel, sinc_h, sinc_v, video_activo, pulso_cuadro;
    wire [9:0] x, y;

    divisor_reloj u_divisor (.reloj(reloj), .reinicio(reinicio), .hab_pixel(hab_pixel));
    sincronia_vga dut (
        .reloj(reloj), .reinicio(reinicio), .hab_pixel(hab_pixel),
        .sinc_h(sinc_h), .sinc_v(sinc_v), .video_activo(video_activo),
        .x(x), .y(y), .pulso_cuadro(pulso_cuadro)
    );

    integer errores      = 0;
    integer cuadros_listos = 0;
    integer cuenta_video = 0, cuenta_h_baja = 0, cuenta_v_baja = 0, cuenta_pulsos = 0;
    integer desde_bajada = 0;
    reg     vio_bajada = 1'b0;
    reg     sinc_h_ant   = 1'b1;
    reg     cuadro_ok;

    // Se muestrea UNA vez por pixel (cuando hab_pixel = 1)
    always @(posedge reloj) begin
        if (reinicio) begin
            cuenta_video = 0; cuenta_h_baja = 0; cuenta_v_baja = 0; cuenta_pulsos = 0;
            desde_bajada = 0; vio_bajada = 1'b0; sinc_h_ant = 1'b1;
        end else if (hab_pixel) begin
            if (x > 10'd799 || y > 10'd524) begin
                errores = errores + 1;
                $display("[FAIL] x/y fuera de rango: x=%0d y=%0d", x, y);
            end
            if (video_activo)   cuenta_video  = cuenta_video  + 1;
            if (!sinc_h)     cuenta_h_baja = cuenta_h_baja + 1;
            if (!sinc_v)     cuenta_v_baja = cuenta_v_baja + 1;
            if (pulso_cuadro) cuenta_pulsos   = cuenta_pulsos   + 1;

            desde_bajada = desde_bajada + 1;
            if (sinc_h_ant && !sinc_h) begin             // flanco de bajada de sinc_h
                if (vio_bajada && desde_bajada != 800) begin
                    errores = errores + 1;
                    $display("[FAIL] periodo de linea = %0d pixeles (esperado 800)", desde_bajada);
                end
                desde_bajada = 0;
                vio_bajada  = 1'b1;
            end
            sinc_h_ant = sinc_h;

            if (x == 10'd799 && y == 10'd524) begin  // ultimo pixel del cuadro
                cuadros_listos = cuadros_listos + 1;
                cuadro_ok = (cuenta_video == 307200) && (cuenta_h_baja == 50400) &&
                           (cuenta_v_baja == 1600)  && (cuenta_pulsos == 1);
                $display("Cuadro %0d: video_activo=%0d (esp 307200) | hsync_bajo=%0d (esp 50400) | vsync_bajo=%0d (esp 1600) | pulso_cuadro=%0d (esp 1)",
                         cuadros_listos, cuenta_video, cuenta_h_baja, cuenta_v_baja, cuenta_pulsos);
                if (cuadro_ok) $display("   -> [PASS] cuadro %0d correcto", cuadros_listos);
                else begin
                    errores = errores + 1;
                    $display("   -> [FAIL] cuadro %0d con valores incorrectos", cuadros_listos);
                end
                cuenta_video = 0; cuenta_h_baja = 0; cuenta_v_baja = 0; cuenta_pulsos = 0;
            end
        end
    end

    // Ondas (opcional): make wave_vga  -> solo guarda los primeros 300 us
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("sim/sincronia_vga_tb.vcd");
            $dumpvars(0, sincronia_vga_tb);
            #300000;
            $dumpoff;
        end
    end

    initial begin
        repeat (4) @(posedge reloj);
        @(negedge reloj) reinicio = 1'b0;

        wait (cuadros_listos == 2);               // 2 cuadros completos verificados
        wait (y > 10'd100);                    // ya estamos a mitad del cuadro 3

        // caso especial: reinicio a mitad de cuadro
        @(negedge reloj) reinicio = 1'b1;
        repeat (3) @(negedge reloj);
        if (x !== 10'd0 || y !== 10'd0 || sinc_h !== 1'b1 || sinc_v !== 1'b1 || video_activo !== 1'b1) begin
            errores = errores + 1;
            $display("[FAIL] tras reinicio: x=%0d y=%0d sinc_h=%b sinc_v=%b video_activo=%b", x, y, sinc_h, sinc_v, video_activo);
        end else begin
            $display("[PASS] reinicio a mitad de cuadro: x=0, y=0, sinc_h=1, sinc_v=1, video_activo=1");
        end
        @(negedge reloj) reinicio = 1'b0;

        wait (cuadros_listos == 3);               // un cuadro completo despues del reinicio
        #100;
        if (errores == 0) $display("RESULTADO FINAL sincronia_vga_tb: PASS");
        else             $display("RESULTADO FINAL sincronia_vga_tb: FAIL (%0d errores)", errores);
        $finish;
    end

    initial begin
        #150_000_000;
        $display("[FAIL] TIMEOUT: la simulacion no termino");
        $finish;
    end
endmodule
