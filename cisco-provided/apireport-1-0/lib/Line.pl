
$chart->chart_type("Line");

#############################################################################################

$chart->axis_category(

        "size"              => 8,
        "color"             => "000000",
        "alpha"             => 25,
        "font"              => "arial",
        "bold"              => true,
        "skip"              => 5,
        "orientation"       => "horizontal"

); 

#############################################################################################

$chart->axis_ticks(

        "value_ticks"       => true,
        "category_ticks"    => true,
        "major_thickness"   => 1,
        "minor_thickness"   => 1,
        "minor_count"       => 1,
        "major_color"       => "9f9f9f",
        "minor_color"       => "c0c0c0" ,
        "position"          => "outside"
        
);

#############################################################################################

$chart->axis_value(

        "min"               => 0,
        "font"              => "arial",
        "bold"              => true,
        "size"              => 8,
        "color"             => "000000",
        "alpha"             => 25,
        "steps"             => 4,
        "prefix"            => "",
        "suffix"            => "",
        "decimals"          => 0,
        "separator"         => "",
        "show_min"          => true

);

#############################################################################################

$chart->chart_border(
        
        "color"             => "999999",
        "top_thickness"     => 1,
        "bottom_thickness"  => 1,
        "left_thickness"    => 1,
        "right_thickness"   => 1 

);

#############################################################################################

$chart->chart_grid_h(

        "alpha"             => 10,
        "color"             => "000000",
        "thickness"         => 1,
        "type"              => "solid"

);

#############################################################################################

$chart->chart_grid_v(

        "alpha"             => 2,
        "color"             => "000000",
        "thickness"         => 1,
        "type"              => "solid"

);

#############################################################################################

$chart->chart_pref(

        "line_thickness"    => 2,
        "point_shape"       => "none",
        "fill_shape"        => false

);

#############################################################################################

$chart->chart_transition(

        "type"              => "slide_right",
        "delay"             => 0,
        "duration"          => 1

);

#############################################################################################

$chart->chart_rect(

        "x"                 => 55,
        "y"                 => 5,
        "width"             => 113,
        "height"            => 70,
        "positive_color"    => "999999",
        "positive_alpha"    => 20,
        "negative_color"    => "ff0000",
        "negative_alpha"    => 10

);

#############################################################################################

$chart->chart_value(

        "prefix"            => "",
        "suffix"            => " recipients",
        "decimals"          => 0,
        "separator"         => "",
        "position"          => "cursor",
        "hide_zero"         => true,
        "as_percentage"     => false,
        "font"              => "arial",
        "bold"              => true,
        "size"              => 12,
        "color"             => "333333",
        "alpha"             => 75

);

#############################################################################################

$chart->draw_text(

        "text"              => "",
        "transition"        => "slide_left",
        "color"             => "306888",
        "alpha"             => 50,
        "font"              => "arial",
        "rotation"          => -90,
        "bold"              => true,
        "size"              => 20,
        "x"                 => 0,
        "y"                 => 180,
        "width"             => 260,
        "height"            => 100,
        "h_align"           => "center",
        "v_align"           => "top"

);

$chart->draw_text(

        "text"              => "volume",
        "transition"        => "slide_right",
        "color"             => "c0c0c0",
        "alpha"             => 25,
        "font"              => "arial",
        "rotation"          => -90,
        "bold"              => true,
        "size"              => 25,
        "x"                 => 8,
        "y"                 => 180,
        "width"             => 260,
        "height"            => 100,
        "h_align"           => "center",
        "v_align"           => "top"

);


#############################################################################################

$chart->legend_rect(

        "x"                 => -100,
        "y"                 => -100,
        "width"             => 10,
        "height"            => 10,
        "margin"            => 10

); 

#############################################################################################

$chart->series_color(

        "306888",
        "666666"

); 

#############################################################################################
