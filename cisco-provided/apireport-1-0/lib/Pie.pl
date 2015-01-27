
$chart->chart_type("3d pie");

#############################################################################################

$chart->chart_border(
        
        "color"             => "ffffff",
        "top_thickness"     => 1,
        "bottom_thickness"  => 1,
        "left_thickness"    => 1,
        "right_thickness"   => 1 

);

#############################################################################################

$chart->chart_grid_h(

        "alpha"             => 0,
        "color"             => "000000",
        "thickness"         => 1,
        "type"              => "solid"

);

#############################################################################################

$chart->chart_grid_v(

        "alpha"             => 0,
        "color"             => "000000",
        "thickness"         => 1,
        "type"              => "solid"

);

#############################################################################################

$chart->chart_pref(

        "rotation_x"        => 50
);

#############################################################################################

$chart->chart_transition(

        "type"              => "slide_down",
        "delay"             => .5,
        "duration"          => .75,
        "order"             => "category"
);

#############################################################################################

$chart->chart_rect(

        "x"                 => 25,
        "y"                 => 10,
        "width"             => 180,
        "height"            => 120,
        "positive_color"    => "999999",
        "positive_alpha"    => 0,
        "negative_color"    => "ff0000",
        "negative_alpha"    => 0

);

#############################################################################################

$chart->chart_value(

        "prefix"            => "",
        "suffix"            => "%",
        "decimals"          => 0,
        "separator"         => "",
        "position"          => "inside",
        "hide_zero"         => true,
        "as_percentage"     => false,
        "font"              => "arial",
        "bold"              => true,
        "size"              => 16,
        "color"             => "000000",
        "alpha"             => 65

);

#############################################################################################

$chart->draw_text(

        "text"              => "overall",
        "type"              => "text",
        "transition"        => "slide_left",
        "color"             => "306888",
        "alpha"             => 50,
        "font"              => "arial",
        "rotation"          => -90,
        "bold"              => true,
        "size"              => 20,
        "x"                 => 0,
        "y"                 => 200,
        "width"             => 260,
        "height"            => 140,
        "h_align"           => "center",
        "v_align"           => "top"

); 

$chart->draw_text(

        "text"              => "deliverability",
        "type"              => "text",
        "transition"        => "slide_right",
        "color"             => "c0c0c0",
        "alpha"             => 25,
        "font"              => "arial",
        "rotation"          => -90,
        "bold"              => true,
        "size"              => 22,
        "x"                 => 8,
        "y"                 => 200,
        "width"             => 260,
        "height"            => 140,
        "h_align"           => "center",
        "v_align"           => "top"

); 

#############################################################################################

$chart->legend_rect(

        "x"                 => 185,
        "y"                 => 112,
        "width"             => 60,
        "height"            => 30,
        "margin"            => 4,
        "fill_color"        => "999999",
        "fill_alpha"        => 20,
        "line_color"        => "000000",
        "line_alpha"        => 50 

); 

#############################################################################################

$chart->legend_label(

        "layout"            => "vertical",
        "bullet"            => "square",
        "font"              => "arial",
        "bold"              => true,
        "size"              => 8,
        "color"             => "333333",
        "alpha"             => 85

); 

#############################################################################################

$chart->series_color(

        "306888",
        "c0c0c0"

); 

#############################################################################################
